"""Phase 6a stub logic: lesson plans (list / create / patch / parse-upload) and syllabus tracking (list / one / mark topic /
mark sub-topic / weekly planner).

!! DUMMY DATA ONLY. Lives under tool/dev/, never shipped. Imported by stub_server.py (HTTP routing, auth and the dev mode
!! switches live there). Every function returns (status, body) so tests can call it directly.

Citation legend (paths relative to eldermin-backend/src/, branch feat/staff-portal, HEAD 62db9f8 "derive teacher identity
server-side for teacher writes"). "UNVERIFIED" = cannot be confirmed from code; all of them are in PHASE6A_REPORT.md.
  TC  = modules/teaching/teaching.controller.ts    TS  = modules/teaching/teaching.service.ts
  LP  = modules/teaching/schemas/lesson-plan.schema.ts
  TID = staff-portal/teacher-identity.util.ts
  SC  = syllabus/syllabus.controller.ts            SS  = syllabus/syllabus.service.ts
  SY  = syllabus/schemas/syllabus.schema.ts        SD  = syllabus/dto/syllabus.dto.ts
  SCOPE = auth/scope.util.ts   FLT = filters/sentry.filter.ts   MAIN = main.ts (global ValidationPipe whitelist:true)

Extra /__stub/mode features (value: ok|empty|400|403|404|413|422|500|drop|slow, plus the special values below):
  lessonplans  GET /teaching/lesson-plans            lpcreate  POST /teaching/lesson-plans      lpupdate  PATCH /teaching/lesson-plans/:id
  lpparse      POST /teaching/lesson-plans/parse-upload   special values: aioff (500 'AI assistance is not configured on this server.'),
               badjson (502 'Could not understand this document's structure...'), googledenied (400 Google Doc not shared)
  syllabus     GET /syllabus      sylone  GET /syllabus/:id      sylmark  PATCH /syllabus/:id/mark-topic + mark-sub-topic
  planner      GET /syllabus/weekly-planner
  Special value on sylmark / lpupdate: notfound (the real not-found behaviour, see the functions below).
"""
import datetime
import json
import re
import uuid

S = None  # the stub_server module, injected by bind()


def bind(mod):
    global S
    S = mod


TERM_STATUSES = ["draft", "submitted", "approved", "rejected", "overdue"]  # LP:38
METHODOLOGIES = ["lecture", "discussion", "activity", "demo", "project", "flipped"]  # TS:222 (parse) / web LessonPlansTab.tsx:13-20
KNOWN_RESOURCES = ["Textbook", "Whiteboard", "Projector", "Lab Equipment", "Handouts", "Video"]  # TS:223
MAX_UPLOAD = 10 * 1024 * 1024  # TC:74 FileInterceptor limits.fileSize -> multer 413 'File too large'
LP_FIELDS = {  # mongoose strict mode: only schema paths survive create()/findOneAndUpdate() (LP:7-42)
    "teacherId", "teacherName", "campusId", "academicYearId", "subject", "gradeLevel", "sectionName", "topic", "description",
    "planDate", "weekNumber", "durationMins", "learningObjectives", "resources", "teachingMethodology", "priorKnowledge",
    "activities", "assessment", "homework", "reflection", "sloTags", "syllabusPageFrom", "syllabusPageTo", "status",
    "approvedBy", "approvedAt", "rejectionReason", "approverNotes", "tenantId", "institutionId",
}

_state = {"plans": {}, "lp_counter": 0x900, "seeded": False, "syllabi": {}, "last_parse": None, "last_patch": None,
          "last_create": None, "mark_calls": 0}


def reset():
    _state.update({"plans": {}, "lp_counter": 0x900, "seeded": False, "syllabi": {}, "last_parse": None, "last_patch": None,
                   "last_create": None, "mark_calls": 0})


def state_summary():
    return {"lessonPlans": len(_state["plans"]), "syllabi": len(_state["syllabi"]), "markCalls": _state["mark_calls"],
            "lastParse": _state["last_parse"], "lastLessonPlanPatch": _state["last_patch"],
            "lastLessonPlanCreate": _state["last_create"]}


def _now():
    return datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")


def _midnight(d):
    return f"{d.isoformat()}T00:00:00.000Z"


def _is_oid(v):
    return isinstance(v, str) and re.fullmatch(r"[0-9a-fA-F]{24}", v) is not None


def _me_ids(account):
    return {account["staffId"], account.get("teacherProfileId")} - {None}


# ============================== LESSON PLANS ==============================

