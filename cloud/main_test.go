package main

import (
	"archive/zip"
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func archive(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var b bytes.Buffer
	z := zip.NewWriter(&b)
	for name, text := range files {
		f, err := z.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		_, _ = io.WriteString(f, text)
	}
	if err := z.Close(); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

func TestPRGValidation(t *testing.T) {
	for _, tc := range []struct {
		name  string
		files map[string]string
		ok    bool
	}{
		{"current", map[string]string{"metadata.json": `{"version":"3.0.0"}`, "stage.json": `{"objects":[],"camera":{}}`, "legacy/image.png": "preserved"}, true},
		{"missing_stage", map[string]string{"metadata.json": `{"version":"3.0.0"}`}, false},
		{"future_format", map[string]string{"metadata.json": `{"version":"4.0.0"}`, "stage.json": `{"objects":[]}`}, false},
		{"malformed_version", map[string]string{"metadata.json": `{"version":"3.broken"}`, "stage.json": `{"objects":[]}`}, false},
		{"wrong_objects", map[string]string{"metadata.json": `{"version":"3.0.0"}`, "stage.json": `{"objects":{}}`}, false},
		{"null_stage", map[string]string{"metadata.json": `{"version":"3.0.0"}`, "stage.json": `null`}, false},
		{"corrupt_json", map[string]string{"metadata.json": `{"version":"3.0.0"}`, "stage.json": `{"objects":`}, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if err := validatePRG(archive(t, tc.files)); (err == nil) != tc.ok {
				t.Fatalf("validation = %v, expected ok=%v", err, tc.ok)
			}
		})
	}
	if validatePRG([]byte("not a zip")) == nil {
		t.Fatal("accepted non-archive")
	}
	if validatePRG(archive(t, map[string]string{"huge": strings.Repeat("x", 65<<20)})) == nil {
		t.Fatal("accepted decompression bomb")
	}
}

func fakeAuth(t *testing.T, fn http.HandlerFunc) *server {
	t.Helper()
	h := httptest.NewServer(fn)
	t.Cleanup(h.Close)
	return &server{authURL: h.URL, client: &http.Client{Timeout: 80 * time.Millisecond}, slots: make(chan struct{}, 4)}
}

func TestRegistrationAndRecoveryNeverExposeSessions(t *testing.T) {
	for _, action := range []string{"signup", "confirm", "reset"} {
		t.Run(action, func(t *testing.T) {
			var paths []string
			s := fakeAuth(t, func(w http.ResponseWriter, r *http.Request) {
				paths = append(paths, r.Method+" "+r.URL.Path)
				if r.Header.Get("X-Forwarded-For") != "192.0.2.1" {
					t.Error("trusted remote IP was not forwarded")
				}
				out(w, 200, map[string]string{"access_token": "must-stay-private", "refresh_token": "also-private"})
			})
			r := httptest.NewRequest("POST", "/v1/auth/"+action, strings.NewReader(`{"email":"test@example.com","password":"long-password","code":"123456"}`))
			r.RemoteAddr = "192.0.2.1:1234"
			r.Header.Set("X-Forwarded-For", "spoofed")
			w := httptest.NewRecorder()
			s.routes().ServeHTTP(w, r)
			if w.Code != 200 || strings.Contains(w.Body.String(), "private") {
				t.Fatalf("unsafe auth result: %d %s", w.Code, w.Body.String())
			}
			if action == "reset" && strings.Join(paths, ",") != "POST /verify,PUT /user,POST /logout" {
				t.Fatalf("recovery sequence: %v", paths)
			}
		})
	}
}

func TestAuthTimeoutAndCancellation(t *testing.T) {
	s := fakeAuth(t, func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.Copy(io.Discard, r.Body)
		select {
		case <-r.Context().Done():
		case <-time.After(150 * time.Millisecond):
		}
	})
	r := httptest.NewRequest("POST", "/v1/auth/login", strings.NewReader(`{"email":"test@example.com","password":"test"}`))
	w := httptest.NewRecorder()
	s.routes().ServeHTTP(w, r)
	if w.Code != 503 {
		t.Fatalf("timeout result %d", w.Code)
	}
	if len(s.slots) != 0 {
		t.Fatal("request capacity leaked after timeout")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, _, err := s.authCall(ctx, "GET", "/user", "", "", nil); err == nil {
		t.Fatal("canceled request succeeded")
	}
}

func TestAuthRejectsUnrequestedFieldsAndInvalidCode(t *testing.T) {
	s := fakeAuth(t, func(w http.ResponseWriter, r *http.Request) { t.Error("invalid request reached auth") })
	for _, body := range []string{`{"email":"test@example.com","code":"123456","type":"magiclink"}`, `{"email":"test@example.com","code":"abc123"}`, `{"email":"test@example.com","code":"123456"} {}`} {
		w := httptest.NewRecorder()
		s.routes().ServeHTTP(w, httptest.NewRequest("POST", "/v1/auth/confirm", strings.NewReader(body)))
		if w.Code != 400 {
			t.Fatalf("invalid request accepted: %d", w.Code)
		}
	}
	for _, path := range []string{"/v1/auth/otp", "/v1/auth/magiclink", "/auth/v1/verify"} {
		w := httptest.NewRecorder()
		s.routes().ServeHTTP(w, httptest.NewRequest("POST", path, strings.NewReader(`{}`)))
		if w.Code != 404 {
			t.Fatalf("unrequested auth endpoint exposed: %s", path)
		}
	}
}

func TestOverloadAndCrossOrigin(t *testing.T) {
	s := &server{slots: make(chan struct{}, 1)}
	s.slots <- struct{}{}
	w := httptest.NewRecorder()
	s.routes().ServeHTTP(w, httptest.NewRequest("GET", "/", nil))
	if w.Code != 503 {
		t.Fatal("overload not rejected")
	}
	<-s.slots
	r := httptest.NewRequest("POST", "/v1/auth/signup", nil)
	r.Header.Set("Origin", "https://evil.example")
	w = httptest.NewRecorder()
	s.routes().ServeHTTP(w, r)
	if w.Code != 403 || len(s.slots) != 0 {
		t.Fatal("cross-origin request accepted or leaked capacity")
	}
}

func TestPasswordEmailAndID(t *testing.T) {
	if !validPassword("1234567890") || validPassword("short") || validPassword(strings.Repeat("中", 25)) {
		t.Fatal("password length policy incorrect")
	}
	if !validEmail("test@example.com") || validEmail("Test <test@example.com>") {
		t.Fatal("email policy incorrect")
	}
	if !validID(newID()) || validID("../../elsewhere") {
		t.Fatal("UUID policy incorrect")
	}
}

func TestAuthUpstreamBodyIsBounded(t *testing.T) {
	s := fakeAuth(t, func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, strings.Repeat(" ", 1<<20)+`{}`)
	})
	if _, _, err := s.authCall(context.Background(), "GET", "/user", "", "", nil); err == nil {
		t.Fatal("unbounded auth response accepted")
	}
}
