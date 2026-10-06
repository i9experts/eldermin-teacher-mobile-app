#!/usr/bin/env python3
"""READ-ONLY staging verification for the Teacher app Home screen (python3 stdlib only).

Usage:  python3 tool/dev/verify_staging.py [--no-write] [--env <alt env file>]
Needs:  tool/dev/.env.staging (git-ignored; copy tool/dev/.env.staging.example)
        keys: STAGING_BASE_URL, SCHOOL_SLUG, TEACHER_EMAIL, TEACHER_PASSWORD,
              CLASS_TEACHER_EMAIL, CLASS_TEACHER_PASSWORD  (class teacher is optional)
If the file is missing, this prints usage and exits 0.

What it does: logs in (the ONLY two POSTs: POST /auth/login for the teacher and, if given, the class
teacher), then calls ONLY GET endpoints that Home uses and checks that the keys/types the app parses
exist (EXPECTATIONS below; each entry cites the backend code and the app model that consumes it).

HARD RULES (enforced in code and covered by tests in tool/dev/test_verify_staging.py):
  * NEVER prints or writes passwords, tokens, emails, names, ids or ANY response value. Output is limited to
    HTTP status codes, key names from the EXPECTATIONS table, value TYPES, array lengths and counts.
  * Refuses to run against the production host (api.eldermin.com) - hard-coded block, no override.
  * Only GET (plus the two login POSTs); anything else raises before a socket is opened.
  * Redirects are not followed (a token is never sent to a second host).

Result words: PASS / FAIL / NOT-DEPLOYED(404) per endpoint; PASS / FAIL / N/A (no rows to check) per field.
Exit code: 1 if anything FAILed, else 0.
"""
import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_PATH = os.path.join(HERE, ".env.staging")
OUT_DIR = os.path.join(HERE, "out")
BLOCKED_HOSTS = {"api.eldermin.com"}  # production. Hard block, never overridable.
MAX_ITEMS_CHECKED = 50
TIMEOUT = 25

USAGE = """verify_staging.py: tool/dev/.env.staging not found - nothing was called.

Create it from the example (the file is git-ignored; never commit it, never paste it into chat):
  cp tool/dev/.env.staging.example tool/dev/.env.staging
  # fill STAGING_BASE_URL (staging host, e.g. https://<staging-host>/api/v1 or just https://<staging-host>),
  # SCHOOL_SLUG, TEACHER_EMAIL, TEACHER_PASSWORD (and optionally CLASS_TEACHER_EMAIL / CLASS_TEACHER_PASSWORD)
Run:
  python3 tool/dev/verify_staging.py
Details: eldermin-teacher-app-docs/phase4/STAGING_VERIFICATION.md
"""

# ───────────────────────────── pure helpers (unit-tested) ─────────────────────────────


def type_name(v):
    """JSON value -> 'null'|'bool'|'int'|'float'|'str'|'list'|'dict' (bool is NOT an int)."""
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "bool"
    if isinstance(v, int):
        return "int"
    if isinstance(v, float):
        return "float"
    if isinstance(v, str):
        return "str"
    if isinstance(v, list):
        return "list"
    if isinstance(v, dict):
        return "dict"
    return "other"


def parse_env(text):
    """KEY=VALUE lines (# comments, optional quotes). Returns dict. Never logs values."""
    out = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        out[k.strip()] = v
    return out


def host_of(url):
    try:
        return (urllib.parse.urlparse(url.strip()).hostname or "").lower().rstrip(".")
    except ValueError:
        return ""


def host_is_blocked(url):
    """True for the production API host (also when written with a port, userinfo, a trailing dot or in caps)."""
    h = host_of(url)
    return h in BLOCKED_HOSTS or any(h.endswith("." + b) for b in BLOCKED_HOSTS)


def normalize_base(url):
    """Base ending in /api/v1 (the app's prefix), no trailing slash."""
    u = url.strip().rstrip("/")
    return u if u.endswith("/api/v1") else u + "/api/v1"


def request_allowed(method, path):
    """Only GET, plus POST /auth/login. Anything else is refused before any network I/O."""
    method = method.upper()
    if method == "GET":
        return True
    return method == "POST" and path.rstrip("/").endswith("/auth/login")


def _walk(body, path):
    """Resolve `a.b[].c` -> list of (kind, value). kind: 'ok' | 'missing' (final key absent). Parents that are
    null/missing/non-dict are skipped (their own expectation line reports them)."""
    parts = path.split(".")
    nodes = [body]
    for i, part in enumerate(parts):
        last = i == len(parts) - 1
        each = part.endswith("[]")
        key = part[:-2] if each else part
        nxt = []
        for n in nodes:
            if part == "[]":  # top-level / nested bare array
                if isinstance(n, list):
                    nxt.extend(("ok", x) for x in n[:MAX_ITEMS_CHECKED])
                continue
            if not isinstance(n, dict):
                continue
            if key not in n:
                if last:
                    nxt.append(("missing", None))
                continue
            v = n[key]
            if each:
                if isinstance(v, list):
                    nxt.extend(("ok", x) for x in v[:MAX_ITEMS_CHECKED])
                continue
            nxt.append(("ok", v))
        if last:
            return nxt
        nodes = [v for (k, v) in nxt if k == "ok"]
    return []


