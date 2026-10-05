#!/usr/bin/env python3
"""LOCAL DEV STUB of the Eldermin API for the teacher app (Phase 3).

!! DUMMY DATA ONLY. Nothing here talks to, or represents, a real school.
!! Lives under tool/dev/ on purpose: it is never part of lib/ or assets/, so
!! it cannot ship in a release build.

Run:      python3 tool/dev/stub_server.py [--port 3999] [--host 127.0.0.1]
Point app: flutter run --dart-define=API_BASE_URL=http://localhost:3999
           (Android emulator: http://10.0.2.2:3999)

Serves (prefix /api/v1):  POST /auth/login, GET /auth/me,
POST /auth/forgot-password, POST /auth/reset-password, POST /auth/logout,
GET /staff-portal/me.  Response shapes follow eldermin-backend
(auth.controller.ts / auth.service.ts / staff-portal.service.ts getMe).

Dummy accounts (password for all: StubPass123)
  teacher@stub.test       plain teacher
  classteacher@stub.test  class teacher (Grade 5 - A)
  principal@stub.test     role "principal" (-> "use the web portal" screen)

Dummy session tokens (JWT-shaped, accepted by /auth/me + /staff-portal/me)
  stub.teacher.dummy  stub.classteacher.dummy  stub.principal.dummy
  stub.expired.dummy  -> always 401 (expired/invalid token scenario)
Token-login deep link:
  eldermin-teacher://login?token=stub.classteacher.dummy&slug=demo-school
Reset links (single use; POST /__stub/reset-state re-arms it):
  eldermin-teacher://reset-password?token=<VALID_RESET_TOKEN below>
  any other token -> 401 "This reset link is invalid or has expired"

Dev controls (not part of the real API):
  POST /__stub/class-teacher?email=teacher@stub.test&value=true|false
  POST /__stub/reset-state        GET /__stub/state
Request bodies, tokens and passwords are never logged.
"""
import argparse
import json
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PASSWORD = "StubPass123"  # DUMMY
VALID_RESET_TOKEN = "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"  # DUMMY
GENERIC_FORGOT = "If an account exists with that email, a reset link has been sent."

INSTITUTION = {
    "name": "Demo School (STUB)",
    "slug": "demo-school",
    "plan": "pro",
    "activeModules": ["teaching", "students"],
}

# key -> account (DUMMY)
ACCOUNTS = {
    "teacher": {
        "id": "64a000000000000000000001", "name": "Tess Teacher", "email": "teacher@stub.test",
        "role": "teacher", "staffId": "64a0000000000000000000a1", "teacherProfileId": "64a0000000000000000000b1",
        "department": "Science", "campus": {"id": "64a0000000000000000000c1", "name": "Main Campus"},
        "classTeacher": False,
    },
    "classteacher": {
        "id": "64a000000000000000000002", "name": "Clara Classteacher", "email": "classteacher@stub.test",
        "role": "teacher", "staffId": "64a0000000000000000000a2", "teacherProfileId": "64a0000000000000000000b2",
        "department": "Primary", "campus": {"id": "64a0000000000000000000c1", "name": "Main Campus"},
        "classTeacher": True,
    },
    "principal": {
        "id": "64a000000000000000000003", "name": "Paul Principal", "email": "principal@stub.test",
        "role": "principal", "staffId": "64a0000000000000000000a3", "teacherProfileId": None,
        "department": "Management", "campus": {"id": "64a0000000000000000000c1", "name": "Main Campus"},
        "classTeacher": False,
    },
}
BY_EMAIL = {a["email"]: k for k, a in ACCOUNTS.items()}

_lock = threading.Lock()
_state = {"reset_used": False}


def token_for(key):
    return f"stub.{key}.dummy"


def account_for_token(token):
    m = re.fullmatch(r"stub\.([a-z]+)\.dummy", token or "")
    return ACCOUNTS.get(m.group(1)) if m else None


def user_view(a, with_scope=True):
    u = {"id": a["id"], "name": a["name"], "email": a["email"], "role": a["role"], "avatarUrl": None}
    if with_scope:
        u.update({
            "campusId": a["campus"]["id"], "department": a["department"],
            "staffId": a["staffId"], "teacherProfileId": a["teacherProfileId"],
        })
        if a["classTeacher"]:
            u.update({"classTeacherOfGradeId": "grade-5", "classTeacherOfGradeName": "Grade 5",
                      "classTeacherOfSectionName": "A"})
    return u


