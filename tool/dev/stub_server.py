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
                 ptmlist (GET /teaching/ptm range)  pendinggrading (GET /staff-portal/homework/pending-grading)
                 mytimetable (GET /staff-portal/timetable)
       value 'new' on feature=new applies to pendinggrading + mytimetable (e.g. feature=new&value=404 emulates a server
       without the feat/staff-portal follow-ups, to test the app's N+1 / old-timetable FALLBACKS).
  POST /__stub/attendance?count=<n>   seed n "present" records for TODAY for Grade 5 A (default 0; a 28-weekday history is always seeded)
Phase 5a (classroom) features for /__stub/mode: students (GET /students)  studentsgrades (GET /students/filters/grades-sections)
  student360 (GET /students/:id/360)  attsummary (GET /students/:id/attendance/summary)  attendance (GET /students/attendance/list)
  attbulk (POST /students/attendance/bulk).  Extra values: 409 (all) and drop (close the connection: offline path).
  Run with TZ=Asia/Karachi (or America/Los_Angeles ...) to emulate a non-UTC server clock (attendance dates are stored as SERVER-LOCAL midnight).
  GET /__stub/state shows the in-memory attendance record count and the last x-academic-year header the bulk call carried.
Phase 5b (homework, upload, behaviour) logic lives in stub_5b.py with backend file:line citations. Extra /__stub/mode features:
  homework (GET /teaching/assignments + /:id/submissions)  hwwrite (POST/PATCH/DELETE /teaching/assignments[/:id])
  hwgrade (PATCH .../submissions/:sid)  upload (POST /upload/single/:folder)  signedurl (GET /upload/signed-url)
  behaviour (GET /behaviour/records)  behaviourcreate (POST)  behaviourresolve (PATCH records/:id/resolve)  tarbiyah (GET /behaviour/tarbiyah)
  Extra values on any feature: 400 (validation-style message), 413 (File too large), 422, 403, 404, 500, drop, slow, empty.
  GET /__stub/state -> phase5b: counts + the last upload's {folder,fileType,fileSize}.
Phase 6a (lesson plans, syllabus) logic lives in stub_6a.py with backend file:line citations and UNVERIFIED marks. /__stub/mode features:
  lessonplans lpcreate lpupdate lpparse syllabus sylone sylmark planner   (special values: see the stub_6a.py docstring: aioff, badjson,
  googledenied, notfound)   GET /__stub/state -> phase6a: counts + the last PATCH/create keys and parse-upload summary.
Phase 6b (assessments, marks entry, report remarks, quiz grading, curriculum, library) lives in stub_6b.py (citations, UNVERIFIED marks).
  /__stub/mode features: assessments assessone marks marksbulk reportcards remarks quizlist quizone quizgrade curriculum curone library
  specials: marksbulk=partial500|toobig|lockedrows|lockedrows403|published403 (403 + the planned lock text), upload=503 (storage not configured), quizgrade=published403, marks=allverified, quizone=nopaper|notmyclass, quizgrade=quizbounds|regrade|notmyclass,
  remarks=notclassteacher|notfound (the error modes copy the landed backend hardening, see stub_6b.py); feature `bigclass`=on -> a 230-student Grade 5 A. GET /__stub/state -> phase6b.
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
NEW_FEATURES = ("pendinggrading", "mytimetable")  # feat/staff-portal follow-ups; feature=new switches both


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
        "subjectsCanTeach": ["Science"], "gradeLevelsCanTeach": ["5"],
        # TeacherProfile.currentAssignments (teacher-profile.schema.ts:24): sectionId, sectionName, subjectName, gradeLevel,
        # periodsPerWeek. DUMMY. The app scopes rosters to these classes (+ the class-teacher class).
        "currentAssignments": [
            {"sectionId": "64a0000000000000000005a1", "sectionName": "A", "subjectName": "Mathematics", "gradeLevel": "Grade 5", "periodsPerWeek": 5},
            {"sectionId": "64a0000000000000000006b1", "sectionName": "B", "subjectName": "Science", "gradeLevel": "Grade 6", "periodsPerWeek": 4},
        ],
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

    # DUMMY: two extra periods around the server clock (today's weekday) so a run at any time of day
    # shows a current + a next period. Skipped near midnight (HH:mm must not wrap).
    nowdt = datetime.datetime.now()
    if 1 <= nowdt.hour < 22:
        def hm(dt):
            return dt.strftime("%H:%M")
        today_idx = (nowdt.weekday() + 1) % 7
        a.append(_period(today_idx, 20, hm(nowdt - datetime.timedelta(minutes=10)), hm(nowdt + datetime.timedelta(minutes=30)),
                         "History (live dummy)", staff_id, name, "105"))
        a.append(_period(today_idx, 21, hm(nowdt + datetime.timedelta(minutes=40)), hm(nowdt + datetime.timedelta(minutes=80)),
                         "Geography (live dummy)", staff_id, name, "106"))

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
    docs = [doc(1, "Grade 5", "A", a, False), doc(2, "Grade 6", "B", b, True)]
    return docs


def split_only_doc(staff_id, name):
    """A class whose ONLY period for this teacher is inside splitGroups (period teacherId blank, S/TT:52-56).
    The OLD endpoint (GET /teaching/timetable/teacher/:id) does NOT return such a doc (TS:489 gap, verified in the
    shapes doc); the NEW GET /staff-portal/timetable DOES (staff-teaching.service.ts:161,178-182)."""
    sc = [
        {"label": "Group 1", "teacherId": staff_id, "teacherName": name, "roomNo": "Lang 3"},
        {"label": "Group 2", "teacherId": OTHER_STAFF, "teacherName": "Other Teacher (DUMMY)", "roomNo": "Lang 4"},
    ]
    periods = [_period(d, 9, "09:30", "10:10", "Languages (split only)", "", "", "", splits=sc) for d in range(1, 6)]
    return {
        "_id": _oid(0x103), "tenantId": _oid(0xa1), "institutionId": _oid(0xa2), "academicYearId": None,
        "campusId": "64a0000000000000000000c1", "gradeLevel": "Grade 7", "sectionName": "C", "sectionId": None,
        "status": "active", "periodsPerDay": 8, "workingDays": [1, 2, 3, 4, 5], "weekCycleEnabled": False,
        "cycleAnchor": None, "periods": periods, "createdBy": _oid(0xd1),
        "createdAt": "2026-08-01T06:00:00.000Z", "updatedAt": "2026-08-01T06:00:00.000Z",
    }


def my_timetable(staff_id, name, frm, to):
    """GET /staff-portal/timetable?date= | ?from=&to=  (NEW on feat/staff-portal; route staff-portal.controller.ts:91-92 ->
    staff-teaching.service.ts timetable() :153-225). Response { from, to, days:[{date, dayOfWeek, weekCycle, slots}] }
    (:224, :217-222). dayOfWeek computed in UTC from the date string, 0=Sun (:216). weekCycle on the DAY is ALWAYS null
    (:220, U1 A/B parity undeterminable). Slot fields :188-200: timetableId, gradeLevel, sectionName, periodNo, startTime,
    endTime (trimmed), subject, roomNo, type, weekCycle both|A|B (own tag, :184), splitGroup {name, subject, roomNo}|null
    (:181). A period is mine if teacherId==me (:178) or a splitGroup teacherId==me (:179-182). Slots sorted by startTime,
    periodNo, timetableId (:205-210). Dedupe key (:185). Data below is DUMMY. Campus filter (:163-164) not emulated."""
    docs = timetable_docs(staff_id, name) + [split_only_doc(staff_id, name)]
    by_day = {}
    seen = set()
    for tt in docs:
        for p in tt["periods"]:
            group = None
            room = (p["roomNo"] or "").strip()
            if p["teacherId"] != staff_id:
                g = next((x for x in p["splitGroups"] if x["teacherId"] == staff_id), None)
                if not g:
                    continue
                group = {"name": g["label"].strip(), "subject": p["subject"].strip(), "roomNo": g["roomNo"].strip()}
                room = group["roomNo"]
            week = p["weekCycle"] if p["weekCycle"] in ("A", "B") else "both"
            key = (tt["_id"], p["day"], p["periodNo"], week, group["name"] if group else "")
            if key in seen:
                continue
            seen.add(key)
            by_day.setdefault(p["day"], []).append({
                "timetableId": tt["_id"], "gradeLevel": tt["gradeLevel"],
                "sectionName": tt["sectionName"] or None, "periodNo": p["periodNo"],
                "startTime": p["startTime"].strip(), "endTime": p["endTime"].strip(), "subject": p["subject"].strip(),
                "roomNo": room, "type": p["type"] or "regular", "weekCycle": week, "splitGroup": group,
            })
    for slots in by_day.values():
        slots.sort(key=lambda x: (x["startTime"], x["periodNo"] or 0, x["timetableId"]))
    days = []
    d = frm
    while d <= to:
        dow = (d.weekday() + 1) % 7
        days.append({"date": d.isoformat(), "dayOfWeek": dow, "weekCycle": None, "slots": by_day.get(dow, [])})
        d += datetime.timedelta(days=1)
    return {"from": frm.isoformat(), "to": to.isoformat(), "days": days}


def parse_timetable_query(q):
    """Validation per staff-teaching.service.ts parseRange/validDate :232-252 -> (from, to) dates or an error string
    (HTTP 400 messages copied from the service)."""
    def valid(v):
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", v or ""):
            raise ValueError("Dates must be formatted YYYY-MM-DD.")
        try:
            return datetime.date.fromisoformat(v)
        except ValueError:
            raise ValueError("Invalid calendar date.")
    try:
        if "date" in q:
            if "from" in q or "to" in q:
                return "Use either date, or from and to."
            d = valid(q["date"][0])
            return d, d
        if "from" not in q or "to" not in q:
            return "Provide date=YYYY-MM-DD, or from and to."
        f, t = valid(q["from"][0]), valid(q["to"][0])
        span = (t - f).days
        if span < 0:
            return '"to" must not be before "from".'
        if span + 1 > 14:
            return "Range may span at most 14 days."
        return f, t
    except ValueError as e:
        return str(e)


def pending_grading(staff_id, limit):
    """GET /staff-portal/homework/pending-grading?limit=  (NEW on feat/staff-portal; route staff-portal.controller.ts:87-88 ->
    staff-teaching.service.ts pendingGrading() :58-117). Response { total, items[], generatedAt } (:102-116). Item fields
    :104-114: assignmentId, title, subject, gradeLevel, sectionName (null when absent, :109), dueDate ISO|null,
    submittedCount (= UNGRADED submitted|late, :87), totalSubmissions (:86), oldestSubmittedAt ISO|null (:113).
    Non-draft assignments of mine only (:64), zero-ungraded omitted (:93), total over ALL (:94), sorted by oldest ungraded
    then dueDate then title (:96-99), limit default 50 max 200 (:9-10,254-258). Built from the same dummy rows the old
    N+1 path serves (ASSIGNMENT_SUBS), so both paths agree. oldestSubmittedAt values are DUMMY."""
    rows = []
    for idx, a in enumerate(assignments(staff_id), start=1):
        if a["status"] == "draft":
            continue
        statuses = ASSIGNMENT_SUBS.get(idx, [])
        ungraded = sum(1 for st in statuses if st in ("submitted", "late"))
        if ungraded == 0:
            continue
        rows.append({
            "assignmentId": a["_id"], "title": a["title"], "subject": a["subject"], "gradeLevel": a["gradeLevel"],
            "sectionName": a["sectionName"] or None, "dueDate": a["dueDate"], "submittedCount": ungraded,
            "totalSubmissions": len(statuses),
            "oldestSubmittedAt": (datetime.datetime.utcnow() - datetime.timedelta(days=idx)).strftime("%Y-%m-%dT%H:%M:00.000Z"),
        })
    rows.sort(key=lambda r: (r["oldestSubmittedAt"] or "9", r["dueDate"] or "9", r["title"]))
    try:
        n = int(limit)
        n = 50 if n < 1 else min(n, 200)
    except (TypeError, ValueError):
        n = 50
    return {"total": sum(r["submittedCount"] for r in rows), "items": rows[:n],
            "generatedAt": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")}


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


def _ptm(staff_id, n, student, date, st, start, end):
    # PTMMeeting fields S/PTM:29-68 (verified); status enum requested|confirmed|completed|cancelled|no_show (S/PTM:51);
    # scheduledDate is the picked day stored as a Date, MIDNIGHT UTC ASSUMED (UNVERIFIED U8-ptm);
    # startTime/endTime format beyond the spec examples UNVERIFIED (U8).
    return {"_id": _oid(0x700 + n), "tenantId": _oid(0xa1), "studentId": _oid(0x200 + n), "studentName": student,
            "gradeLevel": "Grade 5", "sectionName": "A", "teacherId": staff_id, "teacherName": "Sample Teacher",
            "scheduledDate": _utc_midnight(date), "startTime": start, "endTime": end,
            "guardianName": "Sample Guardian (DUMMY)", "status": st, "academicYear": "2026-27",
            "discussionPoints": [], "actionItems": [], "parentAttended": False}


def _all_ptms(staff_id):
    """DUMMY meetings of one teacher. TODAY: one completed earlier, one confirmed whose time already passed (shown as
    'Earlier today' by the app's clock rule, status still confirmed), one cancelled, one remaining today (starts ~1 h
    from the server clock, clamped to the evening so it exists at any hour). Plus two future ones."""
    t = _today()
    now = datetime.datetime.now()
    rem_start = min(now + datetime.timedelta(minutes=60), now.replace(hour=23, minute=0, second=0, microsecond=0))
    if rem_start < now:  # after 23:00 the "remaining" meeting is intentionally already over; the app will show it as earlier
        rem_start = now
    hm = lambda dt: dt.strftime("%H:%M")
    return [
        _ptm(staff_id, 1, "Sample Student 1 (DUMMY)", t + datetime.timedelta(days=3), "confirmed", "10:00", "10:20"),
        _ptm(staff_id, 2, "Sample Student 2 (DUMMY)", t + datetime.timedelta(days=6), "requested", "11:00", "11:20"),
        _ptm(staff_id, 3, "Sample Student 3 (DUMMY)", t, "completed", "00:10", "00:30"),
        _ptm(staff_id, 4, "Sample Student 4 (DUMMY)", t, "confirmed", "00:40", "00:55"),
        _ptm(staff_id, 5, "Sample Student 5 (DUMMY)", t, "cancelled", "01:00", "01:20"),
        _ptm(staff_id, 6, "Sample Student 6 (DUMMY)", t, "confirmed", hm(rem_start), hm(rem_start + datetime.timedelta(minutes=20))),
    ]


def upcoming_ptms(staff_id):
    """GET /teaching/ptm/upcoming/mine?teacherId=<staffId>  (PC:23-29 -> PS:178-183; status requested|confirmed,
    scheduledDate>=now, asc; no limit). Emulates the real DROP of today's meetings: scheduledDate is stored at midnight,
    so `scheduledDate >= new Date()` (PS:181) is false for today once the day has started."""
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
    out = [m for m in _all_ptms(staff_id) if m["status"] in ("requested", "confirmed") and m["scheduledDate"] >= now]
    return sorted(out, key=lambda m: m["scheduledDate"])


def ptm_list(staff_id, status, frm, to):
    """GET /teaching/ptm?teacherId=&status=&from=&to=  (PC:18-21 -> PS:91-104, verified): filters teacherId, status,
    scheduledDate $gte from / $lte to (`new Date(x)`), sorted scheduledDate DESC, limit 200, campus-scoped (campus scope
    not emulated; whether null-campusId meetings are hidden for teachers = UNVERIFIED). Unparseable from/to is not
    validated by the real server (Invalid Date); the stub just ignores it."""
    def parse(v):
        try:
            return datetime.datetime.fromisoformat(v.replace("Z", "+00:00")).astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
        except (ValueError, AttributeError):
            return None
    f, t = parse(frm), parse(to)
    out = []
    for m in _all_ptms(staff_id):
        if status and m["status"] != status:
            continue
        if f and m["scheduledDate"] < f:
            continue
        if t and m["scheduledDate"] > t:
            continue
        out.append(m)
    out.sort(key=lambda m: m["scheduledDate"], reverse=True)
    return out[:200]


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


def threads(staff_id, status=""):
    """GET /staff-portal/threads?status=open  (SPC:49-50 -> SPS:217-223, verified). `status` is applied ONLY when it is
    exactly 'open' or 'closed' (SPS:220), otherwise all statuses are returned; sorted lastMessageAt desc, limit 100
    (SPS:221). { items, unreadCount }; unreadCount counts only the returned rows (SPS:222). NEW on feat/staff-portal, NOT
    deployed to production. Item fields NM:41-59 (verified). The CLOSED thread below has staffHasUnread=true on purpose:
    it must NOT be counted by the app (open-only decision) and only appears without ?status=open."""
    def t(n, unread, preview, st="open"):
        return {"_id": _oid(0x900 + n), "subject": "Homework query", "studentId": _oid(0x200 + n),
                "studentName": f"Sample Student {n} (DUMMY)", "guardianUserId": _oid(0x910 + n),
                "guardianName": "Sample Guardian (DUMMY)", "staffId": staff_id, "staffName": "Sample Teacher",
                "lastMessagePreview": preview, "lastMessageAt": f"{_today().isoformat()}T06:30:00.000Z",
                "guardianHasUnread": False, "staffHasUnread": unread, "status": st, "schoolSlug": "demo-school"}
    items = [t(1, True, "Thank you ma'am (DUMMY)"), t(2, True, "Could you share the worksheet? (DUMMY)"),
             t(3, False, "See you at the meeting (DUMMY)"), t(4, True, "Closed topic, ignore (DUMMY)", "closed")]
    if status in ("open", "closed"):
        items = [i for i in items if i["status"] == status]
    return {"items": items, "unreadCount": sum(1 for i in items if i["staffHasUnread"])}


def unread_count():
    """GET /staff-portal/notifications/unread-count  (SPC:33-34 -> SPS:191-195) -> { unreadCount }. NEW, not in prod."""
    return {"unreadCount": 3}


# ======================= Phase 5a: Classroom fixtures (DUMMY) =======================
# Backend citations (eldermin-backend, branch feat/staff-portal). Abbreviations:
#   STC = src/students/students.controller.ts   STS = src/students/students.service.ts
#   STD = src/students/dto/student.dto.ts       SCH = src/students/schemas/student.schema.ts
#   ATT = src/students/schemas/student-supporting.schema.ts   SCOPE = src/auth/scope.util.ts
#   CM  = src/common/utils/class-match.util.ts  FLT = src/filters/sentry.filter.ts   MAIN = src/main.ts
# "UNVERIFIED" = cannot be confirmed from code (see PHASE5A_REPORT.md register).
import calendar as _cal
import math
import time as _time

CAMPUS_ID = "64a0000000000000000000c1"
ACADEMIC_YEAR = "2026-27"  # DUMMY. Real value is per-student `currentAcademicYear` (SCH:141)

_FIRST = ["Aarav", "Zara", "Omar", "Layla", "Yusuf", "Mariam", "Hamza", "Aisha", "Bilal", "Sana", "Ibrahim", "Hira",
          "Zayd", "Noor", "Ali", "Fatima", "Usman", "Amna", "Hassan", "Iqra", "Saad", "Maryam", "Daniyal", "Eman",
          "Rayyan", "Khadija", "Talha", "Anaya", "Huzaifa", "Rida", "Idris"]
_LAST = ["Ahmed", "Siddiqui", "Malik", "Qureshi", "Sheikh", "Baig", "Raza", "Farooq"]

# (grade string as STORED on the student, section as stored, count, first student index, id base)
# Two Grade 5 A students are stored as "5"/"a" to exercise the tolerant class matching (CM:25-45); whether real
# data looks like that is UNVERIFIED (CM header comment says imports may produce such strings).
CLASSES = [
    {"grade": "Grade 5", "section": "A", "count": 31, "base": 0x200, "name0": 0},
    {"grade": "Grade 5", "section": "B", "count": 6, "base": 0x240, "name0": 8},
    {"grade": "Grade 6", "section": "B", "count": 8, "base": 0x260, "name0": 15},
]
ODD_STRINGS = {3: ("5", "a"), 17: ("5", "a")}  # index within Grade 5 A -> stored (grade, section)
TRANSFERRED_INDEX = 30  # last of Grade 5 A is status 'transferred' (31 total, 30 active == roster_diagnostic)


def _student_doc(cls, i):
    """One Student document, fields from SCH:79-241 (verified). The real GET /students and GET /students/:id/360
    return the WHOLE document (guardian phone/CNIC/income, address, medical incl. insurance, ...): this stub does
    the same ON PURPOSE so the app's whitelist models are proven to ignore them."""
    sid = cls["base"] + i
    first = _FIRST[(cls["name0"] + i) % len(_FIRST)]
    last = _LAST[(i * 3 + cls["name0"]) % len(_LAST)]
    grade, section = ODD_STRINGS.get(i, (cls["grade"], cls["section"])) if (cls["grade"], cls["section"]) == ("Grade 5", "A") else (cls["grade"], cls["section"])
    status = "transferred" if (cls["count"] == 31 and i == TRANSFERRED_INDEX) else "active"
    allergies = ["Peanuts (DUMMY)"] if i % 11 == 4 else []
    return {
        "_id": _oid(sid), "studentId": f"STU-2026-{1000 + sid % 1000}", "firstName": first,
        "lastName": f"{last} (DUMMY)", "dateOfBirth": "2015-04-12T00:00:00.000Z", "gender": "female" if i % 2 else "male",
        "nationality": "Pakistani", "photo": None, "grNo": f"GR-{2000 + sid % 1000}", "rfid": "RFID-DUMMY",
        "address": "12 Dummy Street (DUMMY ADDRESS)", "town": "Dummytown", "city": "Dummycity",
        "personalPhone": "0300-5550000", "nationalId": "00000-0000000-0", "bForm": "00000-0000000-1",
        "guardians": [
            {"name": f"Mr {last} (DUMMY)", "relation": "father", "cnic": "00000-0000000-2", "phone": "0300-5550001",
             "email": "guardian.dummy@example.test", "occupation": "Engineer", "employer": "DUMMY Corp",
             "monthlyIncome": 250000, "isPrimary": True, "isEmergencyContact": True},
            {"name": f"Mrs {last} (DUMMY)", "relation": "mother", "cnic": "00000-0000000-3", "phone": "0300-5550002",
             "email": "", "occupation": "Doctor", "employer": "DUMMY Clinic", "monthlyIncome": 180000,
             "isPrimary": False, "isEmergencyContact": True},
        ] + ([{"name": f"Mr {last} (DUMMY)", "relation": "father", "cnic": "00000-0000000-2", "phone": "0300-5550001",
               "isPrimary": True, "isEmergencyContact": True}] if i == 2 else []),  # duplicate guardian row (known data issue, see STC:196-205 comment)
        "medical": {"bloodGroup": "B+", "allergies": allergies, "medications": [], "conditions": ["Asthma (DUMMY)"] if i == 7 else [],
                    "doctorName": "Dr DUMMY", "doctorPhone": "0300-5550003", "insurancePolicyNumber": "POL-DUMMY-1"},
        "currentGrade": grade, "currentSection": section, "currentRollNumber": str(i + 1),
        "currentAcademicYear": ACADEMIC_YEAR, "classTeacher": "Clara Classteacher", "houseGroup": "Blue",
        "admissionDate": "2021-04-01T00:00:00.000Z", "admissionNumber": f"ADM-{sid}",
        "emergencyContactName": "Uncle DUMMY", "emergencyContactPhone": "0300-5550004",
        "specialNeeds": i == 7, "scholarshipHolder": i == 5, "scholarshipDetail": "50% (DUMMY)" if i == 5 else None,
        "transportRequired": True, "siblingInSchool": False, "status": status,
        "campusId": CAMPUS_ID, "schoolSlug": "demo-school", "programType": "k12",
        "createdAt": f"2026-04-{1 + i % 27:02d}T05:00:00.000Z", "updatedAt": "2026-09-01T05:00:00.000Z", "__v": 0,
    }


STUDENTS = []
for _c in CLASSES:
    for _i in range(_c["count"]):
        STUDENTS.append(_student_doc(_c, _i))
STUDENTS_BY_ID = {s["_id"]: s for s in STUDENTS}


def _norm_grade(v):
    """CM:normalizeGradeName (CM:25-29)."""
    s = re.sub(r"\s+", " ", str(v if v is not None else "").strip()).lower()
    s = re.sub(r"^(?:grade|class|standard|std|g)[\s\-_.]*(?=\d)", "", s)
    if re.fullmatch(r"\d+", s):
        s = str(int(s))
    return s


def _norm_section(v):
    """CM:normalizeSectionName (CM:31-35)."""
    s = re.sub(r"\s+", " ", str(v if v is not None else "").strip()).lower()
    return re.sub(r"^(?:section|sec)[\s\-_.:]+(?=\S)", "", s)


def grades_sections():
    """GET /students/filters/grades-sections (STC:61-66 -> STS:450-462, verified): school-wide DISTINCT RAW strings,
    sorted, falsy removed. No class/campus scoping."""
    return {"grades": sorted({s["currentGrade"] for s in STUDENTS if s["currentGrade"]}),
            "sections": sorted({s["currentSection"] for s in STUDENTS if s["currentSection"]})}


def _fee_for(s):
    """STS:547-621: the list adds `monthlyTuitionFee` (number|null) to EVERY student (verified). DUMMY amount.
    The teacher app must NOT parse or show it (hardening-backlog item 6)."""
    return 18500 if s["currentGrade"].endswith("5") or s["currentGrade"] == "5" else 21000


def students_list(q, account):
    """GET /students  (STC:54-59 -> STS:515-622, verified). Query StudentQueryDto STD:235-258 + PaginationDto STD:15-30:
    page (def 1), limit (def 20, @Min(1) @Max(1000)), search, sortBy (def createdAt), sortOrder (def desc), grade[]/section[]
    (repeated params, exact $in), status, gender, academicYear, campusId. Campus forced for non-owner roles (SCOPE:70-91): a
    teacher without a campusId gets 403 'Your account has no campus assigned...'. NOT class-scoped (hardening item 6).
    `search` (STS:538-554) = regex over firstName, lastName, studentId, grNo, admissionNumber, guardians.phone/email
    (NOT currentRollNumber). Response { data, meta:{total,page,limit,pages} } (STS:623)."""
    def arg(k, d=None):
        v = q.get(k)
        return v[0] if v else d
    try:
        page = int(arg("page", "1")); limit = int(arg("limit", "20"))
    except ValueError:
        return 400, "limit must be a number conforming to the specified constraints"
    if limit < 1:
        return 400, "limit must not be less than 1"
    if limit > 1000:
        return 400, "limit must not be greater than 1000"
    rows = [dict(s) for s in STUDENTS]
    if _modes.get("bigclass") == "on":  # Phase 6b: a 230-student Grade 5 A (two 200-row pages)
        rows += stub_6b.extra_students()
    if q.get("grade"):
        rows = [s for s in rows if s["currentGrade"] in q["grade"]]
    if q.get("section"):
        rows = [s for s in rows if s["currentSection"] in q["section"]]
    if arg("status"):
        rows = [s for s in rows if s["status"] == arg("status")]
    if arg("search"):
        rx = re.compile(re.escape(arg("search")), re.I)
        def hit(s):
            keys = [s["firstName"], s["lastName"], s["studentId"], s["grNo"], s["admissionNumber"]]
            keys += [g.get("phone", "") for g in s["guardians"]] + [g.get("email", "") for g in s["guardians"]]
            return any(rx.search(k or "") for k in keys)
        rows = [s for s in rows if hit(s)]
    rows.sort(key=lambda s: s["createdAt"], reverse=(arg("sortOrder", "desc") != "asc"))
    total = len(rows)
    page_rows = rows[(page - 1) * limit: page * limit]
    for s in page_rows:
        s["monthlyTuitionFee"] = _fee_for(s)
    return 200, {"data": page_rows, "meta": {"total": total, "page": page, "limit": limit, "pages": math.ceil(total / limit)}}


# ---- attendance store (StudentAttendance, ATT:14-49) ----
# date is stored as server-LOCAL midnight (STS:1800-1801, 1812-1813): "server local" = this process's TZ (run the stub with
# TZ=Asia/Karachi etc. to exercise U3). Unique index {studentId,date} (ATT:46-49).
ATT = {}  # (studentId, epoch_seconds) -> record
_att_last = {"academicYearHeader": None, "bulkCalls": 0, "lastBulkSize": 0}


def _js_parse_date(v):
    """JS `new Date(str)` for the strings IsDateString accepts: date-only = UTC midnight; with Z/offset = that instant; naive
    datetime = local time. Returns epoch seconds or None."""
    m = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?(Z|[+-]\d{2}:?\d{2})?)?", v or "")
    if not m:
        return None
    y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
    try:
        datetime.date(y, mo, d)
    except ValueError:
        return None
    if m.group(4) is None:
        return _cal.timegm((y, mo, d, 0, 0, 0))
    hh, mi, ss = int(m.group(4)), int(m.group(5)), int(m.group(6) or 0)
    tz = m.group(8)
    if tz is None:
        return _time.mktime((y, mo, d, hh, mi, ss, 0, 0, -1))
    epoch = _cal.timegm((y, mo, d, hh, mi, ss))
    if tz != "Z":
        sign = 1 if tz[0] == "+" else -1
        digits = tz[1:].replace(":", "")
        epoch -= sign * (int(digits[:2]) * 3600 + int(digits[2:]) * 60)
    return epoch


def _local_midnight(epoch):
    """`date.setHours(0,0,0,0)` in the server's local zone (STS:1800-1801)."""
    lt = _time.localtime(epoch)
    return _time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday, 0, 0, 0, 0, 0, -1))