def _plan(n, teacher_id, topic, status, *, days, subject="Mathematics", grade="Grade 5", section="A", teacher_name="Tess Teacher",
          reason=None, notes=None, objectives=None, resources=None, method=None, **more):
    """LessonPlan document, fields LP:7-42 (verified). `teacherId` refs Staff (LP:9); the schema has NO `title`, the name is
    `topic` (LP:19)."""
    d = S._today() + datetime.timedelta(days=days)
    p = {"_id": S._oid(0x900 + n), "tenantId": S._oid(0xa1), "institutionId": S._oid(0xa2), "teacherId": teacher_id,
         "teacherName": teacher_name, "campusId": S.CAMPUS_ID, "subject": subject, "gradeLevel": grade, "sectionName": section,
         "topic": topic, "description": "", "planDate": _midnight(d), "durationMins": 40, "learningObjectives": list(objectives or []),
         "resources": list(resources or []), "sloTags": [], "syllabusPageFrom": 0, "syllabusPageTo": 0, "status": status,
         "createdAt": "2026-10-01T05:00:00.000Z", "updatedAt": "2026-10-02T05:00:00.000Z", "__v": 0}
    if method:
        p["teachingMethodology"] = method
    if reason is not None:
        p["rejectionReason"] = reason
    if notes is not None:
        p["approverNotes"] = notes
        p["approvedBy"] = S._oid(0xc9)
        p["approvedAt"] = "2026-10-03T08:00:00.000Z"
    p.update(more)
    return p


def seed_plans():
    if _state["seeded"]:
        return
    _state["seeded"] = True
    a1 = S.ACCOUNTS["teacher"]["staffId"]
    b1 = S.ACCOUNTS["teacher"]["teacherProfileId"]
    plans = [
        _plan(1, a1, "Fractions (DUMMY)", "rejected", days=-2, reason="Add an assessment section and a homework task (DUMMY reason)",
              objectives=["Add fractions with like denominators", "Compare two fractions"], resources=["Textbook", "Whiteboard"],
              method="lecture", description="Introduction to fractions.", assessment="", homework="Exercise 4.1"),
        _plan(2, a1, "Decimals (DUMMY)", "submitted", days=1, objectives=["Read decimals to two places"], method="activity",
              activities="Place-value cards in pairs.", resources=["Handouts"]),
        # stale reason: rejectionReason is NOT cleared when a plan is edited and re-submitted (TS:191-207 raw $set)
        _plan(3, a1, "Percentages (DUMMY)", "submitted", days=2, reason="Old reason from an earlier rejection (DUMMY)",
              objectives=["Convert a fraction to a percentage"]),
        _plan(4, a1, "Ratios (DUMMY)", "approved", days=-5, notes="Well structured. Please add an exit ticket next time (DUMMY).",
              objectives=["Simplify a ratio"], resources=["Textbook", "Projector"], method="discussion"),
        _plan(5, a1, "Geometry basics (DUMMY)", "draft", days=4),
        _plan(6, a1, "Angles (DUMMY)", "overdue", days=-9, objectives=["Measure an angle"]),
        _plan(7, a1, "Plant growth (DUMMY)", "draft", days=3, subject="Science", grade="Grade 6", section="B"),
        # legacy row keyed by the TeacherProfile id (the web sends TeacherProfile._id, LessonPlansTab.tsx handleTeacherSelect;
        # TS:381-392 tolerates both) - id semantics in real data UNVERIFIED
        _plan(8, b1, "Legacy plan keyed by profile id (DUMMY)", "approved", days=-12),
        # a colleague's plan: GET without the teacherId filter returns it (no owner scoping, TS:151-162)
        _plan(9, S.OTHER_STAFF, "Colleague's plan (DUMMY)", "submitted", days=2, teacher_name="Other Teacher", subject="English"),
    ]
    for p in plans:
        _state["plans"][p["_id"]] = p


def list_plans(account, q):
    """GET /teaching/lesson-plans (TC:59-60 -> TS:151-162): filters teacherId (cast to ObjectId: an invalid one throws -> 500),
    status, subject, gradeLevel (exact); campus forced for a teacher (resolveCampusScope; plans with a null campus are hidden);
    sort planDate desc; hard limit(100); NO pagination, NO total; bare array."""
    seed_plans()

    def arg(k):
        return (q.get(k) or [""])[0]

    tid = arg("teacherId")
    if tid and not _is_oid(tid):
        return 500, "Internal server error"
    rows = list(_state["plans"].values())
    if tid:
        rows = [p for p in rows if p["teacherId"] == tid]
    for key in ("status", "subject", "gradeLevel"):
        if arg(key):
            rows = [p for p in rows if p.get(key) == arg(key)]
    rows = [p for p in rows if p.get("campusId") == S.CAMPUS_ID]
    rows.sort(key=lambda p: p["planDate"], reverse=True)
    return 200, rows[:100]