def staff_me(a):
    profile = {
        "employeeId": "EMP-STUB", "designation": "Teacher", "department": a["department"], "photoUrl": None,
        "subjectsCanTeach": ["Science"], "gradeLevelsCanTeach": ["5"], "currentAssignments": [],
        "status": "active", "isClassTeacher": a["classTeacher"],
        "classTeacherOf": {"gradeId": "grade-5", "gradeName": "Grade 5", "sectionName": "A",
                           "label": "Grade 5 - A"} if a["classTeacher"] else None,
    }
    return {
        "user": {"id": a["id"], "name": a["name"], "email": a["email"], "role": a["role"], "avatarUrl": None},
        "staffId": a["staffId"], "teacherProfileId": a["teacherProfileId"], "teacherProfile": profile,
        "department": a["department"], "campus": a["campus"], "institution": INSTITUTION,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "ElderminStub/1"

    def log_message(self, fmt, *args):  # path + status only; never bodies/tokens
        print(f"[stub] {self.command} {urlparse(self.path).path} -> {args[1] if len(args) > 1 else ''}", flush=True)

    # -- helpers
    def _send(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _err(self, status, message, error=None):
        self._send(status, {"statusCode": status, "message": message, "error": error or {
            400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found"}.get(status, "Error")})

    def _json(self):
        try:
            n = int(self.headers.get("Content-Length") or 0)
            return json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return {}

    def _bearer(self):
        h = self.headers.get("Authorization") or ""
        return h[7:] if h.startswith("Bearer ") else ""

    def _authed(self):
        a = account_for_token(self._bearer())
        if not a:
            self._err(401, "Unauthorized")
        return a

    # -- routing
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/v1/auth/me":
            a = self._authed()
            if a:
                self._send(200, user_view(a))
        elif path == "/api/v1/staff-portal/me":
            a = self._authed()
            if not a:
                return
            if a["role"] != "teacher":
                return self._err(403, "Forbidden resource")
            self._send(200, staff_me(a))
        elif path == "/__stub/state":
            with _lock:
                self._send(200, {"classTeacher": {k: v["classTeacher"] for k, v in ACCOUNTS.items()}, **_state})
        else:
            self._err(404, f"Cannot GET {path}")

    def do_POST(self):
        u = urlparse(self.path)
        path = u.path
        if path == "/api/v1/auth/login":
            b = self._json()
            email, pw = str(b.get("email", "")).strip().lower(), str(b.get("password", ""))
            problems = []
            if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
                problems.append("email must be an email")
            if len(pw) < 6:
                problems.append("password must be longer than or equal to 6 characters")
            if problems:
                return self._err(400, problems)
            key = BY_EMAIL.get(email)
            if not key or pw != PASSWORD:
                return self._err(401, "Invalid credentials")
            a = ACCOUNTS[key]
            return self._send(200, {"accessToken": token_for(key), "user": user_view(a), "institution": INSTITUTION})
        if path == "/api/v1/auth/forgot-password":
            b = self._json()
            if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", str(b.get("email", ""))):
                return self._err(400, ["email must be an email"])
            return self._send(200, {"message": GENERIC_FORGOT})  # same for known/unknown emails
        if path == "/api/v1/auth/reset-password":
            b = self._json()
            token, pw = str(b.get("token", "")), str(b.get("newPassword", ""))
            if len(pw) < 6:
                return self._err(400, ["newPassword must be longer than or equal to 6 characters"])
            with _lock:
                if token != VALID_RESET_TOKEN or _state["reset_used"]:
                    return self._err(401, "This reset link is invalid or has expired")
                _state["reset_used"] = True
            return self._send(200, {"message": "Password updated - you can now sign in with your new password."})
        if path == "/api/v1/auth/logout":
            return self._send(200, {"message": "Logged out successfully"})
        if path == "/__stub/class-teacher":
            q = parse_qs(u.query)
            key = BY_EMAIL.get((q.get("email") or [""])[0])
            if not key:
                return self._err(404, "unknown stub email")
            with _lock:
                ACCOUNTS[key]["classTeacher"] = (q.get("value") or ["true"])[0] == "true"
            return self._send(200, {"email": ACCOUNTS[key]["email"], "classTeacher": ACCOUNTS[key]["classTeacher"]})
        if path == "/__stub/reset-state":
            with _lock:
                _state["reset_used"] = False
                ACCOUNTS["teacher"]["classTeacher"] = False
                ACCOUNTS["classteacher"]["classTeacher"] = True
            return self._send(200, {"ok": True})
        self._err(404, f"Cannot POST {path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=3999)
    ap.add_argument("--host", default="127.0.0.1")
    args = ap.parse_args()
    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"[stub] DUMMY Eldermin API on http://{args.host}:{args.port}/api/v1  (Ctrl+C to stop)", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
