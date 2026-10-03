#!/usr/bin/env python3
"""Exercise the public cloud interface with disposable, synthetic accounts."""
import concurrent.futures
import hashlib
import io
import json
import os
import re
import socket
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zipfile

BASE = os.environ.get("CLOUD_BASE", "http://127.0.0.1:18080").rstrip("/")
MAIL = os.environ.get("MAILPIT_BASE", "http://127.0.0.1:18025").rstrip("/")


def request(path, data=None, token=None, headers=None, method=None, expected=200):
    headers = dict(headers or {})
    if isinstance(data, dict):
        data = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(BASE + path, data, headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=40) as response:
            status, body, info = response.status, response.read(), response.headers
    except urllib.error.HTTPError as error:
        status, body, info = error.code, error.read(), error.headers
    allowed = (expected,) if isinstance(expected, int) else expected
    assert status in allowed, (path, status, body[:400])
    return body, info, status


def auth(action, payload, expected=200, token=None):
    data, _, _ = request("/v1/auth/" + action, payload, token=token, expected=expected)
    return json.loads(data)


def code_for(email, exclude=None):
    for _ in range(80):
        with urllib.request.urlopen(MAIL + "/api/v1/messages", timeout=5) as response:
            messages = json.load(response)["messages"]
        for message in messages:
            if not any(to["Address"] == email for to in message["To"]):
                continue
            with urllib.request.urlopen(MAIL + "/api/v1/message/" + message["ID"], timeout=5) as response:
                content = json.load(response)
            found = re.search(r"\b([0-9]{6})\b", content.get("Text", "") + " " + content.get("HTML", ""))
            if found and found.group(1) != exclude:
                return found.group(1)
        time.sleep(.1)
    raise AssertionError("OTP email was not captured")


def make_prg(label="first", legacy_bytes=b"preserved-attachment"):
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w", compression=zipfile.ZIP_STORED) as archive:
        archive.writestr("metadata.json", json.dumps({"version": "3.0.0"}))
        archive.writestr("stage.json", json.dumps({"objects": [], "camera": {}, "label": label}))
        archive.writestr("legacy/assets/example.bin", legacy_bytes)
    return data.getvalue()


def list_projects(token):
    body, _, _ = request("/v1/projects", token=token)
    return json.loads(body)