def _mongoose_required(path):
    return f"LessonPlan validation failed: {path}: Path `{path}` is required."


def create_plan(account, body):
    """POST /teaching/lesson-plans (TC:62-64 -> TS:164-189). Guard STAFF_WRITE_ROLES (teacher passes). No DTO: body `any`, so
    NO whitelist (the global ValidationPipe only strips DTO classes): any schema path survives mongoose strict mode, INCLUDING
    `status` / `approvedBy` / `rejectionReason` (a teacher could create an 'approved' plan: UI-gating only). `objectives` is
    renamed to `learningObjectives` (TS:175). For a TEACHER the teacherId is derived (TS:176-179; TID:61-65): absent -> me,
    my Staff or TeacherProfile id -> normalised to my Staff id, anything else -> 403 'You can only create lesson plans for
    yourself'. `campusId` is the caller's campus (TS:173). A mongoose ValidationError -> 400 with the full mongoose message
    (TS:183-188; exact wording UNVERIFIED: mongoose default templates). Returns the created document (HTTP 201)."""
    seed_plans()
    if not isinstance(body, dict):
        body = {}
    sent = body.get("teacherId")
    if sent in (None, ""):
        tid = account["staffId"]
    elif sent in _me_ids(account):
        tid = account["staffId"]
    else:
        return 403, "You can only create lesson plans for yourself"
    doc = {k: v for k, v in body.items() if k in LP_FIELDS and k not in ("teacherId", "tenantId", "institutionId", "campusId")}
    if "objectives" in body and body["objectives"]:
        doc["learningObjectives"] = body["objectives"]
    for req in ("subject", "gradeLevel", "topic", "planDate"):
        if not doc.get(req):
            return 400, _mongoose_required(req)
    if doc.get("status") is not None and doc["status"] not in TERM_STATUSES:
        return 400, f"LessonPlan validation failed: status: `{doc['status']}` is not a valid enum value for path `status`."
    pd = _parse_plan_date(doc["planDate"])
    if pd is None:
        return 400, (f'LessonPlan validation failed: planDate: Cast to date failed for value "{doc["planDate"]}" '
                     f'(type string) at path "planDate"')
    doc["planDate"] = pd
    for num in ("durationMins", "weekNumber"):
        if num in doc and not isinstance(doc[num], (int, float)):
            return 400, f'LessonPlan validation failed: {num}: Cast to Number failed for value "{doc[num]}" (type string) at path "{num}"'
    _state["lp_counter"] += 1
    p = {"_id": S._oid(_state["lp_counter"]), "tenantId": S._oid(0xa1), "institutionId": S._oid(0xa2), "teacherId": tid,
         "campusId": S.CAMPUS_ID, "durationMins": 40, "learningObjectives": [], "resources": [], "sloTags": [],
         "syllabusPageFrom": 0, "syllabusPageTo": 0, "status": "draft", "createdAt": _now(), "updatedAt": _now(), "__v": 0}
    p.update(doc)
    _state["plans"][p["_id"]] = p
    _state["last_create"] = {"keys": sorted(body.keys()), "status": p["status"]}
    return 201, p


def _parse_plan_date(v):
    """mongoose Date cast of a string: 'YYYY-MM-DD' (UTC midnight) or a full ISO instant; anything else fails."""
    if not isinstance(v, str):
        return None
    m = re.fullmatch(r"(\d{4}-\d{2}-\d{2})(T.*)?", v)
    if not m:
        return None
    try:
        d = datetime.date.fromisoformat(m.group(1))
    except ValueError:
        return None
    return v if m.group(2) else _midnight(d)