def _iso_utc(epoch):
    return _time.strftime("%Y-%m-%dT%H:%M:%S.000Z", _time.gmtime(epoch))


def _att_record(student, epoch, status, grade, section, academic_year, marked_by="Clara Classteacher"):
    return {"_id": _oid(0x900000 + len(ATT) + 1), "studentId": student["_id"],
            "studentName": f'{student["firstName"]} {student["lastName"]}', "grade": grade, "section": section,
            "date": _iso_utc(epoch), "status": status, "markedBy": marked_by, "schoolSlug": "demo-school",
            "academicYear": academic_year, "createdAt": _iso_utc(epoch + 3 * 3600), "updatedAt": _iso_utc(epoch + 3 * 3600), "__v": 0}


def _roster_5a():
    rows = [s for s in STUDENTS if s["currentGrade"] in ("Grade 5", "5") and _norm_section(s["currentSection"]) == "a" and s["status"] == "active"]
    rows.sort(key=lambda s: int(s["currentRollNumber"]))
    return rows


def seed_attendance(today_count=0):
    """DUMMY history for Grade 5 A: the last 28 weekdays (not today) with a deterministic mix; plus `today_count` present
    records for today. Stored with the class strings the app sends (grade 'Grade 5' / section 'A')."""
    ATT.clear()
    roster = _roster_5a()
    today = datetime.date.today()
    day = today - datetime.timedelta(days=1)
    made = 0
    while made < 28:
        if day.weekday() < 5:
            midnight = _local_midnight(_cal.timegm((day.year, day.month, day.day, 12, 0, 0)))
            for idx, s in enumerate(roster):
                k = (idx * 7 + made * 3) % 29
                status = "absent" if k == 0 else "late" if k in (1, 2) else "excused" if k == 3 else "half_day" if k == 4 and made % 5 == 0 else "present"
                ATT[(s["_id"], midnight)] = _att_record(s, midnight, status, "Grade 5", "A", ACADEMIC_YEAR)
            made += 1
        day -= datetime.timedelta(days=1)
    set_today_attendance(today_count)