_FORMATS = {
    "hm": re.compile(r"^\d{1,2}:\d{2}(:\d{2})?$"),
    "ymd": re.compile(r"^\d{4}-\d{2}-\d{2}$"),
    "iso": re.compile(r"^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?$"),
    "id": re.compile(r"^[0-9a-fA-F]{24}$"),
}


def _value_ok(v, extra):
    """extra = None | ('enum', [...]) | ('fmt', name). Returns bool; the value itself is never reported."""
    if extra is None or v is None:
        return True
    kind, arg = extra
    if kind == "enum":
        return v in arg
    if kind == "fmt":
        return isinstance(v, str) and bool(_FORMATS[arg].match(v))
    return True


def check_field(body, spec):
    """spec = (path, allowed_types, required, extra). Returns (status, detail); detail has only types/counts.
    status: PASS | FAIL | N/A"""
    path, allowed, required, extra = spec
    leaves = _walk(body, path)
    if not leaves:
        if "[]" in path:
            return "N/A", "no rows to check"
        return ("FAIL", "key path not reachable") if required else ("N/A", "optional, parent absent")
    seen = {}
    bad_type = bad_value = missing = 0
    for kind, v in leaves:
        if kind == "missing":
            missing += 1
            continue
        t = type_name(v)
        seen[t] = seen.get(t, 0) + 1
        if t not in allowed:
            bad_type += 1
        elif not _value_ok(v, extra):
            bad_value += 1
    n = len(leaves)
    types_seen = ", ".join(f"{t}x{c}" for t, c in sorted(seen.items())) or "none"
    detail = f"checked {n}; types seen: {types_seen}; expected {'|'.join(sorted(allowed))}"
    if extra:
        detail += f"; {extra[0]}={extra[1] if extra[0] == 'fmt' else 'listed values'}"
    if missing and required:
        return "FAIL", f"{detail}; missing in {missing}/{n}"
    if missing and not required and missing == n:
        return "N/A", f"optional, absent in all {n}"
    if bad_type:
        return "FAIL", f"{detail}; wrong type in {bad_type}/{n}"
    if bad_value:
        return "FAIL", f"{detail}; unexpected value/format in {bad_value}/{n}"
    return "PASS", detail


def check_expectations(body, specs):
    return [(s[0], *check_field(body, s)) for s in specs]


def body_summary(body):
    """Top-level shape only: 'dict' or 'list[<len>]'."""
    if isinstance(body, list):
        return f"list[{len(body)}]"
    return type_name(body)


def endpoint_verdict(status):
    if status == 404:
        return "NOT-DEPLOYED(404)"
    if status == 200:
        return "PASS"
    return "FAIL"


# ───────────────────────────── expectations table ─────────────────────────────
# (path, allowed_types, required, extra). `S`/`N` shortcuts. Each endpoint block cites the BACKEND code
# (eldermin-backend) and the APP model (eldermin-teacher-app) that consumes the keys.
S = {"str"}
SN = {"str", "null"}
I = {"int"}
B = {"bool"}
NUM = {"int", "float"}
L = {"list"}
D = {"dict"}
DN = {"dict", "null"}
CYCLE = ("enum", ["both", "A", "B"])