def update_plan(account, pid, body, mode=None):
    """PATCH /teaching/lesson-plans/:id (TC:80-82 -> TS:191-207). Raw `$set` of the body: NO DTO, NO whitelist, NO validation
    (findOneAndUpdate without runValidators), so ANY schema path can be set, including `status`. For a TEACHER: unknown id ->
    HTTP 200 with an EMPTY body (the service returns null, TS:195); not my plan -> 403 'You can only modify your own lesson
    plans'; tenantId/institutionId/campusId are dropped; `teacherId` may only be restated as myself. Unknown (non-schema) paths
    such as `objectives` are silently dropped by mongoose strict mode (so an edit must send `learningObjectives`; the web sends
    `objectives` on edit, which is lost: found in code, see report). `rejectionReason` is never cleared. A cast failure on
    update (e.g. planDate 'x') -> CastError -> 500 (UNVERIFIED)."""
    seed_plans()
    if not isinstance(body, dict):
        body = {}
    p = _state["plans"].get(pid)
    if mode == "notfound":
        p = None
    if p is None:
        return 200, None
    if p["teacherId"] not in _me_ids(account):
        return 403, "You can only modify your own lesson plans"
    data = dict(body)
    for k in ("tenantId", "institutionId", "campusId"):
        data.pop(k, None)
    if "teacherId" in data:
        if data["teacherId"] in (None, "") or data["teacherId"] in _me_ids(account):
            data["teacherId"] = account["staffId"]
        else:
            return 403, "You can only create lesson plans for yourself"
    applied = {k: v for k, v in data.items() if k in LP_FIELDS}
    if "planDate" in applied:
        pd = _parse_plan_date(applied["planDate"])
        if pd is None:
            return 500, "Internal server error"
        applied["planDate"] = pd
    p.update(applied)
    p["updatedAt"] = _now()
    _state["last_patch"] = {"keys": sorted(body.keys()), "dropped": sorted(k for k in body if k not in LP_FIELDS)}
    return 200, p


# ---- parse-upload -------------------------------------------------------------------------------------------------------

def _canned_draft(file_name, topic="Equivalent fractions"):
    """The shape returned by parseLessonPlanUpload (TS:294-379, the final `return {...}`): topic, description, durationMins|null,
    teachingMethodology|null, objectives[], resources[] (only from the known list), otherResource (single string, '; '-joined),
    homework, subjectGuess|null, gradeLevelGuess|null, warnings[], sourceFileName|null. The CONTENT below is canned DUMMY data
    (the real one comes from a Claude call, TS:266-292)."""
    return {
        "topic": f"{topic} (DUMMY parse)", "description": "Students explore equivalent fractions with paper strips.",
        "durationMins": 45, "teachingMethodology": "activity",
        "objectives": ["Students will be able to find two equivalent fractions", "Students will be able to simplify a fraction"],
        "resources": ["Textbook", "Handouts"], "otherResource": "Paper strips; coloured pencils",
        "homework": "Worksheet 3, questions 1-8", "subjectGuess": "Maths", "gradeLevelGuess": "Grade 5",
        "warnings": ["No clear duration found; check the 45 minutes", "Could not find an assessment section"],
        "sourceFileName": file_name,
    }


def parse_upload(account, content_type, body, mode=None):
    """POST /teaching/lesson-plans/parse-upload (TC:66-78 -> TS:294-379). multipart: file field `file` (FileInterceptor('file',
    memoryStorage, 10 MB), TC:74) and/or text field `sourceUrl`. Neither -> 400 'Upload a file or paste a Google Doc link.'
    (TC:76). Types by extension/mime (TS:225-247): .docx, .xlsx/.xls/.csv, .txt accepted; .doc -> 400 (save as .docx); .pdf ->
    400 (not supported yet); anything else 400 'Unsupported file type...'. < 20 readable characters -> 400 (TS:302-306). AI key
    missing -> 500 'AI assistance is not configured on this server.' (TS:267); Claude unreachable/non-2xx -> 502; unparseable
    JSON -> 502 'Could not understand...' (TS:333-338). Google link: must contain /d/<id> or id= else 400; not shared -> 400.
    Never saves a plan. NOTE the stub cannot read docx/xlsx; it only checks the type, the size and that the file is not tiny."""
    from stub_5b import parse_multipart  # same helper as the upload stub
    if not content_type.startswith("multipart/form-data"):
        return 400, "Upload a file or paste a Google Doc link."
    try:
        parts = parse_multipart(content_type, body)
    except Exception:
        return 400, "Multipart: Malformed part header"
    for name in parts:
        if name not in ("file", "sourceUrl"):
            return 400, f"Unexpected field - {name}"
    link = (parts.get("sourceUrl") or (None, None, b""))[2].decode("utf-8", "ignore").strip()
    has_file = "file" in parts and parts["file"][2] is not None and (parts["file"][0] or len(parts["file"][2]) > 0)
    if not has_file and not link:
        return 400, "Upload a file or paste a Google Doc link."
    if has_file:
        fname, ctype, data = parts["file"]
        if len(data) > MAX_UPLOAD:
            return 413, "File too large"
        low = (fname or "").lower()
        if low.endswith((".docx", ".xlsx", ".xls", ".csv", ".txt")):
            pass
        elif low.endswith(".doc"):
            return 400, "Old .doc files aren't supported - please save/export it as .docx (File > Save As > Word Document) and try again."
        elif low.endswith(".pdf"):
            return 400, "PDF upload isn't supported yet - please upload the original Word/Excel file, or paste a Google Doc link instead."
        else:
            return 400, "Unsupported file type. Please upload a .docx, .xlsx, .xls, .csv, or .txt file."
        if len(data.strip()) < 20:
            return 400, "Could not find any readable text in this document. If it's mostly images/scans, you'll need to fill the form in manually."
        source_name = fname
    else:
        if not re.search(r"/d/([a-zA-Z0-9_-]+)", link) and not re.search(r"[?&]id=([a-zA-Z0-9_-]+)", link):
            return 400, "That doesn't look like a Google Docs link. Paste the full link from the document's \"Share\" button."
        if mode == "googledenied":
            return 400, "Could not open this Google Doc. Make sure sharing is set to \"Anyone with the link can view\", then try again."
        source_name = None
    if mode == "aioff":
        return 500, "AI assistance is not configured on this server."
    if mode == "badjson":
        return 502, "Could not understand this document's structure. Try a simpler/cleaner file, or fill the form in manually."
    _state["last_parse"] = {"file": bool(has_file), "link": bool(link), "fileName": source_name}
    return 200, _canned_draft(source_name)


