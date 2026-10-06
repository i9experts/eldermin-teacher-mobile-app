"""Phase 5b stub logic: homework (assignments CRUD, submissions, grading), upload, behaviour records, tarbiyah.

!! DUMMY DATA ONLY. Lives under tool/dev/, never shipped. Imported by stub_server.py (which owns HTTP routing, auth,
!! and the dev mode switches). Every function returns (status, body) so tests can call it directly.

Citation legend (paths relative to eldermin-backend/src/, branch feat/staff-portal; "UNVERIFIED" = cannot be
confirmed from code and is listed in PHASE5B_REPORT.md):
  TC   = modules/teaching/teaching.controller.ts      TS  = modules/teaching/teaching.service.ts
  DTO  = modules/teaching/dto/assignment.dto.ts       AS  = modules/teaching/schemas/assignment.schema.ts
  SUB  = modules/teaching/schemas/assignment-submission.schema.ts
  UC   = upload/upload.controller.ts   US = upload/upload.service.ts   UM = upload/upload.module.ts
  BC   = behaviour/behaviour.controller.ts   BS = behaviour/behaviour.service.ts   BSC = behaviour/schemas/behaviour.schema.ts
  PPS  = parent-portal/parent-portal.service.ts   FLT = filters/sentry.filter.ts   MAIN = main.ts
  JWT  = modules/auth/jwt.strategy.ts   SCOPE = auth/scope.util.ts
"""
import datetime
import math
import re
import uuid
from email.parser import BytesParser
from email.policy import HTTP

S = None  # the stub_server module, injected by bind() (works when stub_server runs as __main__)


def bind(mod):
    global S
    S = mod

MAX_FILE_SIZE = 10 * 1024 * 1024  # US:17 / UM:11 (multer limit -> 413 'File too large', multer.constants LIMIT_FILE_SIZE)

ASSIGNMENT_TYPES = ["homework", "classwork", "project", "quiz", "test", "lab_work", "presentation", "other"]  # DTO:5
ASSIGNMENT_STATUSES = ["draft", "assigned"]  # DTO:6 (the schema also allows submitted|graded|overdue, AS:23)

_state = {"assignments": {}, "subs": {}, "seeded": set(), "sub_counter": 0x10000, "asg_counter": 0x2000,
          "uploads": {}, "records": [], "rec_counter": 0, "tarbiyah": [], "seeded_b": False, "last_upload": None}


def reset():
    """Re-arm all Phase 5b state (POST /__stub/reset-state)."""
    for k in ("assignments", "subs", "uploads"):
        _state[k] = {}
    _state["seeded"] = set()
    _state["records"] = []
    _state["tarbiyah"] = []
    _state["seeded_b"] = False
    _state["sub_counter"] = 0x10000
    _state["asg_counter"] = 0x2000
    _state["rec_counter"] = 0
    _state["last_upload"] = None


def state_summary():
    return {"assignments": len(_state["assignments"]), "uploads": len(_state["uploads"]),
            "behaviourRecords": len(_state["records"]), "lastUpload": _state["last_upload"]}


def _today():
    return S._today()


def _midnight(d):
    return f"{d.isoformat()}T00:00:00.000Z"


def _now_iso():
    return datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")


# ============================== HOMEWORK ==============================

def _asg_doc(aid, teacher_id, teacher_name, title, subject, grade, section, due_days, status, typ="homework",
             description="", instructions="", total=100, passing=50, keys=None, campus=None):
    """Assignment document, fields AS:7-33 (verified). `teacherId` ref Staff (AS:10). status default 'draft' (AS:23)."""
    due = _today() + datetime.timedelta(days=due_days) if due_days is not None else None
    return {
        "_id": aid, "tenantId": S._oid(0xa1), "institutionId": S._oid(0xa2), "teacherId": teacher_id,
        "teacherName": teacher_name, "campusId": campus or S.CAMPUS_ID, "title": title, "description": description,
        "subject": subject, "gradeLevel": grade, "sectionName": section, "type": typ,
        "assignedDate": _midnight(_today() - datetime.timedelta(days=3)) if status != "draft" else None,
        "dueDate": _midnight(due) if due else None, "totalMarks": total, "passingMarks": passing, "status": status,
        "submissionsCount": 0, "avgScore": 0, "attachmentS3Keys": list(keys or []), "instructions": instructions,
        "createdAt": "2026-10-01T05:00:00.000Z", "updatedAt": "2026-10-01T05:00:00.000Z", "__v": 0,
    }


def _class_roster(grade, section, campus_id):
    """getClassRoster (TS:940-947): EXACT match on currentGrade (+ currentSection when given), status active, campusId.
    Students stored with other spellings ('5'/'a') are NOT found (U4 in PHASE5A_REPORT)."""
    out = []
    for st in S.STUDENTS:
        if st["currentGrade"] != grade or st["status"] != "active":
            continue
        if section and st["currentSection"] != section:
            continue
        if campus_id and st["campusId"] != campus_id:
            continue
        out.append(st)
    return out