EXPECTATIONS = {
    # POST /auth/login. Backend auth.service.ts login; app: login_result.dart.
    "login": [
        ("accessToken", S, True, None),
        ("user", D, True, None),
        ("user.role", S, True, None),
        ("institution", D, True, None),
    ],
    # GET /auth/me: user document flat. App: auth_me.dart (role from primaryRole|role).
    "auth_me": [
        ("role", S | {"null"}, False, None),
        ("primaryRole", S | {"null"}, False, None),
    ],
    # GET /staff-portal/me. Backend staff-portal.controller.ts:30-31 -> staff-portal.service.ts getMe :112-165
    # (response object ~:126-165). App: staff_me.dart.
    "staff_me": [
        ("staffId", S, True, ("fmt", "id")),
        ("user", D, True, None),
        ("user.name", S, True, None),  # U9: presence on real docs
        ("user.avatarUrl", SN, False, None),
        ("department", SN, False, None),
        ("campus", DN, False, None),
        ("campus.name", SN, False, None),
        ("teacherProfile", DN, True, None),
        ("institution", D, True, None),
    ],
    # staff_me for a CLASS teacher additionally (staff-portal.service.ts getMe, classTeacherOf block; app teacher_profile.dart ClassTeacherInfo).
    "staff_me_class": [
        ("teacherProfile.classTeacherOf", D, True, None),
        ("teacherProfile.classTeacherOf.gradeName", S, True, None),
        ("teacherProfile.classTeacherOf.sectionName", SN, False, None),
    ],
    # GET /staff-portal/timetable?date=. Backend staff-teaching.service.ts:153-225 (slots :188-200, days :217-222).
    # App: lib/core/models/home/timetable.dart MyTimetable/TimetableDay/TimetableSlot.
    "timetable": [
        ("from", S, True, ("fmt", "ymd")),
        ("to", S, True, ("fmt", "ymd")),
        ("days", L, True, None),
        ("days[].date", S, True, ("fmt", "ymd")),
        ("days[].dayOfWeek", I, True, None),
        ("days[].weekCycle", SN, True, None),  # documented ALWAYS null (U1); a string means the server rule changed
        ("days[].slots", L, True, None),
        ("days[].slots[].timetableId", S, True, ("fmt", "id")),
        ("days[].slots[].gradeLevel", S, True, None),
        ("days[].slots[].sectionName", SN, False, None),
        ("days[].slots[].periodNo", I, True, None),
        ("days[].slots[].startTime", S, True, ("fmt", "hm")),  # U7
        ("days[].slots[].endTime", S, True, ("fmt", "hm")),
        ("days[].slots[].subject", S, True, None),
        ("days[].slots[].roomNo", S, True, None),
        ("days[].slots[].type", S, True, None),
        ("days[].slots[].weekCycle", S, True, CYCLE),
        ("days[].slots[].splitGroup", DN, True, None),
        ("days[].slots[].splitGroup.name", S, True, None),
        ("days[].slots[].splitGroup.roomNo", S, False, None),
    ],
    # GET /staff-portal/homework/pending-grading. Backend staff-teaching.service.ts:58-117 (items :104-114).
    # App: lib/core/models/home/pending_grading.dart.
    "pending_grading": [
        ("total", I, True, None),
        ("items", L, True, None),
        ("items[].assignmentId", S, True, ("fmt", "id")),
        ("items[].title", S, True, None),
        ("items[].subject", S, False, None),
        ("items[].gradeLevel", S, True, None),
        ("items[].sectionName", SN, False, None),
        ("items[].dueDate", SN, True, ("fmt", "iso")),
        ("items[].submittedCount", I, True, None),
        ("items[].totalSubmissions", I, True, None),
        ("items[].oldestSubmittedAt", SN, True, ("fmt", "iso")),
        ("generatedAt", S, True, ("fmt", "iso")),
    ],
    # GET /teaching/lesson-plans (bare array). Backend teaching.service.ts:143-154; schema lesson-plan.schema.ts.
    # App: teaching.dart LessonPlan (topic, NOT title).
    "lesson_plans": [
        ("[]._id", S, True, ("fmt", "id")),
        ("[].topic", S, True, None),
        ("[].teacherId", S, True, None),
        ("[].status", S, True, ("enum", ["draft", "submitted", "approved", "rejected", "overdue"])),
        ("[].planDate", S, False, ("fmt", "iso")),
    ],
    # GET /teaching/lesson-plans?teacherId=<my staffId> (Phase 6a, the full MY-plans list). Backend teaching.controller.ts:59-60 ->
    # teaching.service.ts:151-162 (bare array, planDate desc, hard limit 100); schema lesson-plan.schema.ts:7-42.
    # App: lib/core/models/academic/lesson_plan_models.dart LessonPlanRecord. rejectionReason / approverNotes are optional (set by approve / reject).
    "lesson_plans_mine": [
        ("[]._id", S, True, ("fmt", "id")),
        ("[].topic", S, True, None),
        ("[].subject", S, True, None),
        ("[].gradeLevel", S, True, None),
        ("[].sectionName", SN, False, None),
        ("[].teacherId", SN, True, None),
        ("[].planDate", S, True, ("fmt", "iso")),
        ("[].durationMins", NUM, False, None),
        ("[].learningObjectives", L, False, None),
        ("[].resources", L, False, None),
        ("[].teachingMethodology", SN, False, None),
        ("[].status", S, True, ("enum", ["draft", "submitted", "approved", "rejected", "overdue"])),
        ("[].rejectionReason", SN, False, None),
        ("[].approverNotes", SN, False, None),
    ],
    # GET /syllabus?teacherId=<my staffId> (Phase 6a). Backend syllabus.controller.ts:106-109 -> syllabus.service.ts:95-110 (bare array of FULL
    # documents, no pagination); schema syllabus.schema.ts:19-183; DTO syllabus.dto.ts:152-161. App: syllabus_models.dart Syllabus.
    "syllabi": [
        ("[]._id", S, True, ("fmt", "id")),
        ("[].subjectName", S, True, None),
        ("[].gradeLevel", S, True, None),
        ("[].sectionName", SN, False, None),
        ("[].term", SN, False, None),
        ("[].academicYearLabel", S, True, None),
        ("[].status", S, True, ("enum", ["draft", "active", "approved", "archived"])),
        ("[].trackStatus", S, False, ("enum", ["not_started", "on_track", "behind", "completed"])),
        ("[].teacherId", SN, False, None),
        ("[].totalTopics", I, False, None),
        ("[].coveredTopics", I, False, None),
        ("[].coveragePct", NUM, False, None),
        ("[].units", L, True, None),
        ("[].units[].unitNo", NUM, True, None),
        ("[].units[].topics", L, False, None),
        ("[].units[].topics[].topicNo", NUM, True, None),
        ("[].units[].topics[].topicName", S, True, None),
        ("[].units[].topics[].isCovered", B, False, None),
        ("[].units[].topics[].subTopics", L, False, None),
        ("[].units[].topics[].lessons", L, False, None),
    ],
    # GET /syllabus/weekly-planner?teacherId=<my staffId> (Phase 6a; CURRENT week only). Backend syllabus.controller.ts:31-37 ->
    # syllabus.service.ts:301-332. App: syllabus_models.dart PlannerEntry. An empty array is a legitimate answer.
    "weekly_planner": [
        ("[].syllabusId", S, True, ("fmt", "id")),
        ("[].subjectName", S, True, None),
        ("[].gradeLevel", S, True, None),
        ("[].sectionName", SN, False, None),
        ("[].currentWeek", I, True, None),
        ("[].subTopics", L, True, None),
        ("[].subTopics[].unitNo", NUM, True, None),
        ("[].subTopics[].topicNo", NUM, True, None),
        ("[].subTopics[].subTopicNo", NUM, True, None),
        ("[].subTopics[].subTopicName", S, True, None),
        ("[].subTopics[].isCovered", B, False, None),
    ],
    # GET /teaching/ptm?teacherId&from&to. Backend ptm.service.ts:91-104; schema ptm-meeting.schema.ts:29-68.
    # App: teaching.dart PtmMeeting; agenda rules in lib/core/utils/ptm_agenda.dart.
    "ptm_range": [
        ("[]._id", S, True, ("fmt", "id")),
        ("[].teacherId", S, True, None),
        ("[].scheduledDate", S, True, ("fmt", "iso")),
        ("[].startTime", S, False, ("fmt", "hm")),  # U8
        ("[].endTime", S, False, ("fmt", "hm")),
        ("[].studentName", S, False, None),
        ("[].status", S, True, ("enum", ["requested", "confirmed", "completed", "cancelled", "no_show"])),
    ],
    # GET /teaching/ptm/upcoming/mine?teacherId. Backend ptm.service.ts:178-183 (requested|confirmed only).
    "ptm_upcoming": [
        ("[]._id", S, True, ("fmt", "id")),
        ("[].teacherId", S, True, None),
        ("[].scheduledDate", S, True, ("fmt", "iso")),
        ("[].startTime", S, False, ("fmt", "hm")),
        ("[].endTime", S, False, ("fmt", "hm")),
        ("[].status", S, True, ("enum", ["requested", "confirmed"])),
    ],
    # GET /teaching/fixtures?teacherId&from&to. Backend substitution.service.ts:232-245; schema :28-57.
    # App: teaching.dart Substitution.
    "fixtures": [
        ("[]._id", S, True, ("fmt", "id")),
        ("[].date", S, True, ("fmt", "iso")),
        ("[].originalTeacherId", SN, True, None),
        ("[].substituteTeacherId", SN, False, None),
        ("[].status", S, True, ("enum", ["open", "assigned", "completed", "cancelled"])),
        ("[].startTime", S, False, ("fmt", "hm")),
    ],
    # GET /staff-portal/threads?status=open. Backend staff-portal.service.ts:217-223; schema
    # notification-and-message.schema.ts:41-59. App: messaging.dart (ThreadsResult/MessageThread).
    "threads_open": [
        ("items", L, True, None),
        ("unreadCount", I, True, None),
        ("items[]._id", S, True, ("fmt", "id")),
        ("items[].staffHasUnread", B, True, None),
        ("items[].status", S, True, ("enum", ["open"])),  # status=open must filter server-side
        ("items[].lastMessageAt", SN, False, ("fmt", "iso")),
    ],
    # GET /staff-portal/notifications/unread-count. Backend staff-portal.controller.ts:36-37 -> staff-portal.service.ts:191-195. App: home_repository.dart.
    "unread_count": [("unreadCount", I, True, None)],
    # GET /students/attendance/list?grade&section&from&to&limit=1. Backend students.service.ts:1825-1852.
    # App: class_snapshot.dart attendanceTotalFromJson (meta.total).
    "attendance_list": [
        ("data", L, True, None),
        ("meta", D, True, None),
        ("meta.total", I, True, None),
    ],
    # GET /students?grade=..&section=..&status=active&limit=200 (Phase 5a roster). Backend students.controller.ts:54-59 ->
    # students.service.ts:515-623 (meta :623). App: lib/core/models/classroom/student_models.dart StudentSummary (whitelist: only
    # these keys are parsed; fee/guardian/contact keys are NEVER checked or printed).
    "students_list": [
        ("data", L, True, None),
        ("data[]._id", S, True, ("fmt", "id")),
        ("data[].firstName", S, True, None),
        ("data[].lastName", S, True, None),
        ("data[].currentGrade", S, True, None),
        ("data[].currentSection", SN, False, None),
        ("data[].currentRollNumber", SN, False, None),
        ("data[].status", S, False, None),
        ("data[].currentAcademicYear", SN, False, None),
        ("meta", D, True, None),
        ("meta.total", I, True, None),
        ("meta.pages", I, True, None),
    ],
    # GET /students/filters/grades-sections. Backend students.service.ts:450-462. App: GradesSections.
    "grades_sections": [
        ("grades", L, True, None),
        ("sections", L, True, None),
    ],
    # GET /students/:id/360 (keys the app parses only). Backend students.service.ts:1483-1575. App: student_360.dart Student360.
    "student_360": [
        ("student", D, True, None),
        ("student._id", S, True, ("fmt", "id")),
        ("student.firstName", S, True, None),
        ("student.currentGrade", S, True, None),
        ("student.guardians", L, False, None),
        ("student.guardians[].name", S, False, None),
        ("student.guardians[].relation", S, False, None),
        ("attendance", D, True, None),
        ("attendance.totalDays", I, True, None),
        ("attendance.percentage", {"int", "float"}, True, None),
        ("attendance.recent", L, True, None),
        ("behaviour", D, True, None),
        ("behaviour.recent", L, True, None),
        ("assessments", D, True, None),
        ("assessments.recent", L, True, None),
    ],
    # GET /students/attendance/list (full record keys the app parses). Backend students.service.ts:1825-1852; schema ATT:14-40.
    # App: attendance_models.dart AttendanceRecord.
    "attendance_records": [
        ("data", L, True, None),
        ("data[].studentId", S, True, ("fmt", "id")),
        ("data[].date", S, True, ("fmt", "iso")),
        ("data[].status", S, True, ("enum", ["present", "absent", "late", "excused", "half_day"])),
        ("meta", D, True, None),
        ("meta.total", I, True, None),
        ("meta.pages", I, True, None),
    ],
    # GET /students/:id/attendance/summary?month=YYYY-MM: bare array of {_id: status, count}. Backend students.service.ts:1854-1864.
    "attendance_summary": [
        ("[]._id", S, False, None),
        ("[].count", I, False, None),
    ],
    # GET /students/class-roster-diagnostic?grade&section. Backend students.service.ts:478-513. App: RosterCount.
    "roster": [
        ("activeCount", I, True, None),
        ("totalInClass", I, True, None),
    ],
    # GET /teaching/assignments?teacherId=<my staffId> (Phase 5b). Backend teaching.controller.ts:194-195 -> teaching.service.ts:861-871
    # (bare array, sorted dueDate desc, unbounded); schema modules/teaching/schemas/assignment.schema.ts:7-33.
    # App: lib/core/models/homework/homework_models.dart Assignment (whitelist; tenantId/institutionId/campusId never parsed).
    "assignments": [
        ("[]._id", S, True, ("fmt", "id")),
        ("[].teacherId", SN, False, None),
        ("[].title", S, True, None),
        ("[].subject", S, True, None),
        ("[].gradeLevel", S, True, None),
        ("[].sectionName", SN, False, None),
        ("[].type", S, False, None),
        ("[].status", S, True, ("enum", ["draft", "assigned", "submitted", "graded", "overdue"])),
        ("[].dueDate", SN, False, ("fmt", "iso")),
        ("[].totalMarks", NUM, False, None),
        ("[].passingMarks", NUM, False, None),
        ("[].submissionsCount", I, False, None),
        ("[].attachmentS3Keys", L, False, None),
    ],
    # GET /teaching/assignments/:id/submissions (Phase 5b). Backend teaching.controller.ts:209-210 -> teaching.service.ts:990-1002 ->
    # { assignment, submissions[] }; schema assignment-submission.schema.ts:14-39. App: homework_models.dart SubmissionsResult/Submission.
    "submissions": [
        ("assignment", D, True, None),
        ("assignment._id", S, True, ("fmt", "id")),
        ("assignment.totalMarks", NUM, False, None),
        ("submissions", L, True, None),
        ("submissions[]._id", S, True, ("fmt", "id")),
        ("submissions[].studentName", S, False, None),
        ("submissions[].status", S, True, ("enum", ["pending", "submitted", "late", "graded", "missed"])),
        ("submissions[].isLate", B, False, None),
        ("submissions[].maxGrade", NUM, False, None),
        ("submissions[].grade", NUM | {"null"}, False, None),
        ("submissions[].submittedAt", SN, False, ("fmt", "iso")),
        ("submissions[].attachmentS3Keys", L, False, None),
    ],
    # GET /behaviour/records?limit=5 (Phase 5b). Backend behaviour.controller.ts:43-47 -> behaviour.service.ts:170-207 ({ data, meta });
    # schema behaviour/schemas/behaviour.schema.ts:14-106. App: lib/core/models/behaviour/behaviour_models.dart BehaviourRecord/BehaviourPage.
    # meta.page / meta.limit are echoed as the raw query STRINGS when sent (no DTO) so they are not asserted here.
    "behaviour_records": [
        ("data", L, True, None),
        ("data[]._id", S, True, ("fmt", "id")),
        ("data[].studentId", S, True, ("fmt", "id")),
        ("data[].studentName", S, True, None),
        ("data[].grade", S, True, None),
        ("data[].section", SN, False, None),
        ("data[].date", S, True, ("fmt", "iso")),
        ("data[].type", S, True, ("enum", ["positive", "negative", "neutral"])),
        ("data[].category", S, True, None),
        ("data[].title", S, True, None),
        ("data[].description", S, True, None),
        ("data[].severity", S, False, ("enum", ["low", "medium", "high", "critical"])),
        ("data[].points", NUM, False, None),
        ("data[].resolved", B, False, None),
        ("data[].reportedBy", S, True, None),
        ("data[].reportedById", SN, False, None),
        ("meta", D, True, None),
        ("meta.total", I, True, None),
        ("meta.pages", I, True, None),
    ],
    # GET /behaviour/tarbiyah?limit=1 (Phase 5b, read-only). Backend behaviour.controller.ts:95-99 -> behaviour.service.ts:319-334;
    # schema behaviour.schema.ts:147-190. App: behaviour_models.dart TarbiyahAssessment.
    "tarbiyah": [
        ("data", L, True, None),
        ("data[]._id", S, True, ("fmt", "id")),
        ("data[].studentId", S, True, ("fmt", "id")),
        ("data[].period", S, True, None),
        ("data[].assessmentDate", S, True, ("fmt", "iso")),
        ("data[].traits", L, False, None),
        ("data[].traits[].traitKey", S, True, None),
        ("data[].traits[].score", NUM, True, None),
        ("data[].overallPercentage", NUM, False, None),
        ("data[].overallRating", S, False, ("enum", ["excellent", "good", "satisfactory", "needs_improvement", "critical"])),
        ("meta", D, True, None),
        ("meta.total", I, True, None),
    ],
}

