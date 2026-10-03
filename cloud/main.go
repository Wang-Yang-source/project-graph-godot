package main

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/mail"
	"net/url"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed schema.sql web.html
var assets embed.FS

const maxFile = 20 << 20
const userQuota = 100 << 20
const totalQuota = 500 << 20

type server struct {
	db      *pgxpool.Pool
	authURL string
	client  *http.Client
	slots   chan struct{}
}

type project struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Revision  int       `json:"revision"`
	Size      int64     `json:"size"`
	SHA256    string    `json:"sha256"`
	UpdatedAt time.Time `json:"updated_at"`
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	config, err := pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))
	if err != nil || os.Getenv("DATABASE_URL") == "" {
		log.Fatal("DATABASE_URL is required and must be valid")
	}
	config.MaxConns = 5
	db, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		log.Fatal("database initialization failed")
	}
	defer db.Close()
	schema, _ := assets.ReadFile("schema.sql")
	if _, err = db.Exec(ctx, string(schema)); err != nil {
		log.Fatal("database migration failed: ", err)
	}
	authURL := strings.TrimRight(os.Getenv("AUTH_URL"), "/")
	if authURL == "" {
		authURL = "http://127.0.0.1:19999"
	}
	s := &server{db: db, authURL: authURL, client: &http.Client{Timeout: 8 * time.Second}, slots: make(chan struct{}, 4)}
	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = "127.0.0.1:18080"
	}
	h := &http.Server{Addr: addr, Handler: s.routes(), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 30 * time.Second, WriteTimeout: 35 * time.Second, IdleTimeout: 60 * time.Second, MaxHeaderBytes: 16 << 10}
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = h.Shutdown(shutdown)
	}()
	log.Printf("Project Graph cloud listening on %s", addr)
	if err := h.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
	s.client.CloseIdleConnections()
}

func (s *server) routes() http.Handler {
	m := http.NewServeMux()
	m.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		b, _ := assets.ReadFile("web.html")
		_, _ = w.Write(b)
	})
	m.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if s.db.Ping(ctx) != nil {
			fail(w, 503, "database_unavailable")
			return
		}
		out(w, 200, map[string]string{"status": "ok"})
	})
	m.HandleFunc("GET /templates/{kind}", func(w http.ResponseWriter, r *http.Request) {
		kind := r.PathValue("kind")
		if kind != "confirmation" && kind != "recovery" {
			fail(w, 404, "not_found")
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = io.WriteString(w, "<p>Project Graph 邮箱验证码：</p><p><strong>{{ .Token }}</strong></p><p>5 分钟内有效，请勿将验证码透露给其他人。</p>")
	})
	for _, action := range []string{"signup", "confirm", "login", "refresh", "recover", "reset", "logout"} {
		m.HandleFunc("POST /v1/auth/"+action, s.auth)
	}
	m.HandleFunc("GET /v1/projects", s.projects)
	m.HandleFunc("POST /v1/projects", s.projects)
	m.HandleFunc("GET /v1/projects/{id}/file", s.download)
	m.HandleFunc("GET /v1/projects/{id}/revisions", s.revisions)
	m.HandleFunc("GET /v1/projects/{id}/revisions/{revision}/file", s.download)
	m.HandleFunc("PUT /v1/projects/{id}/file", s.projects)
	m.HandleFunc("DELETE /v1/projects/{id}", s.remove)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
		defer cancel()
		r = r.WithContext(ctx)
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
		// The test server has no cross-origin clients or cookie authentication.
		if origin := r.Header.Get("Origin"); origin != "" && origin != "http://"+r.Host && origin != "https://"+r.Host {
			fail(w, 403, "origin_not_allowed")
			return
		}
		select {
		case s.slots <- struct{}{}:
			defer func() { <-s.slots }()
		case <-r.Context().Done():
			return
		default:
			fail(w, 503, "busy_retry_later")
			return
		}
		m.ServeHTTP(w, r)
	})
}

func out(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func fail(w http.ResponseWriter, status int, code string) {
	out(w, status, map[string]string{"error": code})
}

func decode(w http.ResponseWriter, r *http.Request, v any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 8<<10)
	d := json.NewDecoder(r.Body)
	d.DisallowUnknownFields()
	if d.Decode(v) != nil || d.Decode(new(any)) != io.EOF {
		fail(w, 400, "invalid_json")
		return false
	}
	return true
}