# ============================== SYLLABUS ==============================

def _sub(no, name, week=None, covered=False, by=None):
    s = {"subTopicNo": no, "subTopicName": name, "description": "", "isCovered": covered}
    if week is not None:
        s["plannedWeek"] = week
    if covered:
        s["coveredDate"] = _now()
        s["coveredBy"] = by or "Tess Teacher"
    return s


def _topic(no, name, subs=None, covered=False, lessons=None, est=2):
    t = {"topicNo": no, "topicName": name, "description": "", "learningObjectives": [], "sloReferences": [], "estimatedLessons": est,
         "subTopics": list(subs or []), "lessons": list(lessons or []), "isCovered": covered}
    if covered:
        t["coveredDate"] = _now()
        t["coveredBy"] = "Tess Teacher"
    return t


def _rollup(units):
    """computeRollup (SS:55-79): per topic WITH sub-topics count sub-topics, else the topic itself; pct = round(); trackStatus
    completed (100) | on_track (>0) | not_started. ('behind' is only ever set by PATCH :id/behind-schedule, SS:551-562.)"""
    total = covered = 0
    for u in units:
        for t in u.get("topics", []):
            if t.get("subTopics"):
                total += len(t["subTopics"])
                covered += sum(1 for s in t["subTopics"] if s.get("isCovered"))
            else:
                total += 1
                covered += 1 if t.get("isCovered") else 0
    pct = int(round(covered / total * 100)) if total else 0
    status = "completed" if pct == 100 else ("on_track" if pct > 0 else "not_started")
    return {"totalTopics": total, "coveredTopics": covered, "coveragePct": pct, "trackStatus": status}


def _syllabus(n, subject, grade, section, teacher_id, teacher_name, units, *, status="active", term="Term 1", track=None,
              year="2026-27", published=False, **more):
    doc = {"_id": S._oid(0x800 + n), "tenantId": S._oid(0xa1), "institutionId": S._oid(0xa2), "campusId": S.CAMPUS_ID,
           "subjectName": subject, "gradeLevel": grade, "academicYearLabel": year, "term": term, "framework": "national",
           "recommendedTextbook": "Maths Today 5 (DUMMY)", "totalWeeks": 12, "totalPeriods": 48, "units": units,
           "assessmentBreakdown": {"midTerm": 30, "finalExam": 50, "classwork": 10, "homework": 10},
           "teacherId": teacher_id, "teacherName": teacher_name, "status": status, "createdBy": S._oid(0xc9),
           "createdByName": "Admin (DUMMY)", "publishedToStudents": published, "createdAt": "2026-08-20T05:00:00.000Z",
           "updatedAt": "2026-10-01T05:00:00.000Z", "__v": 0}
    if section is not None:
        doc["sectionName"] = section
    doc.update(_rollup(units))
    if track:
        doc["trackStatus"] = track
    doc.update(more)
    return doc


def _unit(no, name, topics):
    return {"unitNo": no, "unitName": name, "weeks": 6, "periods": 24, "topics": topics}


def term_start_for_week(week):
    """UTC midnight of a term start such that TODAY (UTC) is in week `week` (SS:251-260: floor(diff/7d)+1)."""
    return datetime.datetime.combine(S._today(), datetime.time()) - datetime.timedelta(days=7 * (week - 1) + 2)


def academic_years():
    """The AcademicYear terms the stub 'knows' (SS:251-260: findOne({schoolSlug, name}) then the term by NAME). 'Term 3' is
    deliberately missing, so a syllabus on it has no computable week and is skipped by the planner (SS:306-307)."""
    return {"2026-27": {"Term 1": term_start_for_week(5), "Term 2": term_start_for_week(1) + datetime.timedelta(days=56)}}