# ───────────────────────────── runner ─────────────────────────────


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):  # never follow: a token must not leave the configured host
        return None


_opener = urllib.request.build_opener(NoRedirect)


def http(method, base, path, query=None, token=None, json_body=None):
    """Returns (status:int|None, parsed_body|None). Error text/bodies are never surfaced."""
    if not request_allowed(method, path):
        raise RuntimeError("read-only tool: only GET and POST /auth/login are allowed")
    url = base + path + ("?" + urllib.parse.urlencode(query) if query else "")
    data = json.dumps(json_body).encode() if json_body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with _opener.open(req, timeout=TIMEOUT) as r:
            raw, status = r.read(), r.status
    except urllib.error.HTTPError as e:
        raw, status = b"", e.code
    except Exception:  # network/DNS/TLS: report the fact only
        return None, None
    try:
        return status, json.loads(raw) if raw else None
    except ValueError:
        return status, None


class Report:
    def __init__(self):
        self.lines = []
        self.fails = 0
        self.counts = {"PASS": 0, "FAIL": 0, "NOT-DEPLOYED(404)": 0, "SKIP": 0}

    def line(self, s=""):
        self.lines.append(s)
        print(s)

    def endpoint(self, who, label, status, body, spec_key, note=""):
        if status is None:
            verdict = "FAIL"
            head = "no response (network/TLS/DNS)"
        else:
            verdict = endpoint_verdict(status)
            head = f"HTTP {status}"
        self.counts[verdict] += 1
        if verdict == "FAIL":
            self.fails += 1
        self.line(f"[{verdict}] {who}: {label} -> {head}" + (f" ({note})" if note else ""))
        if status != 200 or spec_key is None:
            return
        self.line(f"        body: {body_summary(body)}")
        for path, st, detail in check_expectations(body, EXPECTATIONS[spec_key]):
            if st == "FAIL":
                self.fails += 1
            self.line(f"        {st:<4} {path} : {detail}")

    def skip(self, who, label, why):
        self.counts["SKIP"] += 1
        self.line(f"[SKIP] {who}: {label} ({why})")