func (s *server) authCall(ctx context.Context, method, path, token, ip string, payload any) (map[string]any, int, error) {
	var body io.Reader
	if payload != nil {
		b, err := json.Marshal(payload)
		if err != nil {
			return nil, 0, err
		}
		body = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, s.authURL+path, body)
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	// Never trust a client-supplied forwarding header.
	req.Header.Set("X-Forwarded-For", ip)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(io.LimitReader(resp.Body, (1<<20)+1))
	if err != nil || len(b) > 1<<20 {
		return nil, 0, errors.New("invalid auth response")
	}
	data := make(map[string]any)
	if len(b) > 0 && json.Unmarshal(b, &data) != nil {
		return nil, 0, errors.New("invalid auth response")
	}
	return data, resp.StatusCode, nil
}

func remoteIP(r *http.Request) string {
	ip, _, _ := net.SplitHostPort(r.RemoteAddr)
	return ip
}

func bearer(r *http.Request) string {
	value := r.Header.Get("Authorization")
	if strings.HasPrefix(value, "Bearer ") && len(value) < 8192 {
		return strings.TrimPrefix(value, "Bearer ")
	}
	return ""
}

func (s *server) owner(w http.ResponseWriter, r *http.Request) string {
	token := bearer(r)
	if token == "" {
		fail(w, 401, "authentication_required")
		return ""
	}
	user, status, err := s.authCall(r.Context(), "GET", "/user", token, remoteIP(r), nil)
	if err != nil {
		fail(w, 503, "authentication_unavailable")
		return ""
	}
	id, _ := user["id"].(string)
	if status != 200 || !validID(id) {
		fail(w, 401, "invalid_session")
		return ""
	}
	return id
}

func validEmail(email string) bool {
	a, err := mail.ParseAddress(email)
	return err == nil && a.Address == email && len(email) <= 254
}

func validPassword(password string) bool {
	return len([]rune(password)) >= 10 && len(password) <= 72
}

func (s *server) auth(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email        string `json:"email"`
		Password     string `json:"password"`
		Code         string `json:"code"`
		RefreshToken string `json:"refresh_token"`
	}
	if !decode(w, r, &in) {
		return
	}
	action := strings.TrimPrefix(r.URL.Path, "/v1/auth/")
	if action != "refresh" && action != "logout" && !validEmail(in.Email) {
		fail(w, 400, "invalid_email")
		return
	}
	if (action == "signup" || action == "reset") && !validPassword(in.Password) {
		fail(w, 400, "password_requires_10_characters_and_at_most_72_bytes")
		return
	}
	if (action == "confirm" || action == "reset") && (len(in.Code) != 6 || strings.Trim(in.Code, "0123456789") != "") {
		fail(w, 400, "six_digit_code_required")
		return
	}
	var path, token string
	var payload any
	switch action {
	case "signup":
		path, payload = "/signup", map[string]string{"email": in.Email, "password": in.Password}
	case "confirm":
		path, payload = "/verify", map[string]string{"email": in.Email, "token": in.Code, "type": "signup"}
	case "login":
		path, payload = "/token?grant_type=password", map[string]string{"email": in.Email, "password": in.Password}
	case "refresh":
		if in.RefreshToken == "" {
			fail(w, 400, "refresh_token_required")
			return
		}
		path, payload = "/token?grant_type=refresh_token", map[string]string{"refresh_token": in.RefreshToken}
	case "recover":
		path, payload = "/recover", map[string]string{"email": in.Email}
	case "reset":
		path, payload = "/verify", map[string]string{"email": in.Email, "token": in.Code, "type": "recovery"}
	case "logout":
		token = bearer(r)
		if token == "" {
			fail(w, 401, "authentication_required")
			return
		}
		path = "/logout?scope=global"
	}
	data, status, err := s.authCall(r.Context(), "POST", path, token, remoteIP(r), payload)
	if err != nil {
		fail(w, 503, "authentication_unavailable")
		return
	}
	if status >= 400 {
		code := "authentication_failed"
		if status == 429 {
			code = "too_many_requests"
		}
		fail(w, status, code)
		return
	}
	if action == "reset" {
		// Recovery sessions are never returned to the client and cannot download files.
		token, _ = data["access_token"].(string)
		if token == "" {
			fail(w, 502, "invalid_recovery_response")
			return
		}
		_, status, err = s.authCall(r.Context(), "PUT", "/user", token, remoteIP(r), map[string]string{"password": in.Password})
		if err != nil || status >= 400 {
			_, _, _ = s.authCall(r.Context(), "POST", "/logout?scope=global", token, remoteIP(r), nil)
			fail(w, 503, "password_reset_failed_request_new_code")
			return
		}
		_, status, err = s.authCall(r.Context(), "POST", "/logout?scope=global", token, remoteIP(r), nil)
		if err != nil || status >= 400 {
			fail(w, 503, "password_changed_session_cleanup_failed")
			return
		}
	}
	if action == "confirm" {
		if confirmed, _ := data["access_token"].(string); confirmed != "" {
			_, status, err = s.authCall(r.Context(), "POST", "/logout?scope=local", confirmed, remoteIP(r), nil)
			if err != nil || status >= 400 {
				fail(w, 503, "email_confirmed_session_cleanup_failed")
				return
			}
		}
	}
	if action == "login" || action == "refresh" {
		out(w, 200, map[string]any{"access_token": data["access_token"], "refresh_token": data["refresh_token"], "expires_in": data["expires_in"]})
		return
	}
	out(w, 200, map[string]bool{"ok": true})
}