def run():
    suffix = uuid.uuid4().hex
    email = "cloud-" + suffix + "@example.test"
    other = "other-" + suffix + "@example.test"
    password = "Test-only-password-" + suffix
    new_password = "Changed-test-password-" + suffix
    request("/v1/projects", expected=401)
    request("/v1/auth/otp", {}, expected=404)
    result = auth("signup", {"email": email, "password": password})
    assert result == {"ok": True}
    auth("login", {"email": email, "password": password}, expected=(400, 401))
    code = code_for(email)
    wrong = "000000" if code != "000000" else "111111"
    auth("confirm", {"email": email, "code": wrong}, expected=(400, 401, 403))
    assert auth("confirm", {"email": email, "code": code}) == {"ok": True}
    auth("confirm", {"email": email, "code": code}, expected=(400, 401, 403))
    session = auth("login", {"email": email, "password": password})
    token = session["access_token"]
    assert list_projects(token) == []
    print("PASS registration requires email verification; invalid/reused codes rejected; password login")

    original = make_prg()
    body, _, _ = request("/v1/projects", original, token, {"X-Project-Name": urllib.parse.quote("测试项目")})
    project = json.loads(body)
    path = "/v1/projects/" + project["id"]
    assert project["sha256"] == hashlib.sha256(original).hexdigest()
    downloaded, info, _ = request(path + "/file", token=token)
    assert downloaded == original and info["ETag"] == '"1"'
    assert list_projects(token)[0]["name"] == "测试项目"
    updated = make_prg("updated")
    request(path + "/file", updated, token, method="PUT", expected=428)
    request(path + "/file", updated, token, {"If-Match": '"1"'}, method="PUT")
    request(path + "/file", original, token, {"If-Match": '"1"'}, method="PUT", expected=409)
    downloaded, _, _ = request(path + "/revisions/1/file", token=token)
    assert downloaded == original
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        calls = [pool.submit(request, path + "/file", make_prg(str(i)), token, {"If-Match": '"2"'}, "PUT", (200, 409)) for i in range(2)]
        assert sorted(call.result()[2] for call in calls) == [200, 409]
    revisions, _, _ = request(path + "/revisions", token=token)
    assert [v["revision"] for v in json.loads(revisions)] == [3, 2, 1]
    print("PASS byte-exact PRG and attachment roundtrip; history; stale and concurrent saves conflict")

    auth("signup", {"email": other, "password": password})
    auth("confirm", {"email": other, "code": code_for(other)})
    other_token = auth("login", {"email": other, "password": password})["access_token"]
    assert list_projects(other_token) == []
    request(path + "/file", token=other_token, expected=404)
    request(path + "/revisions", token=other_token, expected=404)
    request(path + "/revisions/1/file", token=other_token, expected=404)
    request(path + "/file", updated, other_token, {"If-Match": '"3"'}, method="PUT", expected=404)
    request(path, token=other_token, headers={"If-Match": '"3"'}, method="DELETE", expected=404)
    print("PASS second user cannot list, read, update or delete first user's files")

    request("/v1/projects", b"broken-archive", token, {"X-Project-Name": "bad"}, expected=400)
    request("/v1/projects", b"x" * ((20 << 20) + 1), token, {"X-Project-Name": "too-large"}, expected=413)
    parsed = urllib.parse.urlparse(BASE)
    if parsed.scheme == "http":
        connection = socket.create_connection((parsed.hostname, parsed.port or 80), timeout=5)
        head = (f"POST /v1/projects HTTP/1.1\r\nHost: {parsed.netloc}\r\nAuthorization: Bearer {token}\r\nX-Project-Name: interrupted\r\nContent-Length: 10000\r\nConnection: close\r\n\r\n").encode()
        connection.sendall(head + b"PK")
        connection.close()
        time.sleep(.5)
    assert len(list_projects(token)) == 1
    print("PASS invalid, oversized and disconnected uploads do not create partial projects")

    if os.environ.get("QUOTA_TEST") == "1":
        large = make_prg("quota", b"x" * (18 << 20))
        extras = []
        try:
            for _ in range(5):
                body, _, _ = request("/v1/projects", large, token, {"X-Project-Name": "quota"})
                extras.append(json.loads(body)["id"])
            body, _, _ = request("/v1/projects", large, token, {"X-Project-Name": "quota"}, expected=413)
            assert json.loads(body)["error"] == "storage_quota_exceeded"
        finally:
            for id in extras:
                request("/v1/projects/" + id, token=token, headers={"If-Match": '"1"'}, method="DELETE")
        print("PASS per-user storage quota is enforced transactionally and deletion frees space")

    refreshed = auth("refresh", {"refresh_token": session["refresh_token"]})
    token = refreshed["access_token"]
    assert auth("recover", {"email": "absent-" + suffix + "@example.test"}) == {"ok": True}
    auth("recover", {"email": email})
    reset_code = code_for(email, exclude=code)
    auth("reset", {"email": email, "code": wrong, "password": new_password}, expected=(400, 401, 403))
    assert auth("reset", {"email": email, "code": reset_code, "password": new_password}) == {"ok": True}
    auth("login", {"email": email, "password": password}, expected=(400, 401))
    auth("refresh", {"refresh_token": refreshed["refresh_token"]}, expected=(400, 401))
    auth("reset", {"email": email, "code": reset_code, "password": new_password}, expected=(400, 401, 403))
    session = auth("login", {"email": email, "password": new_password})
    token = session["access_token"]
    assert list_projects(token)[0]["id"] == project["id"]
    request(path, token=token, headers={"If-Match": '"1"'}, method="DELETE", expected=409)
    request(path, token=token, headers={"If-Match": '"3"'}, method="DELETE")
    assert list_projects(token) == []
    request(path + "/revisions/1/file", token=token, expected=404)
    auth("logout", {}, token=token)
    auth("refresh", {"refresh_token": session["refresh_token"]}, expected=(400, 401))
    auth("logout", {}, token=other_token)
    print("PASS password recovery exposes no session; old password and refresh tokens fail; files remain owned; logout revokes refresh")

    if os.environ.get("EXPIRE_WAIT"):
        exp_email = "expired-" + suffix + "@example.test"
        auth("signup", {"email": exp_email, "password": password})
        expired_code = code_for(exp_email)
        auth("signup", {"email": exp_email, "password": password}, expected=429)
        print("Waiting for short-lived local test code to expire...", flush=True)
        time.sleep(float(os.environ["EXPIRE_WAIT"]))
        auth("confirm", {"email": exp_email, "code": expired_code}, expected=(400, 401, 403))
        print("PASS code expiration and resend cooldown")
    print("All public-interface integration checks passed.")


if __name__ == "__main__":
    run()