def _local_today():
    return datetime.date.today()


def _utc_window(d):
    f = datetime.datetime(d.year, d.month, d.day, tzinfo=datetime.timezone.utc)
    t = f + datetime.timedelta(hours=23, minutes=59, seconds=59, milliseconds=999)
    iso = lambda x: x.strftime("%Y-%m-%dT%H:%M:%S.") + f"{x.microsecond // 1000:03d}Z"
    return iso(f), iso(t)


def login(base, slug, email, password):
    body = {"email": email, "password": password}
    if slug:
        body["slug"] = slug
    return http("POST", base, "/auth/login", json_body=body)


def run_user(rep, who, base, slug, email, password, class_teacher):
    st, body = login(base, slug, email, password)
    rep.endpoint(who, "POST /auth/login", st, body, "login")
    token = body.get("accessToken") if st == 200 and isinstance(body, dict) else None
    if not isinstance(token, str) or not token:
        rep.skip(who, "all GET endpoints", "no session")
        return

    def get(path, query=None):
        return http("GET", base, path, query, token)

    st, b = get("/auth/me")
    rep.endpoint(who, "GET /auth/me", st, b, "auth_me")
    st, me = get("/staff-portal/me")
    rep.endpoint(who, "GET /staff-portal/me", st, me, "staff_me")
    staff_id = me.get("staffId") if st == 200 and isinstance(me, dict) else None
    class_of = None
    if st == 200 and isinstance(me, dict):
        tp = me.get("teacherProfile")
        class_of = tp.get("classTeacherOf") if isinstance(tp, dict) else None
    if class_teacher:
        if st == 200:
            for path, s2, detail in check_expectations(me, EXPECTATIONS["staff_me_class"]):
                if s2 == "FAIL":
                    rep.fails += 1
                rep.line(f"        {s2:<4} {path} : {detail}   (class teacher)")
    else:
        rep.line(f"        info: classTeacherOf is {'a dict' if isinstance(class_of, dict) else 'not set'} for this account")

    today = _local_today()
    frm, to = _utc_window(today)
    if not class_teacher:
        st, b = get("/staff-portal/timetable", {"date": today.isoformat()})
        rep.endpoint(who, "GET /staff-portal/timetable?date=<today>", st, b, "timetable")
        st, b = get("/staff-portal/homework/pending-grading")
        rep.endpoint(who, "GET /staff-portal/homework/pending-grading", st, b, "pending_grading")
        if staff_id:
            st, b = get("/teaching/lesson-plans", {"teacherId": staff_id, "status": "submitted"})
            rep.endpoint(who, "GET /teaching/lesson-plans?teacherId&status=submitted", st, b, "lesson_plans")
            st, b = get("/teaching/ptm", {"teacherId": staff_id, "from": frm, "to": to})
            rep.endpoint(who, "GET /teaching/ptm?teacherId&from&to", st, b, "ptm_range")
            st, b = get("/teaching/ptm/upcoming/mine", {"teacherId": staff_id})
            rep.endpoint(who, "GET /teaching/ptm/upcoming/mine?teacherId", st, b, "ptm_upcoming")
            st, b = get("/teaching/fixtures", {"teacherId": staff_id, "from": frm, "to": to})
            rep.endpoint(who, "GET /teaching/fixtures?teacherId&from&to", st, b, "fixtures")
        else:
            for lbl in ("lesson-plans", "ptm", "ptm/upcoming/mine", "fixtures"):
                rep.skip(who, f"GET /teaching/{lbl}", "no staffId from /staff-portal/me")
        st, b = get("/staff-portal/threads", {"status": "open"})
        rep.endpoint(who, "GET /staff-portal/threads?status=open", st, b, "threads_open")
        st, b = get("/staff-portal/notifications/unread-count")
        rep.endpoint(who, "GET /staff-portal/notifications/unread-count", st, b, "unread_count")
    # Phase 5b (all GET, read-only). Behaviour: first records page + first Tarbiyah page of the campus (no ids are printed).
    st, b = get("/behaviour/records", {"limit": 5, "page": 1})
    rep.endpoint(who, "GET /behaviour/records?limit=5", st, b, "behaviour_records")
    st, b = get("/behaviour/tarbiyah", {"limit": 1, "page": 1})
    rep.endpoint(who, "GET /behaviour/tarbiyah?limit=1", st, b, "tarbiyah")
    if not class_teacher:
        if staff_id:
            st, lst = get("/teaching/assignments", {"teacherId": staff_id})
            rep.endpoint(who, "GET /teaching/assignments?teacherId", st, lst, "assignments")
            first_a = None
            if st == 200 and isinstance(lst, list):
                # first NON-draft assignment (drafts have no submission rows)
                first_a = next((x.get("_id") for x in lst if isinstance(x, dict) and x.get("status") != "draft"), None)
            if isinstance(first_a, str) and _FORMATS["id"].match(first_a):
                st, b = get(f"/teaching/assignments/{first_a}/submissions")
                rep.endpoint(who, "GET /teaching/assignments/:id/submissions", st, b, "submissions")
            else:
                rep.skip(who, "GET /teaching/assignments/:id/submissions", "no assignment of mine to check")
        else:
            rep.skip(who, "GET /teaching/assignments", "no staffId from /staff-portal/me")
    # Phase 6a (all GET, read-only): my lesson plans, my syllabi, the weekly planner. No write route is ever called.
    if not class_teacher:
        if staff_id:
            st, b = get("/teaching/lesson-plans", {"teacherId": staff_id})
            rep.endpoint(who, "GET /teaching/lesson-plans?teacherId (all statuses)", st, b, "lesson_plans_mine")
            st, b = get("/syllabus", {"teacherId": staff_id})
            rep.endpoint(who, "GET /syllabus?teacherId", st, b, "syllabi")
            st, b = get("/syllabus/weekly-planner", {"teacherId": staff_id})
            rep.endpoint(who, "GET /syllabus/weekly-planner?teacherId", st, b, "weekly_planner")
        else:
            for lbl in ("lesson-plans (all statuses)", "syllabus", "syllabus/weekly-planner"):
                rep.skip(who, f"GET /{lbl}", "no staffId from /staff-portal/me")
    if class_teacher:
        grade = class_of.get("gradeName") if isinstance(class_of, dict) else None
        section = class_of.get("sectionName") if isinstance(class_of, dict) else None
        if not isinstance(grade, str) or not grade:
            rep.skip(who, "class roster / attendance", "no classTeacherOf.gradeName in /staff-portal/me")
            return
        q = {"grade": grade}
        if isinstance(section, str) and section:
            q["section"] = section
        st, b = get("/students/class-roster-diagnostic", q)
        rep.endpoint(who, "GET /students/class-roster-diagnostic?grade&section", st, b, "roster")
        st, b = get("/students/attendance/list", {**q, "from": frm, "to": to, "limit": 1})
        rep.endpoint(who, "GET /students/attendance/list?grade&section&from&to&limit=1", st, b, "attendance_list")
        # Phase 5a (all GET, read-only): roster, grades/sections, attendance window (noon-bracket), 360 + summary of ONE roster student.
        st, b = get("/students/filters/grades-sections")
        rep.endpoint(who, "GET /students/filters/grades-sections", st, b, "grades_sections")
        st, roster = get("/students", {"grade": grade, **({"section": section} if section else {}), "status": "active", "limit": 200})
        rep.endpoint(who, "GET /students?grade&section&status=active&limit=200", st, roster, "students_list")
        win_from = (today - datetime.timedelta(days=1)).isoformat() + "T12:00:00.000Z"
        win_to = today.isoformat() + "T12:00:00.000Z"
        st, b = get("/students/attendance/list", {**q, "from": win_from, "to": win_to, "limit": 1000})
        rep.endpoint(who, "GET /students/attendance/list?grade&section&from&to (noon window)", st, b, "attendance_records")
        first = None
        if st == 200 and isinstance(roster, dict) and isinstance(roster.get("data"), list) and roster["data"]:
            row = roster["data"][0]
            first = row.get("_id") if isinstance(row, dict) else None
        if isinstance(first, str) and _FORMATS["id"].match(first):
            st, b = get(f"/students/{first}/360")
            rep.endpoint(who, "GET /students/:id/360", st, b, "student_360")
            st, b = get(f"/students/{first}/attendance/summary", {"month": today.strftime("%Y-%m")})
            rep.endpoint(who, "GET /students/:id/attendance/summary?month", st, b, "attendance_summary")
        else:
            rep.skip(who, "GET /students/:id/360 and attendance/summary", "no roster student to check")