func validID(id string) bool {
	return len(id) == 36 && uuid.Validate(id) == nil
}

func newID() string {
	return uuid.NewString()
}

func validatePRG(data []byte) error {
	z, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil || len(z.File) > 2048 {
		return errors.New("invalid_prg_archive")
	}
	entries := map[string]*zip.File{}
	var expanded uint64
	for _, f := range z.File {
		if f.UncompressedSize64 > 64<<20 || expanded > (64<<20)-f.UncompressedSize64 {
			return errors.New("prg_expanded_size_exceeded")
		}
		expanded += f.UncompressedSize64
		if _, exists := entries[f.Name]; exists {
			return errors.New("duplicate_prg_entry")
		}
		entries[f.Name] = f
	}
	for _, name := range []string{"metadata.json", "stage.json"} {
		f := entries[name]
		if f == nil || f.UncompressedSize64 > 8<<20 {
			return errors.New("prg_requires_current_json_format")
		}
		r, err := f.Open()
		if err != nil {
			return errors.New("invalid_prg_entry")
		}
		b, err := io.ReadAll(io.LimitReader(r, (8<<20)+1))
		_ = r.Close()
		var value map[string]json.RawMessage
		if err != nil || len(b) > 8<<20 || json.Unmarshal(b, &value) != nil || value == nil {
			return errors.New("invalid_prg_json")
		}
		if name == "metadata.json" {
			var version string
			if json.Unmarshal(value["version"], &version) != nil || !supportedVersion(version) {
				return errors.New("unsupported_prg_version")
			}
		} else if raw := bytes.TrimSpace(value["objects"]); len(raw) == 0 || raw[0] != '[' {
			return errors.New("prg_requires_objects_array")
		}
	}
	return nil
}

func supportedVersion(version string) bool {
	parts := strings.Split(version, ".")
	if len(parts) != 3 || parts[0] != "3" {
		return false
	}
	for _, part := range parts {
		if part == "" || strings.Trim(part, "0123456789") != "" {
			return false
		}
	}
	return true
}