def set_today_attendance(n):
    today = datetime.date.today()
    midnight = _local_midnight(_cal.timegm((today.year, today.month, today.day, 12, 0, 0)))
    for key in [k for k in ATT if k[1] == midnight]:
        del ATT[key]
    for s in _roster_5a()[:max(0, n)]:
        ATT[(s["_id"], midnight)] = _att_record(s, midnight, "present", "Grade 5", "A", ACADEMIC_YEAR)


def _resolve_class_scope(account, grade, section):
    """SCOPE:163-180 resolveClassSectionScope (verified): no class-teacher claim -> pass through unrestricted; else 403 when the
    requested grade/section differs (normalised, CM) and the RESULT is the claim's own strings (exact match downstream).
    Section is checked only when both sides have one (SCOPE:175). Returns (grade, section) or an error string."""
    if not account or not account["classTeacher"]:
        return grade, section
    if grade and _norm_grade(grade) != _norm_grade("Grade 5"):
        return "Access denied. You are the class teacher of your own assigned class only."
    if section and _norm_section(section) != _norm_section("A"):
        return "Access denied. You are the class teacher of your own assigned class only."
    return "Grade 5", "A"


def attendance_list_real(account, q):
    """GET /students/attendance/list  (STC:451-457 -> STS:1825-1852, verified). AttendanceQueryDto STD:284-292 = PaginationDto +
    studentId?(MongoId) grade? section? from?(ISO) to?(ISO) status? month?('YYYY-MM'); there is NO `date` param (stripped by
    the whitelist, MAIN:70-74). Filter: schoolSlug, grade/section EXACT (STS:1831-1832; hazard U4), status, month ($gte/$lt
    local-month bounds) else from ($gte new Date(from)) / to ($lte new Date(to)); sorted date desc; skip/limit.
    Response { data, meta:{total,page,limit,pages} } (STS:1851)."""
    def arg(k, d=None):
        v = q.get(k)
        return v[0] if v else d
    try:
        page = int(arg("page", "1")); limit = int(arg("limit", "20"))
    except ValueError:
        return 400, "limit must be a number conforming to the specified constraints"
    if limit < 1 or limit > 1000:
        return 400, "limit must not be greater than 1000" if limit > 1000 else "limit must not be less than 1"
    for k in ("from", "to"):
        if arg(k) and _js_parse_date(arg(k)) is None:
            return 400, f"{k} must be a valid ISO 8601 date string"
    if arg("studentId") and not re.fullmatch(r"[0-9a-f]{24}", arg("studentId")):
        return 400, "studentId must be a mongodb id"
    scoped = _resolve_class_scope(account, arg("grade"), arg("section"))
    if isinstance(scoped, str):
        return 403, scoped
    grade, section = scoped
    rows = list(ATT.values())
    if arg("studentId"):
        rows = [r for r in rows if r["studentId"] == arg("studentId")]
    if grade:
        rows = [r for r in rows if r["grade"] == grade]
    if section:
        rows = [r for r in rows if r["section"] == section]
    if arg("status"):
        rows = [r for r in rows if r["status"] == arg("status")]
    def ep(r):
        return _js_parse_date(r["date"])
    if arg("month"):
        y, mo = [int(x) for x in arg("month").split("-")]
        lo = _time.mktime((y, mo, 1, 0, 0, 0, 0, 0, -1))
        hi = _time.mktime((y + (mo == 12), 1 if mo == 12 else mo + 1, 1, 0, 0, 0, 0, 0, -1))
        rows = [r for r in rows if lo <= ep(r) < hi]
    else:
        if arg("from"):
            rows = [r for r in rows if ep(r) >= _js_parse_date(arg("from"))]
        if arg("to"):
            rows = [r for r in rows if ep(r) <= _js_parse_date(arg("to"))]
    rows.sort(key=lambda r: (ep(r), r["studentName"]), reverse=True)
    total = len(rows)
    return 200, {"data": rows[(page - 1) * limit: page * limit],
                 "meta": {"total": total, "page": page, "limit": limit, "pages": math.ceil(total / limit)}}


