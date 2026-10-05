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
  POST /__stub/mode?feature=<f>&value=<ok|empty|403|404|500|slow>   (slow = 6 s delay, then ok)
       features: timetable roster attendance homework lessonplans ptm fixtures threads unread
  POST /__stub/attendance?count=<n>   number of attendance records "marked today" (default 0)
Home (Phase 4) endpoints, response shapes mirror
eldermin-teacher-app-docs/phase4/home-endpoint-shapes.md (citations next to each builder below;
legend: TS=teaching.service.ts S/TT=schemas/timetable.schema.ts STS=students.service.ts SPS=staff-portal.service.ts ...).
All values are DUMMY sample data. Fields not confirmed from backend code are marked "unverified".
Request bodies, tokens and passwords are never logged.
"""
import argparse
import json
import re
import threading
import time
import datetime
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
_modes = {}          # feature -> ok|empty|403|404|500|slow  (dev control)
_attendance = {"count": 0}


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


# ======================= Phase 4: Home fixtures (DUMMY) =======================
# Backend citations (eldermin-backend, branch feat/staff-portal), copied from the shapes doc.
OTHER_STAFF = "64a0000000000000000000a9"  # a colleague (DUMMY)


def _today():
    return datetime.date.today()


def _utc_midnight(d):
    return f"{d.isoformat()}T00:00:00.000Z"


def _oid(n):  # 24-hex dummy ids
    return f"64f{n:021x}"


def _period(day, no, start, end, subject, teacher_id, teacher_name, room, ptype="regular", week="both", splits=None):
    # periods[] shape: S/TT:17-70. day 0=Sun..6=Sat (S/TT:19, verified); startTime/endTime "HH:mm" by
    # convention (S/TT:21-22; format enforcement for legacy rows = UNVERIFIED U7); teacherId blank for a
    # split period (S/TT:54-56); weekCycle both|A|B (S/TT:43).
    return {
        "day": day, "periodNo": no, "startTime": start, "endTime": end, "subject": subject,
        "teacherId": teacher_id, "teacherName": teacher_name, "roomNo": room, "type": ptype,
        "locked": False, "blockId": None, "weekCycle": week, "electiveGroupId": None,
        "electiveGroupName": None, "splitGroups": splits or [],
    }


def timetable_docs(staff_id, name):
    """GET /teaching/timetable/teacher/:staffId  (TC:86-87 -> TS:486-492).
    Returns WHOLE class documents (every teacher's periods), one per grade+section; the app must filter
    (TS:486-492, verified). Doc fields: S/TT:7-15,72-81. weekCycleEnabled S/TT:79 (verified);
    cycleAnchor S/TT:75-80 is a schema COMMENT only -> A/B parity UNVERIFIED (U1): value below is a dummy.
    Note: split-only teachers are NOT returned by the real endpoint (TS:489 gap); this stub mirrors that
    by only returning docs where the teacher has a top-level period."""
    sc = [
        {"label": "Group 1", "teacherId": staff_id, "teacherName": name, "roomNo": "Lab 1"},
        {"label": "Group 2", "teacherId": OTHER_STAFF, "teacherName": "Other Teacher (DUMMY)", "roomNo": "Lab 2"},
    ]
    a, b = [], []
    for d in range(1, 6):
        a += [
            _period(d, 1, "08:00", "08:45", "Mathematics", staff_id, name, "101"),
            _period(d, 2, "09:00", "09:45", "English", OTHER_STAFF, "Other Teacher (DUMMY)", "101"),
            _period(d, 3, "10:00", "10:45", "Science", staff_id, name, "Lab 1", "lab"),
            _period(d, 4, "11:30", "12:15", "Science Lab", "", "", "", "lab", splits=sc),
            _period(d, 5, "13:00", "13:45", "Mathematics", staff_id, name, "101"),
            _period(d, 6, "14:30", "15:15", "Mathematics", staff_id, name, "101"),
            _period(d, 7, "16:00", "16:45", "Mathematics", staff_id, name, "101"),
        ]
        b += [
            _period(d, 1, "12:30", "13:15", "Science", staff_id, name, "202", week="A"),
            _period(d, 1, "12:30", "13:15", "Science (revision)", staff_id, name, "203", week="B"),
            _period(d, 2, "17:00", "17:45", "Mathematics", OTHER_STAFF, "Other Teacher (DUMMY)", "202"),
        ]

    def doc(n, grade, section, periods, cycle):
        return {
            "_id": _oid(0x100 + n), "tenantId": _oid(0xa1), "institutionId": _oid(0xa2), "academicYearId": None,
            "campusId": "64a0000000000000000000c1", "gradeLevel": grade, "sectionName": section, "sectionId": None,
            "status": "active", "periodsPerDay": 8, "workingDays": [1, 2, 3, 4, 5], "weekCycleEnabled": cycle,
            "cycleAnchor": "2026-09-28T00:00:00.000Z" if cycle else None, "periods": periods,
            "createdBy": _oid(0xd1), "createdAt": "2026-08-01T06:00:00.000Z", "updatedAt": "2026-08-01T06:00:00.000Z",
        }
    # A third doc where this teacher has no period must NOT be returned by the real endpoint (query matches
    # periods.teacherId); we only return docs containing her.
    return [doc(1, "Grade 5", "A", a, False), doc(2, "Grade 6", "B", b, True)]


def roster_diagnostic(grade, section):
    """GET /students/class-roster-diagnostic?grade=&section=  (STC:69-74 -> STS:478-513, verified).
    totalInClass STS:506-507; activeCount STS:490-494,508; byStatus STS:509; excludedByCampus STS:497-504,510;
    scopedToCampusId STS:511. Sample numbers are dummy."""
    return {"totalInClass": 31, "activeCount": 30,
            "byStatus": [{"status": "active", "count": 30}, {"status": "transferred", "count": 1}],
            "excludedByCampus": 0, "scopedToCampusId": "64a0000000000000000000c1"}


def attendance_list(grade, section, limit):
    """GET /students/attendance/list?grade&section&from&to&limit  (STC:453-459 -> STS:1825-1852).
    Response { data: StudentAttendance[], meta:{total,page,limit,pages} } (STS:1851, verified); item fields
    ATT:14-39 (verified). `date` is server-local midnight (STS:1800-1801; production TZ UNVERIFIED U3).
    Real server matches grade/section by EXACT string (STS:1831-1832; mismatch risk UNVERIFIED U4)."""
    total = _attendance["count"]
    n = min(total, max(1, int(limit or 20)))
    data = [{
        "_id": _oid(0x400 + i), "studentId": _oid(0x200 + i), "studentName": f"Sample Student {i + 1} (DUMMY)",
        "grade": grade, "section": section, "date": _utc_midnight(_today()), "status": "present",
        "markedBy": "Sample Teacher", "schoolSlug": "demo-school", "academicYear": "2026-27",
        "createdAt": f"{_today().isoformat()}T03:10:00.000Z", "updatedAt": f"{_today().isoformat()}T03:10:00.000Z", "__v": 0,
    } for i in range(n)]
    return {"data": data, "meta": {"total": total, "page": 1, "limit": int(limit or 20), "pages": 1 if total else 0}}


def _assignment(n, teacher_id, title, subject, due_days, status, count, grade="Grade 5", section="A"):
    # GET /teaching/assignments item: S/AS:7-33 (verified). submissionsCount counts submitted+late+graded
    # (S/AS:24; TS:1033-1044). No per-assignment "ungraded" field exists (shapes doc section 3a).
    due = _today() + datetime.timedelta(days=due_days)
    return {
        "_id": _oid(0x300 + n), "tenantId": _oid(0xa1), "institutionId": _oid(0xa2), "teacherId": teacher_id,
        "teacherName": "Sample Teacher", "campusId": "64a0000000000000000000c1", "title": title,
        "subject": subject, "gradeLevel": grade, "sectionName": section, "type": "homework",
        "assignedDate": _utc_midnight(_today() - datetime.timedelta(days=3)), "dueDate": _utc_midnight(due),
        "totalMarks": 100, "passingMarks": 50, "status": status, "submissionsCount": count, "avgScore": 0,
        "attachmentS3Keys": [], "createdAt": "2026-10-01T05:00:00.000Z", "updatedAt": "2026-10-01T05:00:00.000Z", "__v": 0,
    }


ASSIGNMENT_SUBS = {  # assignment index -> submission statuses
    1: ["submitted", "submitted", "late", "graded"],
    2: ["submitted", "graded", "graded"],
    3: ["graded", "graded"],
}


def assignments(staff_id):
    """GET /teaching/assignments?teacherId=<staffId>  (TC:194-195 -> TS:861-871; sorted dueDate desc; no pagination)."""
    return [
        _assignment(1, staff_id, "Chapter 3 worksheet (DUMMY)", "Mathematics", 2, "assigned", 4),
        _assignment(2, staff_id, "Lab report (DUMMY)", "Science", -1, "overdue", 3, "Grade 6", "B"),
        _assignment(3, staff_id, "Reading log (DUMMY)", "English", -4, "assigned", 2),
        _assignment(4, staff_id, "Draft quiz (DUMMY)", "Mathematics", 5, "draft", 0),
    ]


def submissions(assignment_id):
    """GET /teaching/assignments/:id/submissions  (TC:209-210 -> TS:990-1002) -> { assignment, submissions }.
    submissions[] fields: S/SUB:14-39 (verified); status pending|submitted|late|graded|missed (S/SUB:21-25).
    Ungraded = submitted|late (TS:1037). attachmentS3Keys -> download URL resolution UNVERIFIED (U12)."""
    try:
        idx = int(assignment_id[-3:], 16) - 0x300
    except ValueError:
        return None
    statuses = ASSIGNMENT_SUBS.get(idx)
    if statuses is None:
        return None
    subs = [{
        "_id": _oid(0x500 + idx * 10 + i), "assignmentId": assignment_id, "studentId": _oid(0x200 + i),
        "studentName": f"Sample Student {i + 1} (DUMMY)", "status": st, "isLate": st == "late",
        "attachmentS3Keys": [], "maxGrade": 100, "grade": 80 if st == "graded" else None,
    } for i, st in enumerate(statuses)]
    return {"assignment": {"_id": assignment_id}, "submissions": subs}


def lesson_plans(staff_id, status):
    """GET /teaching/lesson-plans?teacherId&status  (TC:59-60 -> TS:143-154; hard limit 100, planDate desc).
    Fields: S/LP:7-42 (verified). NOTE: no `title` field, the name is `topic` (S/LP:19).
    rejectionReason set by reject (S/LP:41; TS:375) and NOT cleared on resubmit (TS:179-185) -> the second
    'submitted' plan below deliberately carries a stale reason. Which id (Staff vs TeacherProfile) legacy
    rows store: UNVERIFIED (U2)."""
    def plan(n, topic, st, reason=None):
        p = {"_id": _oid(0x600 + n), "tenantId": _oid(0xa1), "teacherId": staff_id, "teacherName": "Sample Teacher",
             "campusId": "64a0000000000000000000c1", "subject": "Mathematics", "gradeLevel": "Grade 5",
             "sectionName": "A", "topic": topic, "planDate": _utc_midnight(_today() + datetime.timedelta(days=n)),
             "durationMins": 40, "learningObjectives": [], "resources": [], "sloTags": [], "status": st,
             "createdAt": "2026-10-01T05:00:00.000Z", "updatedAt": "2026-10-02T05:00:00.000Z"}
        if reason is not None:
            p["rejectionReason"] = reason
        return p
    allp = [
        plan(1, "Fractions (DUMMY)", "rejected", "Add an assessment section (DUMMY reason)"),
        plan(2, "Decimals (DUMMY)", "submitted"),
        plan(3, "Percentages (DUMMY)", "submitted", "Old reason from an earlier rejection (DUMMY)"),
        plan(4, "Ratios (DUMMY)", "approved"),
    ]
    return [p for p in allp if not status or p["status"] == status]


def upcoming_ptms(staff_id):
    """GET /teaching/ptm/upcoming/mine?teacherId=<staffId>  (PC:23-29 -> PS:178-183; status requested|confirmed,
    scheduledDate>=now, asc; no limit). Fields S/PTM:29-68 (verified); startTime/endTime format beyond the
    spec examples UNVERIFIED (U8). Real server drops a meeting scheduled for TODAY once now is past UTC
    midnight of the date (PS:60,181)."""
    def m(n, student, days, st, start, end):
        return {"_id": _oid(0x700 + n), "tenantId": _oid(0xa1), "studentId": _oid(0x200 + n), "studentName": student,
                "gradeLevel": "Grade 5", "sectionName": "A", "teacherId": staff_id, "teacherName": "Sample Teacher",
                "scheduledDate": _utc_midnight(_today() + datetime.timedelta(days=days)), "startTime": start,
                "endTime": end, "guardianName": "Sample Guardian (DUMMY)", "status": st, "academicYear": "2026-27",
                "discussionPoints": [], "actionItems": [], "parentAttended": False}
    return [m(1, "Sample Student 1 (DUMMY)", 3, "confirmed", "10:00", "10:20"),
            m(2, "Sample Student 2 (DUMMY)", 6, "requested", "11:00", "11:20")]


def fixtures(staff_id, frm, to):
    """GET /teaching/fixtures?teacherId&from&to  (SC:42-45 -> SS:232-245; limit 200; date desc, periodNo asc).
    teacherId matches originalTeacherId OR substituteTeacherId (SS:241). Fields S/FX:22-57 (verified).
    Stub: ACCOUNT a1 covers a period for a colleague; ACCOUNT a2 has her own period given away."""
    d = _utc_midnight(_today())

    def f(n, orig, orig_name, sub, sub_name, st):
        return {"_id": _oid(0x800 + n), "tenantId": _oid(0xa1), "date": d, "dayOfWeek": (_today().weekday() + 1) % 7,
                "timetableId": _oid(0x101), "periodNo": 3, "startTime": "09:20", "endTime": "10:00",
                "gradeLevel": "Grade 5", "sectionName": "A", "subject": "Mathematics", "roomNo": "101",
                "originalTeacherId": orig, "originalTeacherName": orig_name, "substituteTeacherId": sub,
                "substituteTeacherName": sub_name, "reason": "leave", "status": st, "assignedBy": "Admin",
                "notificationStatus": "sent"}
    out = []
    if staff_id == ACCOUNTS["teacher"]["staffId"]:
        out.append(f(1, OTHER_STAFF, "Other Teacher (DUMMY)", staff_id, "Tess Teacher", "assigned"))
    if staff_id == ACCOUNTS["classteacher"]["staffId"]:
        out.append(f(2, staff_id, "Clara Classteacher", OTHER_STAFF, "Other Teacher (DUMMY)", "assigned"))
    return out


def threads(staff_id):
    """GET /staff-portal/threads?status=open  (SPC:45-46 -> SPS:217-223). NEW on feat/staff-portal, NOT deployed
    to production. { items, unreadCount }; unreadCount counts only the returned rows (max 100) (SPS:222).
    Item fields NM:41-59 (verified)."""
    def t(n, unread, preview):
        return {"_id": _oid(0x900 + n), "subject": "Homework query", "studentId": _oid(0x200 + n),
                "studentName": f"Sample Student {n} (DUMMY)", "guardianUserId": _oid(0x910 + n),
                "guardianName": "Sample Guardian (DUMMY)", "staffId": staff_id, "staffName": "Sample Teacher",
                "lastMessagePreview": preview, "lastMessageAt": f"{_today().isoformat()}T06:30:00.000Z",
                "guardianHasUnread": False, "staffHasUnread": unread, "status": "open", "schoolSlug": "demo-school"}
    items = [t(1, True, "Thank you ma'am (DUMMY)"), t(2, True, "Could you share the worksheet? (DUMMY)"),
             t(3, False, "See you at the meeting (DUMMY)")]
    return {"items": items, "unreadCount": sum(1 for i in items if i["staffHasUnread"])}


def unread_count():
    """GET /staff-portal/notifications/unread-count  (SPC:33-34 -> SPS:191-195) -> { unreadCount }. NEW, not in prod."""
    return {"unreadCount": 3}


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
        # Real error shape: { statusCode, message, timestamp, path } - NO `error` key; an array message is
        # truncated to its first element (src/filters/sentry.filter.ts:43-48; MAIN:77) - shapes doc section 0.
        if isinstance(message, list):
            message = message[0]
        self._send(status, {"statusCode": status, "message": message,
                            "timestamp": datetime.datetime.utcnow().isoformat() + "Z", "path": urlparse(self.path).path})

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


    # -- Phase 4 Home routes. Returns True when the path was handled.
    def _feature_gate(self, feature):
        """Applies the dev-control mode. Returns 'empty' / None(ok) or True when an error was already sent."""
        with _lock:
            mode = _modes.get(feature, "ok")
        if mode == "slow":
            time.sleep(6)
            return None
        if mode in ("403", "404", "500"):
            msgs = {"403": "Forbidden resource", "404": f"Cannot GET (feature {feature} not available)", "500": "Internal server error"}
            self._err(int(mode), msgs[mode])
            return True
        return mode if mode == "empty" else None

    def _home_get(self, path, q):
        a = None
        def arg(k, d=""):
            return (q.get(k) or [d])[0]
        routes = {
            "/api/v1/students/class-roster-diagnostic": "roster",
            "/api/v1/students/attendance/list": "attendance",
            "/api/v1/teaching/assignments": "homework",
            "/api/v1/teaching/lesson-plans": "lessonplans",
            "/api/v1/teaching/ptm/upcoming/mine": "ptm",
            "/api/v1/teaching/fixtures": "fixtures",
            "/api/v1/staff-portal/threads": "threads",
            "/api/v1/staff-portal/notifications/unread-count": "unread",
        }
        feature = routes.get(path)
        m_tt = re.fullmatch(r"/api/v1/teaching/timetable/teacher/([0-9a-f]{24})", path)
        m_sub = re.fullmatch(r"/api/v1/teaching/assignments/([0-9a-f]{24})/submissions", path)
        if m_tt:
            feature = "timetable"
        elif m_sub:
            feature = "homework"
        if not feature:
            return False
        a = self._authed()
        if not a:
            return True
        gate = self._feature_gate(feature)
        if gate is True:
            return True
        empty = gate == "empty"
        if feature == "timetable":
            who = next((x for x in ACCOUNTS.values() if x["staffId"] == m_tt.group(1)), None)
            return self._send(200, [] if (empty or not who) else timetable_docs(who["staffId"], who["name"])) or True
        if feature == "roster":
            return self._send(200, roster_diagnostic(arg("grade"), arg("section"))) or True
        if feature == "attendance":
            return self._send(200, attendance_list(arg("grade"), arg("section"), arg("limit", "20"))) or True
        if feature == "homework" and m_sub:
            r = submissions(m_sub.group(1))
            return (self._err(404, "Assignment not found") if r is None else self._send(200, r)) or True
        if feature == "homework":
            return self._send(200, [] if empty else assignments(arg("teacherId"))) or True
        if feature == "lessonplans":
            return self._send(200, [] if empty else lesson_plans(arg("teacherId"), arg("status"))) or True
        if feature == "ptm":
            return self._send(200, [] if empty else upcoming_ptms(arg("teacherId"))) or True
        if feature == "fixtures":
            return self._send(200, [] if empty else fixtures(arg("teacherId"), arg("from"), arg("to"))) or True
        if feature == "threads":
            body = threads(a["staffId"])
            if empty:
                body = {"items": [], "unreadCount": 0}
            return self._send(200, body) or True
        if feature == "unread":
            return self._send(200, {"unreadCount": 0} if empty else unread_count()) or True
        return False

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
        elif path.startswith("/api/v1/") and self._home_get(path, parse_qs(urlparse(self.path).query)):
            return
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
        if path == "/__stub/mode":
            q = parse_qs(u.query)
            with _lock:
                _modes[(q.get("feature") or [""])[0]] = (q.get("value") or ["ok"])[0]
            return self._send(200, {"modes": _modes})
        if path == "/__stub/attendance":
            q = parse_qs(u.query)
            with _lock:
                _attendance["count"] = int((q.get("count") or ["0"])[0])
            return self._send(200, _attendance)
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
                _modes.clear()
                _attendance["count"] = 0
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