def _new_sub(asg, st):
    _state["sub_counter"] += 1
    return {
        "_id": S._oid(_state["sub_counter"]), "tenantId": asg["tenantId"], "institutionId": asg["institutionId"],
        "campusId": asg["campusId"], "assignmentId": asg["_id"], "studentId": st["_id"],
        "studentName": f"{st['firstName']} {st['lastName']}".strip(), "status": "pending", "isLate": False,
        "attachmentS3Keys": [], "maxGrade": asg["totalMarks"] or 100, "grade": None,
        "createdAt": _now_iso(), "updatedAt": _now_iso(), "__v": 0,
    }


def materialize(asg):
    """materializeSubmissions (TS:949-977): idempotent upsert of 'pending' rows for the exact-match class roster."""
    rows = _state["subs"].setdefault(asg["_id"], [])
    have = {r["studentId"] for r in rows}
    for st in _class_roster(asg["gradeLevel"], asg.get("sectionName"), asg["campusId"]):
        if st["_id"] not in have:
            rows.append(_new_sub(asg, st))


def recompute(asg):
    """recomputeAssignmentStats (TS:1032-1054)."""
    rows = _state["subs"].get(asg["_id"], [])
    asg["submissionsCount"] = sum(1 for r in rows if r["status"] in ("submitted", "late", "graded"))
    graded = [r for r in rows if r["status"] == "graded"]
    asg["avgScore"] = round(sum(r["grade"] for r in graded) / len(graded), 2) if graded else 0


def _set_sub(asg, idx, status, **kw):
    r = _state["subs"][asg["_id"]][idx]
    r["status"] = status
    r.update(kw)
    return r


def seed_for(staff_id):
    """Seeds the four dummy assignments of a staff member once (same cast as the Phase 4 stub)."""
    if staff_id in _state["seeded"]:
        return
    _state["seeded"].add(staff_id)
    acct = next((a for a in S.ACCOUNTS.values() if a["staffId"] == staff_id), None)
    name = acct["name"] if acct else "Sample Teacher"
    k = (list(S.ACCOUNTS).index(next((n for n, a in S.ACCOUNTS.items() if a["staffId"] == staff_id), "teacher"))
         if acct else 7)
    base = 0x300 + 0x40 * k
    a1 = _asg_doc(S._oid(base + 1), staff_id, name, "Chapter 3 worksheet (DUMMY)", "Mathematics", "Grade 5", "A", 2,
                  "assigned", description="Complete questions 1-12 on page 34.", instructions="Show your working.",
                  keys=["demo-school/homework-attachments/3f1c0a52-worksheet.pdf"])
    a2 = _asg_doc(S._oid(base + 2), staff_id, name, "Lab report (DUMMY)", "Science", "Grade 6", "B", -1, "overdue",
                  typ="lab_work", total=20, passing=10, description="Write up the plant growth experiment.")
    a3 = _asg_doc(S._oid(base + 3), staff_id, name, "Reading log (DUMMY)", "English", "Grade 5", "A", -4, "assigned",
                  total=10, passing=5)
    a4 = _asg_doc(S._oid(base + 4), staff_id, name, "Draft quiz (DUMMY)", "Mathematics", "Grade 5", "A", 5, "draft",
                  typ="quiz", total=25, passing=12)
    for a in (a1, a2, a3, a4):
        _state["assignments"][a["_id"]] = a
        if a["status"] != "draft":
            materialize(a)
    # a1: 2 submitted (one with text, one with a file), 1 graded
    _set_sub(a1, 0, "submitted", submittedAt=_iso_ago(hours=5), textResponse="Done. Question 7 was tricky (DUMMY).")
    _set_sub(a1, 1, "submitted", submittedAt=_iso_ago(hours=20), textResponse="Photo of my notebook attached (DUMMY).",
             attachmentS3Keys=["demo-school/homework-submissions/9b2d77c1-notebook.jpg"])
    _set_sub(a1, 2, "graded", submittedAt=_iso_ago(hours=30), textResponse="Finished (DUMMY).", grade=18, maxGrade=a1["totalMarks"],
             feedback="Good work (DUMMY).", gradedAt=_iso_ago(hours=2))
    # a2: submitted, late, graded, graded, rest missed (cron, TS:1056-1070)
    for i, st in enumerate(["submitted", "late", "graded", "graded"]):
        extra = {"submittedAt": _iso_ago(hours=40 + i), "textResponse": f"My report (DUMMY {i})"}
        if st == "late":
            extra.update(isLate=True, attachmentS3Keys=["demo-school/homework-submissions/c41e90aa-report.pdf"])
        if st == "graded":
            extra.update(grade=15 - i, feedback="", gradedAt=_iso_ago(hours=3))
        _set_sub(a2, i, st, **extra)
    for r in _state["subs"][a2["_id"]][4:]:
        r["status"] = "missed"
    # a3: graded x2, late (not graded yet)
    _set_sub(a3, 0, "graded", submittedAt=_iso_ago(hours=90), grade=9, feedback="Great (DUMMY)", gradedAt=_iso_ago(hours=50))
    _set_sub(a3, 1, "graded", submittedAt=_iso_ago(hours=92), grade=7, gradedAt=_iso_ago(hours=50))
    _set_sub(a3, 2, "late", submittedAt=_iso_ago(hours=70), isLate=True, textResponse="Sorry it is late (DUMMY)")
    for a in (a1, a2, a3):
        recompute(a)
    if "colleague" not in _state["seeded"]:  # a colleague's assignment: returned only to an UNFILTERED list
        _state["seeded"].add("colleague")
        c = _asg_doc(S._oid(0x3f0), S.OTHER_STAFF, "Omar Colleague", "History essay (DUMMY colleague)", "History",
                     "Grade 5", "A", 3, "assigned")
        _state["assignments"][c["_id"]] = c