ATT_STATUSES = ("present", "absent", "late", "excused", "half_day")  # STD:268, ATT:26


def attendance_bulk(account, body, academic_year_header):
    """POST /students/attendance/bulk (STC:481-493 -> STS:1810-1823, verified). Guard: @RolesOrModuleManage('students',
    STAFF_WRITE_ROLES, allowModuleWide) - teacher passes. Body BulkAttendanceDto STD:277-282: records[] each MarkAttendanceDto
    STD:261-275: studentId(MongoId) studentName(string) grade(string) section?(string) date(ISO) status(enum) checkInTime? checkOutTime?
    remarks?; schoolSlug/academicYear/markedBy in the body are NOT validated properties and are stripped (whitelist, MAIN:70-74).
    academicYear = JWT claim (absent) || header x-academic-year || '2025-26' (STC:30-31, ctx). Every record is class-checked
    (STC:487-489) with SCOPE:163-180. Upsert key {studentId, date(local midnight), schoolSlug} (STS:1815-1819); `markedBy` is NOT
    written by bulk (STS:1820 spreads r only). Returns the Mongo BulkWriteResult (HTTP 201) - its JSON shape is UNVERIFIED (U5)
    and the app does not read it. Validation errors: 400 with the FIRST message only (FLT:43-48)."""
    recs = body.get("records") if isinstance(body, dict) else None
    if not isinstance(recs, list):
        return 400, "records must be an array"
    for n, r in enumerate(recs):
        if not isinstance(r, dict) or not re.fullmatch(r"[0-9a-f]{24}", str(r.get("studentId", ""))):
            return 400, f"records.{n}.studentId must be a mongodb id"
        if not isinstance(r.get("studentName"), str):
            return 400, f"records.{n}.studentName must be a string"
        if not isinstance(r.get("grade"), str):
            return 400, f"records.{n}.grade must be a string"
        if r.get("section") is not None and not isinstance(r.get("section"), str):
            return 400, f"records.{n}.section must be a string"
        if _js_parse_date(str(r.get("date", ""))) is None:
            return 400, f"records.{n}.date must be a valid ISO 8601 date string"
        if r.get("status") not in ATT_STATUSES:
            return 400, f"records.{n}.status must be one of the following values: {', '.join(ATT_STATUSES)}"
    for r in recs:
        scoped = _resolve_class_scope(account, r["grade"], r.get("section"))
        if isinstance(scoped, str):
            return 403, scoped
    year = academic_year_header or "2025-26"
    upserted = matched = 0
    for r in recs:
        epoch = _local_midnight(_js_parse_date(r["date"]))
        key = (r["studentId"], epoch)
        student = STUDENTS_BY_ID.get(r["studentId"]) or {"_id": r["studentId"], "firstName": r["studentName"], "lastName": ""}
        rec = _att_record(student, epoch, r["status"], r["grade"], r.get("section"), year, marked_by="")
        rec["studentName"] = r["studentName"]
        rec.pop("markedBy", None)
        if key in ATT:
            matched += 1
            rec["_id"] = ATT[key]["_id"]
        else:
            upserted += 1
        ATT[key] = rec
    _att_last.update({"academicYearHeader": academic_year_header, "bulkCalls": _att_last["bulkCalls"] + 1,
                      "lastBulkSize": len(recs)})
    # UNVERIFIED (U5): shape of mongoose bulkWrite()'s result serialised by Nest. Typical driver BulkWriteResult JSON:
    return 201, {"ok": 1, "writeErrors": [], "writeConcernErrors": [], "insertedIds": [], "nInserted": 0,
                 "nUpserted": upserted, "nMatched": matched, "nModified": matched, "nRemoved": 0, "upserted": []}