func (s *server) projects(w http.ResponseWriter, r *http.Request) {
	owner := s.owner(w, r)
	if owner == "" {
		return
	}
	if r.Method == "GET" {
		rows, err := s.db.Query(r.Context(), `SELECT p.id::text,p.name,p.revision,octet_length(v.content),v.sha256,p.updated_at FROM cloud_projects p JOIN cloud_revisions v ON v.project_id=p.id AND v.revision=p.revision WHERE p.owner_id=$1 ORDER BY p.updated_at DESC`, owner)
		if err != nil {
			fail(w, 503, "database_unavailable")
			return
		}
		defer rows.Close()
		items := []project{}
		for rows.Next() {
			var p project
			if rows.Scan(&p.ID, &p.Name, &p.Revision, &p.Size, &p.SHA256, &p.UpdatedAt) != nil {
				fail(w, 503, "database_unavailable")
				return
			}
			items = append(items, p)
		}
		if rows.Err() != nil {
			fail(w, 503, "database_unavailable")
			return
		}
		out(w, 200, items)
		return
	}
	id := r.PathValue("id")
	expected := 0
	name, nameErr := url.QueryUnescape(r.Header.Get("X-Project-Name"))
	name = strings.TrimSpace(name)
	if r.Method == "POST" {
		id = newID()
		if nameErr != nil || name == "" || len(name) > 200 || strings.ContainsAny(name, "/\\\r\n") {
			fail(w, 400, "invalid_project_name")
			return
		}
	} else {
		if !validID(id) {
			fail(w, 404, "not_found")
			return
		}
		var err error
		expected, err = strconv.Atoi(strings.Trim(r.Header.Get("If-Match"), `"`))
		if err != nil || expected < 1 {
			fail(w, 428, "if_match_revision_required")
			return
		}
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxFile)
	data, err := io.ReadAll(r.Body)
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			fail(w, 413, "file_exceeds_20_mib")
		} else {
			fail(w, 400, "upload_interrupted")
		}
		return
	}
	if err := validatePRG(data); err != nil {
		fail(w, 400, err.Error())
		return
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		fail(w, 503, "database_unavailable")
		return
	}
	defer func() { _ = tx.Rollback(context.Background()) }()
	// The small test deployment serializes quota checks and commits globally.
	if _, err = tx.Exec(r.Context(), "SELECT pg_advisory_xact_lock(724905103)"); err != nil {
		fail(w, 503, "database_unavailable")
		return
	}
	if expected > 0 {
		var current int
		err = tx.QueryRow(r.Context(), "SELECT name,revision FROM cloud_projects WHERE id=$1 AND owner_id=$2 FOR UPDATE", id, owner).Scan(&name, &current)
		if errors.Is(err, pgx.ErrNoRows) {
			fail(w, 404, "not_found")
			return
		}
		if err != nil {
			fail(w, 503, "database_unavailable")
			return
		}
		if current != expected {
			out(w, 409, map[string]any{"error": "revision_conflict", "current_revision": current})
			return
		}
	}
	var used, total int64
	err = tx.QueryRow(r.Context(), `SELECT COALESCE(SUM(octet_length(v.content)) FILTER (WHERE p.owner_id=$1),0),COALESCE(SUM(octet_length(v.content)),0) FROM cloud_revisions v JOIN cloud_projects p ON p.id=v.project_id`, owner).Scan(&used, &total)
	if err != nil {
		fail(w, 503, "database_unavailable")
		return
	}
	if used+int64(len(data)) > userQuota || total+int64(len(data)) > totalQuota {
		fail(w, 413, "storage_quota_exceeded")
		return
	}
	next := expected + 1
	if expected == 0 {
		_, err = tx.Exec(r.Context(), "INSERT INTO cloud_projects(id,owner_id,name,revision) VALUES($1,$2,$3,1)", id, owner, name)
	} else {
		_, err = tx.Exec(r.Context(), "UPDATE cloud_projects SET revision=$1,updated_at=now() WHERE id=$2 AND owner_id=$3", next, id, owner)
	}
	checksum := fmt.Sprintf("%x", sha256.Sum256(data))
	if err == nil {
		_, err = tx.Exec(r.Context(), "INSERT INTO cloud_revisions(project_id,revision,sha256,content) VALUES($1,$2,$3,$4)", id, next, checksum, data)
	}
	if err != nil || tx.Commit(r.Context()) != nil {
		fail(w, 503, "save_failed")
		return
	}
	w.Header().Set("ETag", fmt.Sprintf(`"%d"`, next))
	out(w, 200, map[string]any{"id": id, "name": name, "revision": next, "size": len(data), "sha256": checksum})
}