def main(argv):
    write = "--no-write" not in argv
    env_path = ENV_PATH
    if "--env" in argv:  # test hook: alternative env file (e.g. pointing at the local stub)
        env_path = argv[argv.index("--env") + 1]
    if not os.path.exists(env_path):
        print(USAGE)
        return 0
    with open(env_path, encoding="utf-8") as f:
        env = parse_env(f.read())
    base_raw = env.get("STAGING_BASE_URL", "")
    if not base_raw:
        print("STAGING_BASE_URL is empty in tool/dev/.env.staging - nothing was called.")
        return 0
    if host_is_blocked(base_raw):
        print("REFUSED: STAGING_BASE_URL points at the production host. This tool never runs against production.")
        return 2
    base = normalize_base(base_raw)
    rep = Report()
    rep.line("Teacher app Home - staging verification (read-only; values are never printed)")
    rep.line(f"host: {host_of(base)}   date: {_local_today().isoformat()}   (credentials, tokens, ids: never printed)")
    rep.line("")
    slug = env.get("SCHOOL_SLUG", "")
    if env.get("TEACHER_EMAIL") and env.get("TEACHER_PASSWORD"):
        rep.line("== Teacher ==")
        run_user(rep, "teacher", base, slug, env["TEACHER_EMAIL"], env["TEACHER_PASSWORD"], class_teacher=False)
    else:
        rep.line("TEACHER_EMAIL / TEACHER_PASSWORD missing - teacher checks skipped.")
    if env.get("CLASS_TEACHER_EMAIL") and env.get("CLASS_TEACHER_PASSWORD"):
        rep.line("")
        rep.line("== Class teacher ==")
        run_user(rep, "class-teacher", base, slug, env["CLASS_TEACHER_EMAIL"], env["CLASS_TEACHER_PASSWORD"], class_teacher=True)
    else:
        rep.line("")
        rep.line("CLASS_TEACHER_* not given - class card checks skipped.")
    rep.line("")
    c = rep.counts
    rep.line(f"SUMMARY: endpoints PASS={c['PASS']} FAIL={c['FAIL']} NOT-DEPLOYED(404)={c['NOT-DEPLOYED(404)']} SKIP={c['SKIP']}; "
             f"field FAILs counted in total FAIL count = {rep.fails}")
    if write:
        os.makedirs(OUT_DIR, exist_ok=True)
        name = "verify_staging_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + ".txt"
        with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8") as f:
            f.write("\n".join(rep.lines) + "\n")
        print(f"(redacted summary written to tool/dev/out/{name}, git-ignored)")
    return 1 if rep.fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