def attendance_summary(student_id, month):
    """GET /students/:id/attendance/summary?month=YYYY-MM (STC:459-468 -> STS:1854-1864, verified): a BARE ARRAY of
    { _id: status, count } from $group (no month => ALL years). month bounds are server-local (STS:1857-1858)."""
    rows = [r for (sid, _), r in ATT.items() if sid == student_id]
    if month:
        y, mo = [int(x) for x in month.split("-")]
        lo = _time.mktime((y, mo, 1, 0, 0, 0, 0, 0, -1))
        hi = _time.mktime((y + (mo == 12), 1 if mo == 12 else mo + 1, 1, 0, 0, 0, 0, 0, -1))
        rows = [r for r in rows if lo <= _js_parse_date(r["date"]) < hi]
    counts = {}
    for r in rows:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    return [{"_id": k, "count": v} for k, v in counts.items()]


def student_360(student_id):
    """GET /students/:id/360 (STC:154-159 -> STS:1483-1575, verified). { student (WHOLE doc incl. guardians' phone/CNIC/income,
    medical...), attendance:{summary{status:count}, totalDays, presentDays, percentage(1 dp, (present+late)/total), recent[<=30
    StudentAttendance, date desc]}, fees:{summary, recent[<=6]}, behaviour:{summary{type:{count,points}}, totalPoints, recent[<=10]},
    assessments:{recent[<=5]} }. No campus/class check (hardening item 6): 404 'Student not found' only if absent. `fees` is FINANCE
    DATA the teacher app must ignore. attendance summary is for the student's currentAcademicYear (STS:1496-1500)."""
    s = STUDENTS_BY_ID.get(student_id)
    if not s:
        return 404, "Student not found"
    mine = sorted([r for (sid, _), r in ATT.items() if sid == student_id], key=lambda r: r["date"], reverse=True)
    summary = {}
    for r in mine:
        summary[r["status"]] = summary.get(r["status"], 0) + 1
    total = sum(summary.values())
    present = summary.get("present", 0) + summary.get("late", 0)
    pct = round((present / total) * 100, 1) if total else 0
    idx = int(s["currentRollNumber"])
    beh = [
        {"_id": _oid(0xb00 + idx * 5 + n), "studentId": student_id, "studentName": s["firstName"], "grade": s["currentGrade"],
         "section": s["currentSection"], "date": f"2026-09-{10 + n * 4:02d}T00:00:00.000Z", "type": t, "category": c,
         "description": d, "severity": sev, "actionTaken": "Talked to student (DUMMY)", "parentNotified": False,
         "resolved": res, "reportedBy": "Sample Teacher", "points": pts, "schoolSlug": "demo-school", "academicYear": ACADEMIC_YEAR}
        for n, (t, c, d, sev, res, pts) in enumerate([
            ("positive", "helping", "Helped a classmate with fractions (DUMMY)", "low", True, 5),
            ("negative", "late_coming", "Arrived 15 minutes late twice this week (DUMMY)", "medium", False, 2),
            ("neutral", "parent_meeting", "Brief catch-up with guardian (DUMMY)", "low", True, 0),
        ])
    ]
    results = [
        {"_id": _oid(0xc00 + idx * 3 + n), "studentId": student_id, "studentName": s["firstName"], "grade": s["currentGrade"],
         "assessmentTitle": title, "assessmentType": typ, "date": f"2026-09-{5 + n * 7:02d}T00:00:00.000Z",
         "subjectResults": [{"subject": "Mathematics", "maxMarks": 50, "obtainedMarks": 40 - n * 3, "grade": "B"}],
         "totalMaxMarks": 50, "totalObtainedMarks": 40 - n * 3, "percentage": float(80 - n * 6), "overallGrade": "A" if n == 0 else "B",
         "schoolSlug": "demo-school", "academicYear": ACADEMIC_YEAR}
        for n, (title, typ) in enumerate([("Unit 1 test (DUMMY)", "test"), ("Quiz 2 (DUMMY)", "quiz")])
    ]
    return 200, {
        "student": s,
        "attendance": {"summary": summary, "totalDays": total, "presentDays": present, "percentage": pct, "recent": mine[:30]},
        "fees": {"summary": {"pending": {"count": 1, "total": 18500}}, "recent": [
            {"_id": _oid(0xd00 + idx), "studentId": student_id, "month": "2026-10", "feeType": "tuition",
             "amount": 18500, "netAmount": 18500, "status": "pending"}]},
        "behaviour": {"summary": {"positive": {"count": 1, "points": 5}, "negative": {"count": 1, "points": 2}},
                      "totalPoints": 3, "recent": beh},
        "assessments": {"recent": results},
    }