func (s *server) download(w http.ResponseWriter, r *http.Request) {
	owner := s.owner(w, r)
	if owner == "" {
		return
	}
	id := r.PathValue("id")
	if !validID(id) {
		fail(w, 404, "not_found")
		return
	}
	revision := 0
	if v := r.PathValue("revision"); v != "" {
		var err error
		revision, err = strconv.Atoi(v)
		if err != nil || revision < 1 {
			fail(w, 404, "not_found")
			return
		}
	}
	var data []byte
	var checksum string
	var actual int
	err := s.db.QueryRow(r.Context(), `SELECT v.content,v.sha256,v.revision FROM cloud_projects p JOIN cloud_revisions v ON v.project_id=p.id AND v.revision=CASE WHEN $3::integer=0 THEN p.revision ELSE $3::integer END WHERE p.id=$1 AND p.owner_id=$2`, id, owner, revision).Scan(&data, &checksum, &actual)
	if errors.Is(err, pgx.ErrNoRows) {
		fail(w, 404, "not_found")
		return
	}
	if err != nil {
		fail(w, 503, "database_unavailable")
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s-v%d.prg"`, id, actual))
	w.Header().Set("ETag", fmt.Sprintf(`"%d"`, actual))
	w.Header().Set("X-Content-SHA256", checksum)
	w.Header().Set("Content-Length", strconv.Itoa(len(data)))
	_, _ = w.Write(data)
}

func (s *server) revisions(w http.ResponseWriter, r *http.Request) {
	owner := s.owner(w, r)
	if owner == "" {
		return
	}
	id := r.PathValue("id")
	if !validID(id) {
		fail(w, 404, "not_found")
		return
	}
	var exists bool
	if err := s.db.QueryRow(r.Context(), "SELECT EXISTS(SELECT 1 FROM cloud_projects WHERE id=$1 AND owner_id=$2)", id, owner).Scan(&exists); err != nil {
		fail(w, 503, "database_unavailable")
		return
	}
	if !exists {
		fail(w, 404, "not_found")
		return
	}
	rows, err := s.db.Query(r.Context(), `SELECT v.revision,octet_length(v.content),v.sha256,v.created_at FROM cloud_revisions v JOIN cloud_projects p ON p.id=v.project_id WHERE p.id=$1 AND p.owner_id=$2 ORDER BY v.revision DESC`, id, owner)
	if err != nil {
		fail(w, 503, "database_unavailable")
		return
	}
	defer rows.Close()
	items := []map[string]any{}
	for rows.Next() {
		var revision, size int
		var checksum string
		var created time.Time
		if rows.Scan(&revision, &size, &checksum, &created) != nil {
			fail(w, 503, "database_unavailable")
			return
		}
		items = append(items, map[string]any{"revision": revision, "size": size, "sha256": checksum, "created_at": created})
	}
	if rows.Err() != nil {
		fail(w, 503, "database_unavailable")
		return
	}
	out(w, 200, items)
}

func (s *server) remove(w http.ResponseWriter, r *http.Request) {
	owner := s.owner(w, r)
	if owner == "" {
		return
	}
	if !validID(r.PathValue("id")) {
		fail(w, 404, "not_found")
		return
	}
	expected, err := strconv.Atoi(strings.Trim(r.Header.Get("If-Match"), `"`))
	if err != nil || expected < 1 {
		fail(w, 428, "if_match_revision_required")
		return
	}
	result, err := s.db.Exec(r.Context(), "DELETE FROM cloud_projects WHERE id=$1 AND owner_id=$2 AND revision=$3", r.PathValue("id"), owner, expected)
	if err != nil {
		fail(w, 503, "database_unavailable")
		return
	}
	if result.RowsAffected() == 0 {
		var exists bool
		if s.db.QueryRow(r.Context(), "SELECT EXISTS(SELECT 1 FROM cloud_projects WHERE id=$1 AND owner_id=$2)", r.PathValue("id"), owner).Scan(&exists) != nil {
			fail(w, 503, "database_unavailable")
		} else if exists {
			fail(w, 409, "revision_conflict")
		} else {
			fail(w, 404, "not_found")
		}
		return
	}
	out(w, 200, map[string]bool{"ok": true})
}