def seed_syllabi():
    if _state["syllabi"]:
        return
    a1 = S.ACCOUNTS["teacher"]["staffId"]
    maths = _syllabus(1, "Mathematics", "Grade 5", "A", a1, "Tess Teacher", [
        _unit(1, "Numbers and operations", [
            _topic(1, "Adding fractions", [_sub(1, "Like denominators", 3, True), _sub(2, "Unlike denominators", 4, True),
                                          _sub(3, "Mixed numbers", 5)], est=4,
                   lessons=[{"lessonNo": 1, "title": "Fractions explained (video)", "description": "", "type": "video",
                             "url": "https://example.test/video/fractions", "order": 0, "addedBy": "Admin (DUMMY)",
                             "addedAt": "2026-09-01T05:00:00.000Z"},
                            {"lessonNo": 2, "title": "Practice sheet", "description": "", "type": "document",
                             "fileUrl": "https://example.test/files/practice.pdf", "fileName": "practice.pdf", "order": 1,
                             "addedBy": "Admin (DUMMY)", "addedAt": "2026-09-01T05:00:00.000Z"}]),
            _topic(2, "Decimals", [_sub(1, "Place value", 5), _sub(2, "Rounding", 6)]),
            _topic(3, "Number patterns", covered=True, est=1),
        ]),
        _unit(2, "Measurement", [
            _topic(1, "Perimeter and area", [_sub(1, "Perimeter", 7), _sub(2, "Area of rectangles", 8)]),
            _topic(2, "Time and money", est=3),
        ]),
    ], track="on_track", teacherName="Tess Teacher")
    science = _syllabus(2, "Science", "Grade 6", "B", a1, "Tess Teacher", [
        _unit(1, "Plants", [_topic(1, "Photosynthesis", [_sub(1, "Inputs", 2, True), _sub(2, "Outputs", 3), _sub(3, "Chlorophyll", 5)]),
                            _topic(2, "Plant growth", est=3)]),
    ], status="approved", track="behind")
    shared = _syllabus(3, "Mathematics", "Grade 5", None, S.OTHER_STAFF, "Other Teacher", [
        _unit(1, "Whole grade scheme (DUMMY)", [_topic(1, "Place value", [_sub(1, "Thousands", 2, True)]), _topic(2, "Estimation")]),
    ])
    english = _syllabus(4, "English", "Grade 5", "A", S.OTHER_STAFF, "Other Teacher", [
        _unit(1, "Reading", [_topic(1, "Main idea", est=1)])])  # NOT my subject: the app must drop it
    legacy = _syllabus(5, "Mathematics", "Grade 7", "C", S.ACCOUNTS["teacher"]["teacherProfileId"], "Tess Teacher", [
        _unit(1, "Algebra", [_topic(1, "Expressions", [_sub(1, "Terms", 5)])])])  # keyed by the TeacherProfile id (UNVERIFIED)
    term3 = _syllabus(6, "Science", "Grade 6", "B", a1, "Tess Teacher", [
        _unit(1, "Energy", [_topic(1, "Forms of energy", [_sub(1, "Heat", 1)])])], term="Term 3")
    empty = _syllabus(7, "Art", "Grade 6", "B", a1, "Tess Teacher", [], status="draft")
    for d in (maths, science, shared, english, legacy, term3, empty):
        _state["syllabi"][d["_id"]] = d


def list_syllabi(account, q):
    """GET /syllabus (SC:106-109 -> SS:95-110). Query validated by SyllabusQueryDto (SD:152-161, global ValidationPipe MAIN:70-74):
    teacherId must be a MongoId (400 'teacherId must be a mongodb id'), status / trackStatus enums. NO pagination, NO limit; no
    owner scoping (campus only: resolveCampusScope; a teacher without a campus -> 403 SCOPE:85-90). Sorted gradeLevel, subjectName.
    Bare array of FULL documents (units > topics > subTopics, lessons)."""
    seed_syllabi()

    def arg(k):
        return (q.get(k) or [""])[0]

    if arg("teacherId") and not _is_oid(arg("teacherId")):
        return 400, "teacherId must be a mongodb id"
    if arg("status") and arg("status") not in ("draft", "active", "approved", "archived"):
        return 400, "status must be one of the following values: draft, active, approved, archived"
    if arg("trackStatus") and arg("trackStatus") not in ("not_started", "on_track", "behind", "completed"):
        return 400, "trackStatus must be one of the following values: not_started, on_track, behind, completed"
    rows = [d for d in _state["syllabi"].values() if d.get("campusId") == S.CAMPUS_ID]
    for qk, dk in (("gradeLevel", "gradeLevel"), ("sectionName", "sectionName"), ("subjectName", "subjectName"),
                   ("academicYearLabel", "academicYearLabel"), ("term", "term"), ("teacherId", "teacherId"),
                   ("status", "status"), ("trackStatus", "trackStatus")):
        if arg(qk):
            rows = [d for d in rows if d.get(dk) == arg(qk)]
    rows.sort(key=lambda d: (d["gradeLevel"], d["subjectName"]))
    return 200, rows