seed_attendance(0)

import sys as _sys
import stub_5b  # Phase 5b logic (homework, upload, behaviour, tarbiyah)
stub_5b.bind(_sys.modules[__name__])
import stub_6a  # Phase 6a logic (lesson plans, syllabus tracking)
stub_6a.bind(_sys.modules[__name__])
import stub_6b  # Phase 6b logic (assessments, marks entry, report remarks, quiz grading, curriculum, library)
stub_6b.bind(_sys.modules[__name__])


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
            mode = _modes.get(feature, _modes.get("new", "ok") if feature in NEW_FEATURES else "ok")
        if mode == "slow":
            time.sleep(6)
            return None
        if mode == "drop":  # connection closed without a response -> the app's offline/connection-error path
            self.close_connection = True
            try:
                self.connection.shutdown(2)
            except OSError:
                pass
            return True
        if mode in ("400", "403", "404", "409", "413", "422", "500", "503"):
            msgs = {"400": "title must be a string (stub mode 400: a class-validator style message)",
                    "403": "Forbidden resource", "404": f"Cannot GET (feature {feature} not available)",
                    "409": "Attendance for this date is locked (UNVERIFIED: backend code never returns 409 here)",
                    "413": "File too large",
                    "422": "Unprocessable entity (stub mode 422: the real backend answers validation errors with 400)",
                    "500": "Internal server error",
                    # upload=503: the backend's answer when storage is not configured (eldermin-backend feat/staff-portal commit 9890ad1, upload.service.ts;
                    # exact text copied from that commit); other features get a plain 503
                    "503": ("File uploads are not available on this server (storage is not configured)." if feature == "upload" else "Service Unavailable")}
            self._err(int(mode), msgs[mode])
            return True
        return mode if mode == "empty" else None

    def _home_get(self, path, q):
        a = None
        def arg(k, d=""):
            return (q.get(k) or [d])[0]
        routes = {
            "/api/v1/students/class-roster-diagnostic": "roster",
            "/api/v1/teaching/assignments": "homework",
            "/api/v1/teaching/lesson-plans": "lessonplans",
            "/api/v1/teaching/ptm/upcoming/mine": "ptm",
            "/api/v1/teaching/ptm": "ptmlist",
            "/api/v1/staff-portal/homework/pending-grading": "pendinggrading",
            "/api/v1/staff-portal/timetable": "mytimetable",
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
        if feature == "homework" and m_sub:
            status, body = stub_5b.get_submissions(a, m_sub.group(1))
            return (self._err(status, body) if status != 200 else self._send(200, body)) or True
        if feature == "homework":
            if empty:
                return self._send(200, []) or True
            status, body = stub_5b.list_assignments(a, q)
            return (self._err(status, body) if status != 200 else self._send(200, body)) or True
        if feature == "lessonplans":
            return self._send(200, [] if empty else lesson_plans(arg("teacherId"), arg("status"))) or True
        if feature == "pendinggrading":
            body = {"total": 0, "items": [], "generatedAt": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")} \
                if empty else stub_5b.pending_grading(a["staffId"], arg("limit", ""))
            return self._send(200, body) or True
        if feature == "mytimetable":
            rng = parse_timetable_query(q)
            if isinstance(rng, str):
                return self._err(400, rng) or True
            return self._send(200, my_timetable(a["staffId"], a["name"], rng[0], rng[1]) if not empty
                              else {"from": rng[0].isoformat(), "to": rng[1].isoformat(), "days": [
                                  {"date": (rng[0] + datetime.timedelta(days=i)).isoformat(),
                                   "dayOfWeek": ((rng[0] + datetime.timedelta(days=i)).weekday() + 1) % 7,
                                   "weekCycle": None, "slots": []} for i in range((rng[1] - rng[0]).days + 1)]}) or True
        if feature == "ptmlist":
            return self._send(200, [] if empty else ptm_list(arg("teacherId"), arg("status"), arg("from"), arg("to"))) or True
        if feature == "ptm":
            return self._send(200, [] if empty else upcoming_ptms(arg("teacherId"))) or True
        if feature == "fixtures":
            return self._send(200, [] if empty else fixtures(arg("teacherId"), arg("from"), arg("to"))) or True
        if feature == "threads":
            body = threads(a["staffId"], arg("status"))
            if empty:
                body = {"items": [], "unreadCount": 0}
            return self._send(200, body) or True
        if feature == "unread":
            return self._send(200, {"unreadCount": 0} if empty else unread_count()) or True
        return False

    def _classroom_get(self, path, q):
        """Phase 5a routes. Returns True when handled."""
        m360 = re.fullmatch(r"/api/v1/students/([0-9a-f]{24})/360", path)
        msum = re.fullmatch(r"/api/v1/students/([0-9a-f]{24})/attendance/summary", path)
        table = {"/api/v1/students": "students", "/api/v1/students/filters/grades-sections": "studentsgrades",
                 "/api/v1/students/attendance/list": "attendance"}
        feature = "student360" if m360 else "attsummary" if msum else table.get(path)
        if not feature:
            return False
        a = self._authed()
        if not a:
            return True
        gate = self._feature_gate(feature)
        if gate is True:
            return True
        empty = gate == "empty"
        if feature == "studentsgrades":
            return self._send(200, {"grades": [], "sections": []} if empty else grades_sections()) or True
        if feature == "students":
            if empty:
                return self._send(200, {"data": [], "meta": {"total": 0, "page": 1, "limit": 20, "pages": 0}}) or True
            status, body = students_list(q, a)
            return (self._err(status, body) if status != 200 else self._send(200, body)) or True
        if feature == "attendance":
            if empty:
                return self._send(200, {"data": [], "meta": {"total": 0, "page": 1, "limit": 20, "pages": 0}}) or True
            status, body = attendance_list_real(a, q)
            return (self._err(status, body) if status != 200 else self._send(200, body)) or True
        if feature == "attsummary":
            month = (q.get("month") or [""])[0]
            if month and not re.fullmatch(r"\d{4}-\d{2}", month):
                return self._err(500, "Internal server error") or True  # STS:1857 NaN dates -> Mongo cast error (500) - UNVERIFIED
            return self._send(200, [] if empty else attendance_summary(m360 and m360.group(1) or msum.group(1), month)) or True
        if feature == "student360":
            status, body = student_360(m360.group(1))
            return (self._err(status, body) if status != 200 else self._send(200, body)) or True
        return False


    # -- Phase 5b routes (homework writes, grading, upload, behaviour, tarbiyah). True when handled.
    def _raw(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def _reply(self, status, body, ok=200):
        if status >= 400:
            return self._err(status, body)
        if body is None:  # Nest sends an empty body for a null return (resolve of an unknown id)
            self.send_response(status)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return None
        return self._send(status, body)

    # -- Phase 6a routes (lesson plans, syllabus). True when handled.
    def _p6a(self, method, path, q):
        m_lp = re.fullmatch(r"/api/v1/teaching/lesson-plans/([0-9a-zA-Z]+)", path)
        m_mark = re.fullmatch(r"/api/v1/syllabus/([0-9a-zA-Z]+)/(mark-topic|mark-sub-topic)", path)
        m_syl = re.fullmatch(r"/api/v1/syllabus/([0-9a-zA-Z\-]+)", path)
        feature = None
        if method == "GET" and path == "/api/v1/teaching/lesson-plans":
            feature = "lessonplans"
        elif method == "POST" and path == "/api/v1/teaching/lesson-plans":
            feature = "lpcreate"
        elif method == "POST" and path == "/api/v1/teaching/lesson-plans/parse-upload":
            feature = "lpparse"
        elif method == "PATCH" and m_lp and m_lp.group(1) not in ("parse-upload",):
            feature = "lpupdate"
        elif method == "GET" and path == "/api/v1/syllabus":
            feature = "syllabus"
        elif method == "GET" and path == "/api/v1/syllabus/weekly-planner":
            feature = "planner"
        elif method == "PATCH" and m_mark:
            feature = "sylmark"
        elif method == "GET" and m_syl and m_syl.group(1) not in ("weekly-planner", "dashboard"):
            feature = "sylone"
        if not feature:
            return False
        a = self._authed()
        if not a:
            return True
        raw = self._raw() if method in ("POST", "PATCH") else b""
        gate = self._feature_gate(feature)
        if gate is True:
            return True
        if a["role"] != "teacher":
            return self._err(403, "Forbidden resource") or True
        with _lock:
            special = _modes.get(feature, "ok")
        empty = gate == "empty"
        ctype = self.headers.get("Content-Type") or ""

        def jbody():
            try:
                return json.loads(raw or b"{}")
            except Exception:
                return {}
        with _lock:
            if feature == "lessonplans":
                r = (200, []) if empty else stub_6a.list_plans(a, q)
            elif feature == "lpcreate":
                r = stub_6a.create_plan(a, jbody())
            elif feature == "lpupdate":
                r = stub_6a.update_plan(a, m_lp.group(1), jbody(), mode=special)
            elif feature == "lpparse":
                r = stub_6a.parse_upload(a, ctype, raw, mode=special)
            elif feature == "syllabus":
                r = (200, []) if empty else stub_6a.list_syllabi(a, q)
            elif feature == "sylone":
                r = stub_6a.get_syllabus(a, m_syl.group(1))
            elif feature == "sylmark":
                fn = stub_6a.mark_topic if m_mark.group(2) == "mark-topic" else stub_6a.mark_sub_topic
                r = fn(a, m_mark.group(1), jbody(), mode=special)
            else:
                r = (200, []) if empty else stub_6a.weekly_planner(a, q)
        status, body = r
        if status >= 400:
            self._err(status, body)
        elif body is None:  # Nest sends an empty body for a null return
            self.send_response(status)
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            self._send(status, body)
        return True

    # -- Phase 6b routes (assessments, marks, report remarks, quiz grading, curriculum, library). True when handled.
    def _p6b(self, method, path, q):
        static = ("dashboard", "questions", "marks", "report-cards", "analytics", "timetable", "quiz-attempts", "papers", "omr")
        m_asm = re.fullmatch(r"/api/v1/assessments/([0-9a-zA-Z\-]+)", path)
        m_att = re.fullmatch(r"/api/v1/assessments/quiz-attempts/([0-9a-zA-Z]+)", path)
        m_grade = re.fullmatch(r"/api/v1/assessments/quiz-attempts/([0-9a-zA-Z]+)/grade", path)
        m_rem = re.fullmatch(r"/api/v1/assessments/report-cards/([0-9a-zA-Z]+)/remarks", path)
        m_cur = re.fullmatch(r"/api/v1/academics/curriculum/([0-9a-zA-Z]+)", path)
        feature = None
        if method == "GET":
            if path == "/api/v1/assessments":
                feature = "assessments"
            elif path == "/api/v1/assessments/marks/list":
                feature = "marks"
            elif path == "/api/v1/assessments/report-cards":
                feature = "reportcards"
            elif path == "/api/v1/assessments/quiz-attempts":
                feature = "quizlist"
            elif m_att:
                feature = "quizone"
            elif m_asm and m_asm.group(1) not in static:
                feature = "assessone"
            elif path == "/api/v1/academics/curriculum":
                feature = "curriculum"
            elif m_cur:
                feature = "curone"
            elif path == "/api/v1/academics/library/books":
                feature = "library"
        elif method == "POST":
            if path == "/api/v1/assessments/marks/bulk":
                feature = "marksbulk"
            elif m_grade:
                feature = "quizgrade"
        elif method == "PATCH" and m_rem:
            feature = "remarks"
        if not feature:
            return False
        a = self._authed()
        if not a:
            return True
        raw = self._raw() if method in ("POST", "PATCH") else b""
        gate = self._feature_gate(feature)
        if gate is True:
            return True
        if a["role"] != "teacher":
            return self._err(403, "Forbidden resource") or True
        with _lock:
            special = _modes.get(feature, "ok")
        empty = gate == "empty"
        no_page = {"data": [], "meta": {"total": 0, "page": 1, "limit": 20, "pages": 0}}

        def jbody():
            try:
                return json.loads(raw or b"{}")
            except Exception:
                return {}
        with _lock:
            if feature == "assessments":
                r = (200, no_page) if empty else stub_6b.list_assessments(a, q)
            elif feature == "assessone":
                r = stub_6b.get_assessment(a, m_asm.group(1))
            elif feature == "marks":
                r = (200, no_page) if empty else stub_6b.list_marks(a, q, mode=special)
            elif feature == "marksbulk":
                r = stub_6b.bulk_marks(a, jbody(), mode=special, academic_year_header=self.headers.get("x-academic-year"))
            elif feature == "reportcards":
                r = (200, no_page) if empty else stub_6b.list_report_cards(a, q)
            elif feature == "remarks":
                r = stub_6b.update_remarks(a, m_rem.group(1), jbody(), mode=special)
            elif feature == "quizlist":
                r = (200, []) if empty else stub_6b.list_attempts(a, q)
            elif feature == "quizone":
                r = stub_6b.get_attempt(a, m_att.group(1), mode=special)
            elif feature == "quizgrade":
                r = stub_6b.grade_attempt(a, m_grade.group(1), jbody(), mode=special)
            elif feature == "curriculum":
                r = (200, []) if empty else stub_6b.list_curricula(a, q)
            elif feature == "curone":
                r = stub_6b.get_curriculum(a, m_cur.group(1))
            else:
                r = (200, no_page) if empty else stub_6b.list_books(a, q)
        status, body = r
        if status >= 400:
            self._err(status, body)
        elif body is None:  # Nest sends an empty body for a null return
            self.send_response(status)
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            self._send(status, body)
        return True

    def _p5b(self, method, path, q):
        m_asg = re.fullmatch(r"/api/v1/teaching/assignments/([0-9a-f]{24})", path)
        m_grade = re.fullmatch(r"/api/v1/teaching/assignments/([0-9a-f]{24})/submissions/([0-9a-f]{24})", path)
        m_up = re.fullmatch(r"/api/v1/upload/single/([A-Za-z0-9_\-]+)", path)
        m_res = re.fullmatch(r"/api/v1/behaviour/records/([0-9a-f]{24})/resolve", path)
        m_file = path.startswith("/__stub/files/")
        feature = None
        if method == "POST" and path == "/api/v1/teaching/assignments":
            feature = "hwwrite"
        elif method in ("PATCH", "DELETE") and m_asg:
            feature = "hwwrite"
        elif method == "PATCH" and m_grade:
            feature = "hwgrade"
        elif method == "POST" and m_up:
            feature = "upload"
        elif method == "GET" and path == "/api/v1/upload/signed-url":
            feature = "signedurl"
        elif method == "GET" and path == "/api/v1/behaviour/records":
            feature = "behaviour"
        elif method == "POST" and path == "/api/v1/behaviour/records":
            feature = "behaviourcreate"
        elif method == "PATCH" and m_res:
            feature = "behaviourresolve"
        elif method == "GET" and path == "/api/v1/behaviour/tarbiyah":
            feature = "tarbiyah"
        elif method == "GET" and m_file:
            self.send_response(200)
            body = b"DUMMY FILE CONTENT (stub)"
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return True
        if not feature:
            return False
        a = self._authed()
        if not a:
            return True
        raw = self._raw() if method in ("POST", "PATCH", "DELETE") else b""
        gate = self._feature_gate(feature)
        if gate is True:
            return True
        if a["role"] != "teacher":
            return self._err(403, "Forbidden resource") or True
        empty = gate == "empty"
        ctype = self.headers.get("Content-Type") or ""
        def jbody():
            try:
                return json.loads(raw or b"{}")
            except Exception:
                return {}
        with _lock:
            if feature == "hwwrite" and method == "POST":
                r = stub_5b.create_assignment(a, jbody())
            elif feature == "hwwrite" and method == "PATCH":
                r = stub_5b.update_assignment(a, m_asg.group(1), jbody())
            elif feature == "hwwrite":
                r = stub_5b.delete_assignment(a, m_asg.group(1))
            elif feature == "hwgrade":
                r = stub_5b.grade_submission(a, m_grade.group(1), m_grade.group(2), jbody())
            elif feature == "upload":
                r = stub_5b.upload_single(a, m_up.group(1), ctype, raw)
            elif feature == "signedurl":
                host = self.headers.get("Host") or "127.0.0.1"
                r = stub_5b.signed_url((q.get("key") or [""])[0], f"http://{host}")
            elif feature == "behaviour":
                r = (200, {"data": [], "meta": {"total": 0, "page": 1, "limit": 20, "pages": 0}}) if empty else stub_5b.list_records(a, q)
            elif feature == "behaviourcreate":
                r = stub_5b.create_record(a, jbody())
            elif feature == "behaviourresolve":
                r = stub_5b.resolve_record(a, m_res.group(1), jbody())
            else:
                r = (200, {"data": [], "meta": {"total": 0, "page": 1, "limit": 20, "pages": 0}}) if empty else stub_5b.list_tarbiyah(a, q)
        self._reply(*r)
        return True

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
        elif path.startswith("/api/v1/") and (self._p6b("GET", path, parse_qs(urlparse(self.path).query)) or self._p6a("GET", path, parse_qs(urlparse(self.path).query))):
            return
        elif (path.startswith("/api/v1/") or path.startswith("/__stub/files/")) and self._p5b("GET", path, parse_qs(urlparse(self.path).query)):
            return
        elif path.startswith("/api/v1/") and self._classroom_get(path, parse_qs(urlparse(self.path).query)):
            return
        elif path.startswith("/api/v1/") and self._home_get(path, parse_qs(urlparse(self.path).query)):
            return
        elif path == "/__stub/state":
            with _lock:
                self._send(200, {"classTeacher": {k: v["classTeacher"] for k, v in ACCOUNTS.items()}, **_state,
                                 "attendance": {"records": len(ATT), **_att_last}, "phase5b": stub_5b.state_summary(), "phase6a": stub_6a.state_summary(), "phase6b": stub_6b.state_summary()})
        else:
            self._err(404, f"Cannot GET {path}")

    def do_PATCH(self):
        path = urlparse(self.path).path
        if not (self._p6b("PATCH", path, parse_qs(urlparse(self.path).query)) or self._p6a("PATCH", path, parse_qs(urlparse(self.path).query)) or self._p5b("PATCH", path, parse_qs(urlparse(self.path).query))):
            self._err(404, f"Cannot PATCH {path}")

    def do_DELETE(self):
        path = urlparse(self.path).path
        if not self._p5b("DELETE", path, parse_qs(urlparse(self.path).query)):
            self._err(404, f"Cannot DELETE {path}")

    def do_POST(self):
        u = urlparse(self.path)
        path = u.path
        if self._p6b("POST", path, parse_qs(u.query)) or self._p6a("POST", path, parse_qs(u.query)) or self._p5b("POST", path, parse_qs(u.query)):
            return
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
        if path == "/api/v1/students/attendance/bulk":
            a = self._authed()
            if not a:
                return
            body = self._json()
            gate = self._feature_gate("attbulk")
            if gate is True:
                return
            if a["role"] not in ("teacher", "principal"):
                return self._err(403, "Forbidden resource")
            with _lock:
                status, resp = attendance_bulk(a, body, self.headers.get("x-academic-year"))
            return self._err(status, resp) if status != 201 else self._send(201, resp)
        if path == "/__stub/mode":
            q = parse_qs(u.query)
            with _lock:
                _modes[(q.get("feature") or [""])[0]] = (q.get("value") or ["ok"])[0]
            return self._send(200, {"modes": _modes})
        if path == "/__stub/attendance":
            q = parse_qs(u.query)
            with _lock:
                _attendance["count"] = int((q.get("count") or ["0"])[0])
                set_today_attendance(_attendance["count"])
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
                seed_attendance(0)
                _att_last.update({"academicYearHeader": None, "bulkCalls": 0, "lastBulkSize": 0})
                stub_5b.reset()
                stub_6a.reset()
                stub_6b.reset()
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