def _iso_ago(hours=0):
    return (datetime.datetime.utcnow() - datetime.timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%S.000Z")


def _is_oid(v):
    return isinstance(v, str) and re.fullmatch(r"[0-9a-fA-F]{24}", v) is not None


def list_assignments(account, q):
    """GET /teaching/assignments (TC:194-195 -> TS:861-871, verified): filter teacherId (ObjectId cast: an invalid id throws
    -> 500), status, gradeLevel; campus forced for non-owner roles (SCOPE:75-96); sorted dueDate desc; BARE ARRAY, no
    pagination. NOT restricted to the caller's own assignments unless teacherId is passed."""
    seed_for(account["staffId"])
    rows = list(_state["assignments"].values())
    tid = (q.get("teacherId") or [None])[0]
    if tid:
        if not _is_oid(tid):
            return 500, "Internal server error"
        rows = [r for r in rows if r["teacherId"] == tid]
    st = (q.get("status") or [None])[0]
    if st:
        rows = [r for r in rows if r["status"] == st]
    gl = (q.get("gradeLevel") or [None])[0]
    if gl:
        rows = [r for r in rows if r["gradeLevel"] == gl]
    rows = [r for r in rows if r["campusId"] == account["campus"]["id"]]
    rows.sort(key=lambda r: r["dueDate"] or "", reverse=True)
    return 200, rows


def _validate(body, creating):
    """class-validator checks of CreateAssignmentDto / UpdateAssignmentDto (DTO:8-48). Messages are class-validator's
    defaults (read in node_modules/class-validator: 'must be a string', 'must be a valid ISO 8601 date string',
    'must not be less than N', 'must be one of the following values: ...'); the filter returns only the FIRST (FLT:45)."""
    errs = []

    def is_str(k, required):
        v = body.get(k)
        if k in body and v is not None or required:
            if not isinstance(v, str):
                errs.append(f"{k} must be a string")

    def is_date(k):
        v = body.get(k)
        if v is not None and (not isinstance(v, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}([T ][\d:.]+(Z|[+-]\d{2}:?\d{2})?)?", v)):
            errs.append(f"{k} must be a valid ISO 8601 date string")

    def is_num(k):
        v = body.get(k)
        if v is not None:
            if not isinstance(v, (int, float)) or isinstance(v, bool):
                errs.append(f"{k} must be a number conforming to the specified constraints")
            elif v < 0:
                errs.append(f"{k} must not be less than 0")

    def is_enum(k, allowed):
        v = body.get(k)
        if v is not None and v not in allowed:
            errs.append(f"{k} must be one of the following values: {', '.join(allowed)}")

    if creating:
        if body.get("teacherId") is not None and not _is_oid(body.get("teacherId")):
            errs.append("teacherId must be a mongodb id")
    is_str("title", creating)
    is_str("description", False)
    is_str("subject", creating)
    is_str("gradeLevel", creating)
    is_str("sectionName", False)
    is_enum("type", ASSIGNMENT_TYPES)
    is_date("assignedDate")
    is_date("dueDate")
    is_num("totalMarks")
    is_num("passingMarks")
    is_enum("status", ASSIGNMENT_STATUSES)
    keys = body.get("attachmentS3Keys")
    if keys is not None and (not isinstance(keys, list) or any(not isinstance(x, str) for x in keys)):
        errs.append("each value in attachmentS3Keys must be a string" if isinstance(keys, list) else "attachmentS3Keys must be an array")
    is_str("instructions", False)
    return errs


_DTO_FIELDS = {"title", "description", "subject", "gradeLevel", "sectionName", "type", "assignedDate", "dueDate",
               "totalMarks", "passingMarks", "status", "attachmentS3Keys", "instructions"}


def create_assignment(account, body):
    """POST /teaching/assignments (TC:197-199 -> TS:873-908). Whitelisted by CreateAssignmentDto (MAIN:70-74): unknown keys are
    dropped. teacherId comes from the BODY (TS:874,887: the server never derives it from the token: hardening backlog) and an
    invalid one is silently ignored. Returns the created document (HTTP 201 default for @Post). status=assigned materialises
    the roster (TS:896-898)."""
    errs = _validate(body, True)
    if errs:
        return 400, errs[0]
    seed_for(account["staffId"])
    _state["asg_counter"] += 1
    aid = S._oid(0x300 + _state["asg_counter"])
    doc = _asg_doc(aid, body.get("teacherId"), "", body["title"], body["subject"], body["gradeLevel"],
                   body.get("sectionName") or "", None, body.get("status") or "draft", typ=body.get("type") or "homework",
                   description=body.get("description") or "", instructions=body.get("instructions") or "",
                   total=body.get("totalMarks", 100), passing=body.get("passingMarks", 50),
                   keys=body.get("attachmentS3Keys"), campus=account["campus"]["id"])
    if body.get("sectionName") is None:
        doc.pop("sectionName")
    doc["assignedDate"] = body.get("assignedDate")
    doc["dueDate"] = body.get("dueDate")
    doc["teacherName"] = account["name"] if body.get("teacherId") == account["staffId"] else None
    if doc["teacherName"] is None:
        doc.pop("teacherName")
    _state["assignments"][aid] = doc
    if doc["status"] == "assigned":
        materialize(doc)
    return 201, doc


def update_assignment(account, aid, body):
    """PATCH /teaching/assignments/:id (TC:201-203 -> TS:910-920): UpdateAssignmentDto whitelist (no teacherId/campus). 404
    'Assignment not found'. NO ownership check: any teacher can edit any assignment of the tenant (UI-gating only).
    Object.assign + save; draft->assigned materialises the roster (TS:915-918). Returns the updated document (200)."""
    errs = _validate(body, False)
    if errs:
        return 400, errs[0]
    a = _state["assignments"].get(aid)
    if not a:
        return 404, "Assignment not found"
    was_draft = a["status"] == "draft"
    for k, v in body.items():
        if k in _DTO_FIELDS:
            a[k] = v
    a["updatedAt"] = _now_iso()
    if was_draft and a["status"] == "assigned":
        materialize(a)
    return 200, a


def delete_assignment(account, aid):
    """DELETE /teaching/assignments/:id (TC:205-207 -> TS:922-929): 404 'Assignment not found'; deletes the submissions too
    (TS:926); returns { deleted: true }. NO ownership check."""
    a = _state["assignments"].pop(aid, None)
    if not a:
        return 404, "Assignment not found"
    _state["subs"].pop(aid, None)
    return 200, {"deleted": True}


def get_submissions(account, aid):
    """GET /teaching/assignments/:id/submissions (TC:209-210 -> TS:990-1002) -> { assignment, submissions } sorted by
    studentName; includes the roster snapshot rows (pending / missed = who has NOT submitted). 404 'Assignment not found';
    403 'This assignment belongs to a different campus.' for a campus mismatch (TS:995-997)."""
    a = _state["assignments"].get(aid)
    if not a:
        return 404, "Assignment not found"
    if a["campusId"] != account["campus"]["id"]:
        return 403, "This assignment belongs to a different campus."
    rows = sorted(_state["subs"].get(aid, []), key=lambda r: r["studentName"])
    return 200, {"assignment": a, "submissions": rows}


def grade_submission(account, aid, sid, body):
    """PATCH /teaching/assignments/:id/submissions/:submissionId (TC:212-216 -> TS:1004-1027). GradeSubmissionDto (DTO:50-53):
    grade IsNumber Min(0) Max(1000) required, feedback optional string. 404 'Submission not found'; grade > submission.maxGrade
    -> 400 "Grade cannot exceed this assignment's maximum of N." (TS:1007-1009). NO status check (pending/missed rows can be
    graded) and no ownership check. Sets grade/feedback/status='graded'/gradedAt/gradedBy; returns the submission (200)."""
    g = body.get("grade")
    if not isinstance(g, (int, float)) or isinstance(g, bool):
        return 400, "grade must be a number conforming to the specified constraints"
    if g < 0:
        return 400, "grade must not be less than 0"
    if g > 1000:
        return 400, "grade must not be greater than 1000"
    if body.get("feedback") is not None and not isinstance(body.get("feedback"), str):
        return 400, "feedback must be a string"
    rows = _state["subs"].get(aid, [])
    r = next((x for x in rows if x["_id"] == sid), None)
    if not r:
        return 404, "Submission not found"
    if g > r["maxGrade"]:
        return 400, f"Grade cannot exceed this assignment's maximum of {r['maxGrade']}."
    r.update(grade=g, feedback=body.get("feedback"), status="graded", gradedAt=_now_iso(), gradedBy=account["id"],
             updatedAt=_now_iso())
    recompute(_state["assignments"][aid])
    return 200, r


def pending_grading(staff_id, limit):
    """Same contract as stub_server.pending_grading (staff-teaching.service.ts:58-117) but derived from the LIVE submission
    store so grading in the app moves the Home counter."""
    seed_for(staff_id)
    rows = []
    for a in _state["assignments"].values():
        if a["teacherId"] != staff_id or a["status"] == "draft":
            continue
        subs = _state["subs"].get(a["_id"], [])
        ungraded = [r for r in subs if r["status"] in ("submitted", "late")]
        if not ungraded:
            continue
        oldest = min((r.get("submittedAt") or "9") for r in ungraded)
        rows.append({"assignmentId": a["_id"], "title": a["title"], "subject": a["subject"], "gradeLevel": a["gradeLevel"],
                     "sectionName": a.get("sectionName") or None, "dueDate": a["dueDate"], "submittedCount": len(ungraded),
                     "totalSubmissions": len(subs), "oldestSubmittedAt": oldest})
    rows.sort(key=lambda r: (r["oldestSubmittedAt"] or "9", r["dueDate"] or "9", r["title"]))
    try:
        n = int(limit)
        n = 50 if n < 1 else min(n, 200)
    except (TypeError, ValueError):
        n = 50
    return {"total": sum(r["submittedCount"] for r in rows), "items": rows[:n], "generatedAt": _now_iso()}


# ============================== UPLOAD ==============================

def parse_multipart(content_type, body):
    """Returns {name: (filename|None, content_type|None, bytes)} from a multipart/form-data body."""
    raw = b"Content-Type: " + content_type.encode() + b"\r\nMIME-Version: 1.0\r\n\r\n" + body
    msg = BytesParser(policy=HTTP).parsebytes(raw)
    out = {}
    if not msg.is_multipart():
        return out
    for part in msg.iter_parts():
        name = part.get_param("name", header="content-disposition")
        out[name] = (part.get_filename(), part.get_content_type() if part.get("Content-Type") else None,
                     part.get_payload(decode=True) or b"")
    return out


def upload_single(account, folder, content_type, body):
    """POST /upload/single/:folder (UC:20-31 -> US:34-69, verified). Multipart field MUST be named `file`
    (FileInterceptor('file'), UC:22; another name -> multer 400 'Unexpected field - <name>'). HTTP 201 (UC:21). No guard but the
    global JWT. Size limit 10 MB -> 413 'File too large' (UM:11; US:41 would say 400 'File too large. Max 10MB allowed.'
    but multer rejects first). NO file-type filter on the route (FileInterceptor gets no fileFilter; getMulterConfig() in
    US:101-113 is never applied) -> the app restricts types itself. Response { success: true, data: { url, key, fileName,
    fileSize, fileType } } (UC:30; US:34-69). key = `${schoolSlug}/${folder}/${uuid}${ext}` (US:44-45). `url` is the plain
    S3 URL (US:63); whether the bucket serves it publicly is UNVERIFIED -> clients use the signed URL instead."""
    if not content_type.startswith("multipart/form-data"):
        return 400, "Unexpected field"  # multer: no file -> controller US:40 'No file provided' (UNVERIFIED which fires first)
    try:
        parts = parse_multipart(content_type, body)
    except Exception:
        return 400, "Multipart: Malformed part header"
    for name in parts:
        if name != "file":
            return 400, f"Unexpected field - {name}"
    if "file" not in parts:
        return 400, "No file provided"
    fname, ctype, data = parts["file"]
    if len(data) > MAX_FILE_SIZE:
        return 413, "File too large"
    ext = ("." + fname.rsplit(".", 1)[1].lower()) if fname and "." in fname else ""
    key = f"demo-school/{folder}/{uuid.uuid4()}{ext}"
    meta = {"url": f"https://eldermin-files.s3.ap-south-1.amazonaws.com/{key}", "key": key,
            "fileName": fname or "", "fileSize": len(data), "fileType": ctype or "application/octet-stream"}
    _state["uploads"][key] = meta
    _state["last_upload"] = {"folder": folder, "fileType": meta["fileType"], "fileSize": meta["fileSize"]}
    return 201, {"success": True, "data": meta}


def signed_url(key, base):
    """GET /upload/signed-url?key= (UC:46-50 -> US:93-96) -> { url } (S3 presigned GET, expires 3600 s). No ownership/tenant
    check on the key. A missing key makes the SDK throw -> 500 (UNVERIFIED). Stub: URL points back at /__stub/files/."""
    if not key:
        return 500, "Internal server error"
    return 200, {"url": f"{base}/__stub/files/{key}?X-Amz-Expires=3600&X-Amz-Signature=DUMMY"}


# ============================== BEHAVIOUR ==============================

BEHAVIOUR_TYPES = ["positive", "negative", "neutral"]  # BSC:30-33
BEHAVIOUR_CATEGORIES = ["academic_excellence", "helping_others", "leadership", "good_conduct", "community_service",
                        "innovation", "sportsmanship", "attendance_excellence", "moral_courage", "misconduct", "bullying",
                        "cheating", "dishonesty", "disrespect", "property_damage", "late_coming", "uniform_violation",
                        "phone_misuse", "absenteeism", "fighting", "harassment", "vandalism", "counselling_referral",
                        "parent_meeting", "warning_issued", "behaviour_contract", "restorative_practice"]  # BSC:36-50
SEVERITIES = ["low", "medium", "high", "critical"]  # BSC:60-63
CONSEQUENCES = ["verbal_warning", "written_warning", "detention", "parent_notification", "suspension", "counselling",
                "behaviour_contract", "community_service", "commendation", "merit_award", "no_action"]  # BSC:72-77
TEACHER_USER = {"teacher": "64a000000000000000000001", "classteacher": "64a000000000000000000002"}


def _rec(student, typ, cat, title, desc, sev, pts, reporter, reporter_id, days_ago, resolved=False, note=None, grade=None,
         section=None, follow=False):
    _state["rec_counter"] += 1
    d = _today() - datetime.timedelta(days=days_ago)
    return {
        "_id": S._oid(0x700 + _state["rec_counter"]), "studentId": student["_id"],
        "studentName": f"{student['firstName']} {student['lastName']}".strip(),
        "grade": grade or student["currentGrade"], "campusId": S.CAMPUS_ID, "section": section or student["currentSection"],
        "rollNumber": student["currentRollNumber"], "date": _midnight(d), "type": typ, "category": cat, "title": title,
        "description": desc, "witnesses": [], "severity": sev, "points": pts, "followUpRequired": follow,
        "resolved": resolved, "resolvedNote": note, "resolvedDate": _midnight(d) if resolved else None,
        "parentNotified": False, "reportedBy": reporter, "reportedById": reporter_id, "verified": False,
        "attachments": [], "schoolSlug": "demo-school", "academicYear": S.ACADEMIC_YEAR,
        "createdAt": f"{d.isoformat()}T07:30:00.000Z", "updatedAt": f"{d.isoformat()}T07:30:00.000Z", "__v": 0,
    }


def seed_behaviour():
    """DUMMY behaviour records covering: mine / colleague's (name only, no reportedById: the web never sets it) / a student in
    another class (5B) the app must NEVER show / a '5'/'a' spelled student."""
    if _state["seeded_b"]:
        return
    _state["seeded_b"] = True
    s5a = [S.STUDENTS_BY_ID[S._oid(0x200 + i)] for i in range(8)]
    s5b = S.STUDENTS_BY_ID[S._oid(0x240)]
    s6b = S.STUDENTS_BY_ID[S._oid(0x260)]
    CT, T = TEACHER_USER["classteacher"], TEACHER_USER["teacher"]
    R = _state["records"]
    R.append(_rec(s5a[0], "positive", "helping_others", "Helped a classmate", "Explained fractions to a classmate (DUMMY)",
                  "low", 5, "Clara Classteacher", CT, 2))
    R.append(_rec(s5a[0], "negative", "late_coming", "Late to class", "Arrived 15 minutes late twice this week (DUMMY)",
                  "medium", -2, "Tess Teacher", T, 5))
    R.append(_rec(s5a[1], "negative", "misconduct", "Disrupted the lesson", "Repeatedly talked over the teacher (DUMMY)",
                  "high", -5, "Clara Classteacher", CT, 3, follow=True))
    R.append(_rec(s5a[2], "positive", "academic_excellence", "Top of the quiz", "Scored full marks (DUMMY)", "low", 5,
                  "Omar Colleague", None, 6, resolved=True, note="Certificate given (DUMMY)"))
    R.append(_rec(s5a[4], "neutral", "parent_meeting", "Met guardian", "Brief catch-up with guardian (DUMMY)", "low", 0,
                  "Tess Teacher", T, 9))
    R.append(_rec(s5a[3], "positive", "good_conduct", "Great manners", "Held the door for visitors (DUMMY)", "low", 3,
                  "Clara Classteacher", CT, 4, grade="5", section="a"))
    R.append(_rec(s5b, "negative", "phone_misuse", "Phone in class (OTHER CLASS)", "A Grade 5 B student: must not show (DUMMY)",
                  "medium", -3, "Omar Colleague", None, 2))
    R.append(_rec(s6b, "positive", "leadership", "Led the group task", "Organised the science group (DUMMY)", "low", 5,
                  "Tess Teacher", T, 7))
    _state["records"].sort(key=lambda r: r["date"], reverse=True)
    # Tarbiyah (BSC:147-190): one assessment for the first 5A student
    _state["tarbiyah"] = [{
        "_id": S._oid(0x900), "studentId": s5a[0]["_id"], "studentName": f"{s5a[0]['firstName']} {s5a[0]['lastName']}",
        "grade": "Grade 5", "campusId": S.CAMPUS_ID, "section": "A", "period": "Term 1 2026-27", "periodType": "termly",
        "assessmentDate": _midnight(_today() - datetime.timedelta(days=20)),
        "traits": [{"traitKey": "sidq", "score": 5, "observation": "Always honest (DUMMY)"},
                   {"traitKey": "adab", "score": 4}, {"traitKey": "sabr", "score": 3}],
        "overallScore": 4.0, "overallPercentage": 75.0, "overallRating": "good",
        "teacherObservations": "A kind and thoughtful student (DUMMY).", "areasOfStrength": ["Truthfulness"],
        "areasForImprovement": ["Patience"], "recommendedActions": "", "assessedBy": "Clara Classteacher",
        "assessedById": CT, "parentShared": False, "schoolSlug": "demo-school", "academicYear": S.ACADEMIC_YEAR,
        "createdAt": "2026-09-15T07:00:00.000Z", "updatedAt": "2026-09-15T07:00:00.000Z", "__v": 0}]


def _paged(q, rows):
    """BS:23 / BS:267-: `page`/`limit` arrive as STRINGS from the query (the controller takes @Query() q: any, no DTO), so
    meta.page/limit echo the strings; skip = (p-1)*l is coerced by JS. Defaults 1 / 20."""
    page_raw = (q.get("page") or [None])[0]
    limit_raw = (q.get("limit") or [None])[0]
    page = page_raw if page_raw is not None else 1
    limit = limit_raw if limit_raw is not None else 20
    try:
        p, l = int(page), int(limit)
    except ValueError:
        return 500, "Internal server error"
    if l < 1:
        return 500, "Internal server error"
    total = len(rows)
    return 200, {"data": rows[(p - 1) * l: p * l],
                 "meta": {"total": total, "page": page, "limit": limit, "pages": math.ceil(total / l)}}


def list_records(account, q):
    """GET /behaviour/records (BC:43-47 -> BS:170-207, verified). Query read straight from @Query() (NO DTO): type, category,
    severity, grade (EXACT string), studentId (ObjectId cast: invalid -> 500), resolved ('true' only is true; any other
    string is false), from/to (date), followUpOverdue, campusId (403 if not my campus, SCOPE:92-94), search (regex over
    studentName/title/description), page (def 1), limit (def 20), sorted date desc. NO section filter, NO reporter filter and
    NO class scoping: a teacher gets every record of the campus. Parents see ALL of a student's records (PPS:390-396)."""
    seed_behaviour()
    rows = list(_state["records"])

    def arg(k):
        v = q.get(k)
        return v[0] if v else None

    if arg("type"):
        rows = [r for r in rows if r["type"] == arg("type")]
    if arg("category"):
        rows = [r for r in rows if r["category"] == arg("category")]
    if arg("severity"):
        rows = [r for r in rows if r["severity"] == arg("severity")]
    if arg("grade"):
        rows = [r for r in rows if r["grade"] == arg("grade")]
    if arg("studentId"):
        if not _is_oid(arg("studentId")):
            return 500, "Internal server error"
        rows = [r for r in rows if r["studentId"] == arg("studentId")]
    if arg("resolved") is not None:
        rows = [r for r in rows if r["resolved"] == (arg("resolved") == "true")]
    if arg("campusId") and arg("campusId") != account["campus"]["id"]:
        return 403, "Access denied. You are scoped to your own campus only."
    if arg("from"):
        rows = [r for r in rows if r["date"][:10] >= arg("from")[:10]]
    if arg("to"):
        rows = [r for r in rows if r["date"][:10] <= arg("to")[:10]]
    if arg("search"):
        rx = re.compile(re.escape(arg("search")), re.I)
        rows = [r for r in rows if rx.search(r["studentName"]) or rx.search(r["title"]) or rx.search(r["description"])]
    rows.sort(key=lambda r: r["date"], reverse=True)
    return _paged(q, rows)


def create_record(account, body):
    """POST /behaviour/records (BC:55-65 -> BS:159-168, verified). Body is `any` (NO DTO, no whitelist): the controller adds
    schoolSlug (JWT), academicYear (body || JWT || x-academic-year || '2025-26') and reportedBy (body || JWT name ||
    'Admin'), then `new Model({...dto, studentId: ObjectId, date: new Date(date), campusId: JWT campus})`.save(). Mongoose
    required: studentId, studentName, grade, date, type (enum), category (enum), title, description, reportedBy, schoolSlug,
    academicYear (BSC:16-105). There is NO try/catch: a mongoose ValidationError / CastError is not an HttpException -> HTTP
    500 'Internal server error' (FLT:20-27,43-48), so the app must validate everything itself. reportedById is NOT set by the
    server (it only exists if the body carries it; the schema field is ObjectId). Returns the saved document, HTTP 201."""
    seed_behaviour()
    bad = None
    sid = body.get("studentId")
    if not _is_oid(sid):
        bad = "studentId"
    for k in ("studentName", "grade", "title", "description"):
        if not isinstance(body.get(k), str) or not body.get(k):
            bad = bad or k
    if body.get("type") not in BEHAVIOUR_TYPES:
        bad = bad or "type"
    if body.get("category") not in BEHAVIOUR_CATEGORIES:
        bad = bad or "category"
    if body.get("severity") is not None and body.get("severity") not in SEVERITIES:
        bad = bad or "severity"
    if body.get("consequence") is not None and body.get("consequence") not in CONSEQUENCES:
        bad = bad or "consequence"
    date = body.get("date")
    if not isinstance(date, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}([T ][\d:.]+(Z|[+-]\d{2}:?\d{2})?)?", date or ""):
        bad = bad or "date"
    if body.get("reportedById") is not None and not _is_oid(body.get("reportedById")):
        bad = bad or "reportedById"
    if bad:
        return 500, "Internal server error"
    _state["rec_counter"] += 1
    day = date[:10]
    doc = {
        "_id": S._oid(0x700 + _state["rec_counter"]), "studentId": sid, "studentName": body["studentName"], "grade": body["grade"],
        "campusId": account["campus"]["id"], "section": body.get("section"), "rollNumber": body.get("rollNumber"),
        "date": f"{day}T00:00:00.000Z", "type": body["type"], "category": body["category"], "title": body["title"],
        "description": body["description"], "witnesses": [], "severity": body.get("severity") or "medium",
        "points": body.get("points") if isinstance(body.get("points"), (int, float)) else 0,
        "consequence": body.get("consequence"),
        "followUpRequired": bool(body.get("followUpRequired", False)), "resolved": False,
        "parentNotified": bool(body.get("parentNotified", False)),
        "reportedBy": body.get("reportedBy") or account["name"] or "Admin", "verified": False, "attachments": [],
        "schoolSlug": "demo-school", "academicYear": body.get("academicYear") or "2025-26",
        "createdAt": _now_iso(), "updatedAt": _now_iso(), "__v": 0,
    }
    if body.get("reportedById"):
        doc["reportedById"] = body["reportedById"]
    _state["records"].insert(0, doc)
    _state["records"].sort(key=lambda r: r["date"], reverse=True)
    return 201, doc


def resolve_record(account, rid, body):
    """PATCH /behaviour/records/:id/resolve { note } (BC:74-82 -> BS:219-226). No role gate. findOneAndUpdate sets resolved,
    resolvedDate, resolvedNote, verifiedBy (name); returns the document, or null (empty 200 body) when the id is unknown."""
    seed_behaviour()
    r = next((x for x in _state["records"] if x["_id"] == rid), None)
    if not r:
        return 200, None
    r.update(resolved=True, resolvedDate=_now_iso(), resolvedNote=(body or {}).get("note"), verifiedBy=account["name"])
    return 200, r


def list_tarbiyah(account, q):
    """GET /behaviour/tarbiyah (BC:95-99 -> BS:319-334, verified): filters grade, studentId (ObjectId cast), period,
    periodType, campusId; page/limit like records (default 20); sorted assessmentDate desc; { data, meta }. Parents see ALL
    of a student's assessments (PPS:390-396), `parentShared` is not consulted."""
    seed_behaviour()
    rows = list(_state["tarbiyah"])

    def arg(k):
        v = q.get(k)
        return v[0] if v else None

    if arg("studentId"):
        if not _is_oid(arg("studentId")):
            return 500, "Internal server error"
        rows = [r for r in rows if r["studentId"] == arg("studentId")]
    if arg("grade"):
        rows = [r for r in rows if r["grade"] == arg("grade")]
    return _paged(q, rows)