def get_syllabus(account, sid):
    """GET /syllabus/:id (SC:111-114 -> SS:112-116): tenant only, NO campus or owner check; 404 'Syllabus not found'; an invalid id
    is a CastError -> 500."""
    seed_syllabi()
    if not _is_oid(sid):
        return 500, "Internal server error"
    d = _state["syllabi"].get(sid)
    return (200, d) if d else (404, "Syllabus not found")


def _check_num(body, key):
    v = body.get(key)
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        return f"{key} must be a number conforming to the specified constraints"
    return None


def _find_topic(doc, unit_no, topic_no):
    unit = next((u for u in doc["units"] if u["unitNo"] == unit_no), None)
    if unit is None:
        return None, f"Unit {unit_no} not found"
    topic = next((t for t in unit["topics"] if t["topicNo"] == topic_no), None)
    if topic is None:
        return None, f"Topic {topic_no} not found in unit {unit_no}"
    return topic, None


def mark_topic(account, sid, body, mode=None):
    """PATCH /syllabus/:id/mark-topic (SC:139-143 -> SS:524-544). Guard STAFF_WRITE_ROLES + academics module (teacher passes), NO
    ownership check. Body MarkTopicDto (SD:93-100; ValidationPipe whitelist strips other keys): unitNo number, topicNo number,
    isCovered boolean, coveredBy? string, actualLessonsUsed? number, notes? string. First failing constraint only (FLT:46).
    404 'Syllabus not found' / 'Unit N not found' / 'Topic N not found in unit M'. Sets topic.isCovered DIRECTLY even when the
    topic has sub-topics (SS:533; the schema comment SY:80-89 says it should be derived, but this route does not enforce it, and
    the rollup then ignores the topic: the app therefore never marks a topic that has sub-topics). Returns the whole saved
    syllabus (re-rolled coveragePct/trackStatus, lastTrackedAt)."""
    seed_syllabi()
    if not isinstance(body, dict):
        body = {}
    for key in ("unitNo", "topicNo"):
        msg = _check_num(body, key)
        if msg:
            return 400, msg
    if not isinstance(body.get("isCovered"), bool):
        return 400, "isCovered must be a boolean value"
    if "coveredBy" in body and body["coveredBy"] is not None and not isinstance(body["coveredBy"], str):
        return 400, "coveredBy must be a string"
    if "actualLessonsUsed" in body and body["actualLessonsUsed"] is not None and not isinstance(body["actualLessonsUsed"], (int, float)):
        return 400, "actualLessonsUsed must be a number conforming to the specified constraints"
    if "notes" in body and body["notes"] is not None and not isinstance(body["notes"], str):
        return 400, "notes must be a string"
    if not _is_oid(sid):
        return 500, "Internal server error"
    doc = _state["syllabi"].get(sid)
    if doc is None or mode == "notfound":
        return 404, "Syllabus not found"
    topic, err = _find_topic(doc, int(body["unitNo"]), int(body["topicNo"]))
    if err:
        return 404, err
    topic["isCovered"] = body["isCovered"]
    if body["isCovered"]:
        topic["coveredDate"] = _now()
    else:
        topic.pop("coveredDate", None)
    if body.get("coveredBy") is not None:
        topic["coveredBy"] = body["coveredBy"]
    else:
        topic.pop("coveredBy", None)
    if body.get("actualLessonsUsed") is not None:
        topic["actualLessonsUsed"] = body["actualLessonsUsed"]
    if body.get("notes") is not None:
        topic["notes"] = body["notes"]
    doc.update(_rollup(doc["units"]))
    doc["lastTrackedAt"] = _now()
    _state["mark_calls"] += 1
    return 200, doc


def mark_sub_topic(account, sid, body, mode=None):
    """PATCH /syllabus/:id/mark-sub-topic (SC:145-149 -> SS:262-293). Body MarkSubTopicDto (SD:102-109): unitNo, topicNo,
    subTopicNo numbers, isCovered boolean, coveredBy? string, notes? string. 404 as above plus 'Sub-topic N not found in topic M'.
    Derives the parent topic's isCovered from ALL its sub-topics (SS:281-286), re-rolls the syllabus (trackStatus is overwritten
    with on_track/completed/not_started, so a manual 'behind' flag is lost on the first mark: SS:289 Object.assign(rollup))
    and returns the whole saved syllabus."""
    seed_syllabi()
    if not isinstance(body, dict):
        body = {}
    for key in ("unitNo", "topicNo", "subTopicNo"):
        msg = _check_num(body, key)
        if msg:
            return 400, msg
    if not isinstance(body.get("isCovered"), bool):
        return 400, "isCovered must be a boolean value"
    if "coveredBy" in body and body["coveredBy"] is not None and not isinstance(body["coveredBy"], str):
        return 400, "coveredBy must be a string"
    if not _is_oid(sid):
        return 500, "Internal server error"
    doc = _state["syllabi"].get(sid)
    if doc is None or mode == "notfound":
        return 404, "Syllabus not found"
    topic, err = _find_topic(doc, int(body["unitNo"]), int(body["topicNo"]))
    if err:
        return 404, err
    sub = next((s for s in topic["subTopics"] if s["subTopicNo"] == int(body["subTopicNo"])), None)
    if sub is None:
        return 404, f"Sub-topic {int(body['subTopicNo'])} not found in topic {int(body['topicNo'])}"
    sub["isCovered"] = body["isCovered"]
    if body["isCovered"]:
        sub["coveredDate"] = _now()
    else:
        sub.pop("coveredDate", None)
    if body.get("coveredBy") is not None:
        sub["coveredBy"] = body["coveredBy"]
    else:
        sub.pop("coveredBy", None)
    if body.get("notes") is not None:
        sub["notes"] = body["notes"]
    if topic["subTopics"]:
        allc = all(s["isCovered"] for s in topic["subTopics"])
        topic["isCovered"] = allc
        if allc:
            topic["coveredDate"] = _now()
            if body.get("coveredBy") is not None:
                topic["coveredBy"] = body["coveredBy"]
        else:
            topic.pop("coveredDate", None)
            topic.pop("coveredBy", None)
    doc.update(_rollup(doc["units"]))
    doc["lastTrackedAt"] = _now()
    _state["mark_calls"] += 1
    return 200, doc


def weekly_planner(account, q):
    """GET /syllabus/weekly-planner?teacherId= (SC:31-37 -> SS:301-332). `teacherId` is a plain @Query (no DTO): an absent one
    makes `new Types.ObjectId(undefined)` generate a RANDOM id -> empty array (not an error); an invalid string -> 500. Only
    syllabi with status in [active, approved] and teacherId == the id; the week is the CURRENT week only, computed per syllabus
    from the matching AcademicYear term start (floor(diff/7d)+1, null when the year/term is unknown or not started: that
    syllabus is skipped). There is NO date/week parameter. Result: [{syllabusId, subjectName, gradeLevel, sectionName,
    currentWeek, subTopics:[{unitNo, unitName, topicNo, topicName, subTopicNo, subTopicName, isCovered}]}], only syllabi that
    have >= 1 sub-topic planned for that week. NOTE: no `status`/campus scope, and a topic WITHOUT sub-topics never appears."""
    seed_syllabi()
    tid = (q.get("teacherId") or [""])[0]
    if tid and not _is_oid(tid):
        return 500, "Internal server error"
    years = academic_years()
    out = []
    now = datetime.datetime.combine(S._today(), datetime.time())
    for d in sorted(_state["syllabi"].values(), key=lambda x: x["_id"]):
        if not tid or d.get("teacherId") != tid or d["status"] not in ("active", "approved"):
            continue
        start = years.get(d["academicYearLabel"], {}).get(d.get("term"))
        if start is None:
            continue
        diff = (now - start).total_seconds()
        if diff < 0:
            continue
        week = int(diff // (7 * 24 * 3600)) + 1
        subs = []
        for u in d["units"]:
            for t in u["topics"]:
                for s in t["subTopics"]:
                    if s.get("plannedWeek") == week:
                        subs.append({"unitNo": u["unitNo"], "unitName": u["unitName"], "topicNo": t["topicNo"],
                                     "topicName": t["topicName"], "subTopicNo": s["subTopicNo"], "subTopicName": s["subTopicName"],
                                     "isCovered": s["isCovered"]})
        if subs:
            e = {"syllabusId": d["_id"], "subjectName": d["subjectName"], "gradeLevel": d["gradeLevel"], "currentWeek": week,
                 "subTopics": subs}
            if d.get("sectionName") is not None:
                e["sectionName"] = d["sectionName"]
            out.append(e)
    return 200, out
