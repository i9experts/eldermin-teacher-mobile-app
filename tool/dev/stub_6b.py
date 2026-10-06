"""Phase 6b stub logic: assessments (list / one), marks entry (list / bulk), report-card remarks, quiz-attempt grading,
curriculum (list / one) and the library catalogue (books list).

!! DUMMY DATA ONLY. Lives under tool/dev/, never shipped. Imported by stub_server.py (HTTP routing, auth and the dev mode
!! switches live there). Every function returns (status, body) so tests can call it directly.

Citation legend (paths relative to eldermin-backend/src/, branch feat/staff-portal, HEAD da9fff6 "docs(staff-portal): record
lesson-plan self-approval fix"; read-only). "UNVERIFIED" = cannot be confirmed from code; all of them are in PHASE6B_REPORT.md.
  AC  = assessments/assessment.controller.ts   AS  = assessments/assessment.service.ts
  AD  = assessments/dto/assessment.dto.ts      ASC = assessments/schemas/assessment.schema.ts
  QA  = assessments/schemas/quiz-attempt.schema.ts
  ACC = modules/academics/academics.controller.ts   ACS = modules/academics/academics.service.ts
  CUR = modules/academics/schemas/curriculum.schema.ts   BK = modules/academics/schemas/book.schema.ts
  SCOPE = auth/scope.util.ts   FLT = filters/sentry.filter.ts   MAIN = main.ts (global ValidationPipe whitelist:true, transform:true)

/__stub/mode features (value: ok|empty|400|403|404|422|500|drop|slow, plus the special values below):
  assessments GET /assessments        assessone GET /assessments/:id        marks GET /assessments/marks/list
  marksbulk   POST /assessments/marks/bulk   special: partial500 (the first half is written, then 500: bulkWrite is ordered, AS:1296)
  reportcards GET /assessments/report-cards  remarks PATCH /assessments/report-cards/:id/remarks
  quizlist GET /assessments/quiz-attempts    quizone GET /assessments/quiz-attempts/:id   special: nopaper (404 'no quiz paper linked')
  quizgrade   POST /assessments/quiz-attempts/:id/grade
  curriculum GET /academics/curriculum       curone GET /academics/curriculum/:id     library GET /academics/library/books
  PLANNED-BACKEND error modes (UNVERIFIED: they reflect the backend hardening that is PLANNED for marks/bulk, quiz grading and remarks;
  no backend commit or docs/staff-portal entry has landed yet, so the exact status codes and message texts are ASSUMPTIONS; the real
  error SHAPE {statusCode,message,timestamp,path} is verified, FLT:43-48). Update the texts once the backend commit lands:
    marksbulk=toobig         400 'Marks exceed the total (T) for: ...' listing the offending rows (also when the app's own check passed,
                             e.g. the total was lowered after the sheet loaded)
    marksbulk=lockedrows     403 'N mark(s) are verified and locked: ...' (the first row of the request is flipped to verified)
    marksbulk=lockedrows409  the same with 409
    quizgrade=quizbounds     400 'marksAwarded for question <id> must not exceed <max> (and not be negative)'
    quizgrade=regrade        409 'This attempt has already been graded and can't be graded again.' (the attempt is flipped to graded)
    remarks=notclassteacher  403 'Only the class teacher of <grade> <section> can edit these remarks.'
    remarks=notfound         404 'Report card not found' (instead of today's 200 with an empty body)
  Extra feature `bigclass` (value `on`): Grade 5 A has 230 active students (two 200-row roster pages; the web would silently show 100).
  Extra feature `marks` special `allverified`: every returned mark row is verified (a fully locked sheet).
"""
import datetime
import re

S = None  # the stub_server module, injected by bind()


def bind(mod):
    global S
    S = mod


_state = {"seeded": False, "assessments": {}, "marks": {}, "cards": {}, "attempts": {}, "curricula": {}, "books": [],
          "last_bulk": None, "last_grade": None, "last_remarks": None, "bulk_calls": 0, "last_academic_year_header": None}


def reset():
    _state.update({"seeded": False, "assessments": {}, "marks": {}, "cards": {}, "attempts": {}, "curricula": {}, "books": [],
                   "last_bulk": None, "last_grade": None, "last_remarks": None, "bulk_calls": 0, "last_academic_year_header": None})


def state_summary():
    return {"assessments": len(_state["assessments"]), "marks": len(_state["marks"]), "reportCards": len(_state["cards"]),
            "attempts": len(_state["attempts"]), "bulkCalls": _state["bulk_calls"], "lastBulk": _state["last_bulk"],
            "lastBulkAcademicYearHeader": _state["last_academic_year_header"], "lastGrade": _state["last_grade"],
            "lastRemarks": _state["last_remarks"]}


def _is_oid(v):
    return isinstance(v, str) and re.fullmatch(r"[0-9a-fA-F]{24}", v) is not None


def _utc(d):
    return f"{d.isoformat()}T00:00:00.000Z"


def _now():
    return datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")


# AS:38-50 getGrade (default scale), AS:1248-1258 result rule
def _grade(pct):
    for g, lo, gpa in (("A+", 90, 4.0), ("A", 80, 3.7), ("B+", 70, 3.3), ("B", 60, 3.0), ("C", 50, 2.0), ("D", 40, 1.0)):
        if pct >= lo:
            return g, gpa
    return "F", 0.0


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


# ============================== ASSESSMENTS ==============================

def _subject(name, total, passing=None, *, paper=None, attempts=1):
    """SubjectConfig, ASC:13-30 (verified)."""
    d = {"subject": name, "totalMarks": total, "passingMarks": passing if passing is not None else total * 2 // 5,
         "examiner": "Exam Cell (DUMMY)", "date": _utc(S._today()), "startTime": "09:00", "duration": 60,
         "venue": "Hall 1", "examPaperId": paper, "attemptsAllowed": attempts}
    return d


def _assessment(n, title, typ, grade, section, status, subjects, *, days=0, term="Term 1", mode="teacher_marked", published=False,
                campus=None):
    """Assessment document, ASC:33-96 (verified). `section` null = all sections (ASC:46). `gradingScale`, `createdBy`,
    `schoolSlug` and `campusId` are in the real payload and are NOT parsed by the app."""
    d = S._today() + datetime.timedelta(days=days)
    doc = {"_id": S._oid(0xa00 + n), "title": title, "description": "", "type": typ, "grade": grade, "academicYear": S.ACADEMIC_YEAR,
           "term": term, "subjects": subjects, "startDate": _utc(d), "endDate": _utc(d + datetime.timedelta(days=1)), "status": status,
           "resultPublished": published, "gradeCardsGenerated": published, "deliveryMode": mode,
           "gradingScale": {"A+": {"min": 90, "gpa": 4.0}, "F": {"min": 0, "gpa": 0.0}}, "createdBy": "Admin (DUMMY)",
           "schoolSlug": "demo-school", "campusId": campus or S.CAMPUS_ID, "createdAt": "2026-09-20T05:00:00.000Z",
           "updatedAt": "2026-09-21T05:00:00.000Z", "__v": 0}
    if section is not None:
        doc["section"] = section
    if published:
        doc["resultPublishedAt"] = "2026-10-01T05:00:00.000Z"
        doc["resultPublishedBy"] = "Admin (DUMMY)"
    return doc


def _roster(grade_norm, section_norm):
    """Active students of a class as the stub's student list holds them (tolerant match, like the app)."""
    out = []
    for s in S.STUDENTS:
        if S._norm_grade(s["currentGrade"]) == grade_norm and S._norm_section(s["currentSection"]) == section_norm and s["status"] == "active":
            out.append(s)
    return out


def _mark(a, s, subject, obtained, *, absent=False, exempt=False, verified=False, remarks="", by="Tess Teacher"):
    """MarkEntry document, ASC:165-200 (verified)."""
    cfg = next(x for x in a["subjects"] if x["subject"] == subject)
    pct = grade = gpa = result = None
    if absent:
        result = "absent"
    elif exempt:
        result = "exempt"
    elif obtained is not None:
        pct = round(obtained / cfg["totalMarks"] * 100, 1)
        grade, gpa = _grade(pct)
        result = "pass" if pct >= cfg["passingMarks"] / cfg["totalMarks"] * 100 else "fail"
    doc = {"_id": S._oid(0xb00 + len(_state["marks"])), "assessmentId": a["_id"], "assessmentTitle": a["title"], "studentId": s["_id"],
           "studentName": f"{s['firstName']} {s['lastName']}", "rollNumber": s.get("currentRollNumber") or "", "grade": a["grade"],
           "section": s["currentSection"], "subject": subject, "totalMarks": cfg["totalMarks"], "passingMarks": cfg["passingMarks"],
           "obtainedMarks": obtained, "isAbsent": absent, "isExempt": exempt, "result": result, "remarks": remarks,
           "enteredBy": by, "verified": verified, "schoolSlug": "demo-school", "academicYear": S.ACADEMIC_YEAR,
           "createdAt": "2026-10-02T05:00:00.000Z", "updatedAt": "2026-10-02T05:00:00.000Z", "__v": 0}
    if pct is not None:
        doc.update({"percentage": pct, "grade_result": grade, "gpa": gpa})
    if verified:
        doc["verifiedBy"] = "Admin (DUMMY)"
    return doc


def seed():
    if _state["seeded"]:
        return
    _state["seeded"] = True
    A = _state["assessments"]
    paper = S._oid(0xe00)
    rows = [
        _assessment(1, "Unit Test 1 - Fractions (DUMMY)", "unit_test", "Grade 5", "A", "ongoing",
                    [_subject("Mathematics", 50, 20), _subject("English", 30, 12)], days=-1),
        _assessment(2, "Mid-Term Exam (DUMMY)", "mid_term", "Grade 5", None, "completed",
                    [_subject("Mathematics", 100, 40), _subject("Science", 100, 40), _subject("English", 100, 40)], days=-14),
        _assessment(3, "Class Test - Plants (DUMMY)", "class_test", "Grade 6", "B", "ongoing", [_subject("Science", 20, 8)], days=-2),
        _assessment(4, "Final Exam (DUMMY)", "final_exam", "Grade 5", "A", "scheduled", [_subject("Mathematics", 100, 40)], days=40,
                    term="Term 3"),
        _assessment(5, "Term 1 Result (DUMMY)", "mid_term", "Grade 5", "A", "result_published", [_subject("Mathematics", 100, 40)],
                    days=-30, published=True),
        _assessment(6, "Online Quiz - Fractions (DUMMY)", "quiz", "Grade 5", "A", "ongoing",
                    [_subject("Mathematics", 10, 4, paper=paper, attempts=2)], days=-3, mode="self_paced_online"),
        _assessment(7, "Grade 7 Unit Test (DUMMY)", "unit_test", "Grade 7", "A", "ongoing", [_subject("Mathematics", 40, 16)], days=-1),
        _assessment(8, "Draft - Spelling Bee (DUMMY)", "oral", "Grade 5", "A", "draft", [_subject("English", 20, 8)], days=20),
        _assessment(9, "Cancelled Quiz (DUMMY)", "quiz", "Grade 5", "A", "cancelled", [_subject("Mathematics", 10, 4)], days=-9),
        _assessment(10, "English Dictation (DUMMY)", "class_test", "Grade 5", "B", "ongoing", [_subject("English", 25, 10)], days=-1),
    ]
    for r in rows:
        A[r["_id"]] = r
    # marks. Roster of Grade 5 A (normalised, includes the two students stored as "5"/"a").
    ros = _roster("5", "a")
    a1, a2, a5 = rows[0], rows[1], rows[4]
    vals = [42, 38, 47, 50, 31, 25, 44, 18, 36, 40, 29, 33]
    for i, s in enumerate(ros[:12]):
        m = _mark(a1, s, "Mathematics", vals[i], remarks="Good effort (DUMMY)" if i == 2 else "")
        _state["marks"][(a1["_id"], s["_id"], "Mathematics")] = m
    s = ros[12]
    _state["marks"][(a1["_id"], s["_id"], "Mathematics")] = _mark(a1, s, "Mathematics", None, absent=True, remarks="Sick")
    # Mid-term Maths: first 10 verified (a PARTLY locked sheet), a few more entered but not verified
    mt = [88, 67, 91, 45, 72, 59, 80, 38, 95, 62, 70, 77]
    for i, s in enumerate(ros[:12]):
        _state["marks"][(a2["_id"], s["_id"], "Mathematics")] = _mark(a2, s, "Mathematics", mt[i], verified=i < 10, by="Admin (DUMMY)" if i < 10 else "Tess Teacher")
    for i, s in enumerate(ros):  # Term 1 result: every row verified
        _state["marks"][(a5["_id"], s["_id"], "Mathematics")] = _mark(a5, s, "Mathematics", 40 + (i * 7) % 55, verified=True, by="Admin (DUMMY)")
    # report cards of the mid-term: 12 Grade 5 A students + 3 Grade 5 B (another class: the class teacher of 5 A must not get them)
    ros_b = _roster("5", "b")
    for i, s in enumerate(ros[:12] + ros_b[:3]):
        _state["cards"][f"{a2['_id']}:{s['_id']}"] = _card(len(_state["cards"]), a2, s, i)
    a2["gradeCardsGenerated"] = True  # AS:1678-1681 sets it (with status 'completed') when report cards are generated
    for i, s in enumerate(ros[:5]):  # Term 1: published cards (read-only in the app)
        c = _card(len(_state["cards"]), a5, s, i)
        c["published"] = True
        c["publishedAt"] = "2026-10-01T05:00:00.000Z"
        _state["cards"][f"{a5['_id']}:{s['_id']}"] = c
    # quiz attempts (QA:28-60), the questions live in _questions()
    for n, (s, subj, status, grade, section, obtained, marks) in enumerate([
        (ros[0], "Mathematics", "submitted", "Grade 5", "A", None, [None, None]),
        (ros[1], "Mathematics", "submitted", "Grade 5", "A", None, [2, None]),  # partly graded already
        (ros[2], "Mathematics", "graded", "Grade 5", "A", 8, [3, 2]),
        (ros_b[0], "Mathematics", "submitted", "Grade 5", "B", None, [None, None]),  # another section: not mine
        (ros[3], "English", "submitted", "Grade 5", "A", None, [None, None]),  # not my subject
    ]):
        att = _attempt(n, rows[5], s, subj, status, grade, section, obtained, marks, paper)
        _state["attempts"][att["_id"]] = att
    _seed_curricula()
    _seed_books()


def extra_students(count=199):
    """`bigclass`: extra ACTIVE Grade 5 A students (roll numbers 32..) so the class has 230 active students (the roster is fetched in
    200-row pages; the web's limit=100 would silently drop 130). Same whole-document shape as the stub's own students."""
    out = []
    for i in range(count):
        d = S._student_doc({"grade": "Grade 5", "section": "A", "count": 400, "base": 0x400, "name0": 3}, i)
        d["currentRollNumber"] = str(32 + i)
        d["firstName"] = f"Extra{i + 1}"
        d["lastName"] = f"Student (DUMMY)"
        d["status"] = "active"
        d["currentGrade"], d["currentSection"] = "Grade 5", "A"
        out.append(d)
    return out


def _card(n, a, s, i):
    """ReportCard document, ASC:225-266 (verified)."""
    pct = [78.5, 66.0, 91.2, 44.0, 72.5, 59.9, 80.0, 38.5, 95.0, 62.0, 70.0, 77.0, 55.0, 61.0, 49.0][i % 15]
    g, gpa = _grade(pct)
    doc = {"_id": S._oid(0xc00 + n), "assessmentId": a["_id"], "assessmentTitle": a["title"], "assessmentType": a["type"],
           "studentId": s["_id"], "studentName": f"{s['firstName']} {s['lastName']}", "rollNumber": s.get("currentRollNumber") or "",
           "grade": a["grade"], "section": s["currentSection"], "academicYear": a["academicYear"], "term": a["term"],
           "subjects": [{"_id": S._oid(0xc80 + n * 3 + k), "subject": sub, "totalMarks": 100, "obtainedMarks": round(pct), "percentage": pct,
                         "grade": g, "gpa": gpa, "result": "pass" if pct >= 40 else "fail", "remarks": ""}
                        for k, sub in enumerate(["Mathematics", "Science", "English"])],
           "totalMaxMarks": 300, "totalObtainedMarks": round(pct * 3), "overallPercentage": pct, "overallGrade": g, "overallGPA": gpa,
           "overallResult": "pass" if pct >= 40 else "fail", "classPosition": i + 1, "totalStudents": 15,
           "published": False, "schoolSlug": "demo-school", "createdAt": "2026-10-03T05:00:00.000Z", "updatedAt": "2026-10-03T05:00:00.000Z",
           "__v": 0}
    if i == 1:
        doc["classTeacherRemarks"] = "Works steadily; revise tables (DUMMY)."
    if i == 2:
        doc["principalRemarks"] = "Excellent result (DUMMY)."
    return doc


# ---- questions / quiz attempts -------------------------------------------------------------------------------------

def _questions(paper):
    """Question documents hydrated into `answers[].question` (AS:1475-1484: the WHOLE question incl. the answer key: this
    is a teacher route). Fields QuestionSchema ASC:115-154 (verified)."""
    return {
        S._oid(0xe10): {"_id": S._oid(0xe10), "subject": "Mathematics", "grade": "Grade 5", "type": "mcq", "bloomsLevel": "understand",
                         "difficulty": "easy", "questionText": "What is 1/2 + 1/4?", "marks": 2, "tags": [], "usageCount": 3,
                         "options": [{"_id": S._oid(0xe11), "text": "3/4", "isCorrect": True}, {"_id": S._oid(0xe12), "text": "2/6", "isCorrect": False},
                                     {"_id": S._oid(0xe13), "text": "1/8", "isCorrect": False}], "schoolSlug": "demo-school"},
        S._oid(0xe20): {"_id": S._oid(0xe20), "subject": "Mathematics", "grade": "Grade 5", "type": "short", "difficulty": "medium",
                         "questionText": "Explain how you add two fractions with different denominators.", "marks": 4,
                         "correctAnswer": "Find a common denominator, convert, add numerators.", "answerExplanation": "Use the LCM (DUMMY).",
                         "options": [], "tags": [], "usageCount": 1, "schoolSlug": "demo-school"},
        S._oid(0xe30): {"_id": S._oid(0xe30), "subject": "Mathematics", "grade": "Grade 5", "type": "long", "difficulty": "hard",
                         "questionText": "A pizza is cut into 8 slices. Aisha eats 3 and Omar eats 2. What fraction is left? Show your working.",
                         "marks": 4, "correctAnswer": "3/8", "options": [], "tags": [], "usageCount": 1, "schoolSlug": "demo-school"},
    }


def _attempt(n, a, s, subject, status, grade, section, obtained, marks, paper):
    """QuizAttempt, QA:28-60 (verified). Three answers: one auto-graded mcq and two subjective ones (needsManualGrading)."""
    q = list(_questions(paper))
    ans = [
        {"questionId": q[0], "selectedOptionIndex": 0, "needsManualGrading": False, "isCorrect": True, "marksAwarded": 2},
        {"questionId": q[1], "textAnswer": "You make the bottoms the same, then add the tops (DUMMY answer).", "needsManualGrading": True,
         "isCorrect": None, "marksAwarded": marks[0]},
        {"questionId": q[2], "textAnswer": "8 - 5 = 3 so 3/8 are left (DUMMY answer).", "needsManualGrading": True, "isCorrect": None,
         "marksAwarded": marks[1]},
    ]
    doc = {"_id": S._oid(0xd00 + n), "studentId": s["_id"], "studentName": f"{s['firstName']} {s['lastName']}",
           "rollNumber": s.get("currentRollNumber") or "", "assessmentId": a["_id"], "assessmentTitle": a["title"], "subject": subject,
           "examPaperId": paper, "grade": grade, "section": section, "academicYear": S.ACADEMIC_YEAR, "totalMarks": 10, "passingMarks": 4,
           "answers": ans, "autoGradedMarks": 2, "obtainedMarks": obtained, "status": status, "attemptNumber": 1,
           "startedAt": "2026-10-03T08:00:00.000Z", "submittedAt": f"2026-10-0{3 + n % 3}T08:30:00.000Z", "schoolSlug": "demo-school",
           "createdAt": "2026-10-03T08:00:00.000Z", "updatedAt": "2026-10-03T08:30:00.000Z", "__v": 0}
    if status == "graded":
        doc["gradedAt"] = "2026-10-04T08:00:00.000Z"
        doc["gradedBy"] = "Tess Teacher"
    return doc


# ---- list / one ------------------------------------------------------------------------------------------------------

def _arg(q, k, d=None):
    v = q.get(k)
    return v[0] if v else d


def _paged(rows, q):
    """paged() AS:38 + PaginationDto AD:12-18: page default 1, limit default 20 (@Min(1), NO max), meta {total,page,limit,pages}."""
    try:
        page = int(_arg(q, "page", "1"))
        limit = int(_arg(q, "limit", "20"))
    except ValueError:
        return 400, "limit must be a number conforming to the specified constraints"
    if limit < 1:
        return 400, "limit must not be less than 1"
    total = len(rows)
    skip = (page - 1) * limit
    return 200, {"data": rows[skip:skip + limit], "meta": {"total": total, "page": page, "limit": limit, "pages": -(-total // limit)}}


def list_assessments(account, q):
    """GET /assessments (AC:54-58 -> AS:994-1021): filters grade, section, type, status, academicYear, term (exact), search (regex on
    title/description); sort `sortBy||startDate` desc by default; campus forced for a teacher (SCOPE:73-97). NO teacher / class /
    subject scoping."""
    seed()
    rows = [dict(a) for a in _state["assessments"].values() if a["campusId"] == S.CAMPUS_ID]
    for k in ("grade", "section", "type", "status", "academicYear", "term"):
        if _arg(q, k):
            rows = [a for a in rows if a.get(k) == _arg(q, k)]
    if _arg(q, "search"):
        rx = re.compile(re.escape(_arg(q, "search")), re.I)
        rows = [a for a in rows if rx.search(a["title"]) or rx.search(a.get("description", ""))]
    sort_by = _arg(q, "sortBy") or "startDate"
    rows.sort(key=lambda a: a.get(sort_by) or "", reverse=_arg(q, "sortOrder") != "asc")
    return _paged(rows, q)


def get_assessment(account, aid):
    """GET /assessments/:id (AC:195-199 -> AS:1023-1027): 404 'Assessment not found'; an invalid id is a CastError = 500."""
    seed()
    if not _is_oid(aid):
        return 500, "Internal server error"
    a = _state["assessments"].get(aid)
    return (200, dict(a)) if a else (404, "Assessment not found")


def list_marks(account, q, mode="ok"):
    """GET /assessments/marks/list (AC:78-82 -> AS:1301-1318): MarkQueryDto AD:180-187 (assessmentId/studentId MongoId else 400,
    grade, section, subject exact, verified bool), sort rollNumber ASC (a STRING sort: '10' < '2'), page/limit as above. NOT
    campus/class scoped (schoolSlug only)."""
    seed()
    for k in ("assessmentId", "studentId"):
        if _arg(q, k) and not _is_oid(_arg(q, k)):
            return 400, f"{k} must be a mongodb id"
    rows = [dict(m) for m in _state["marks"].values()]
    for k in ("assessmentId", "studentId", "grade", "section", "subject"):
        if _arg(q, k):
            rows = [m for m in rows if m.get(k) == _arg(q, k)]
    if _arg(q, "verified") is not None:
        rows = [m for m in rows if m["verified"] == (_arg(q, "verified") == "true")]
    rows.sort(key=lambda m: m["rollNumber"])
    if mode == "allverified":
        for m in rows:
            m["verified"] = True
    return _paged(rows, q)


BULK_FIELDS = {"studentId", "studentName", "rollNumber", "section", "obtainedMarks", "isAbsent", "isExempt", "remarks"}


def bulk_marks(account, body, mode="ok", academic_year_header=None):
    """POST /assessments/marks/bulk (AC:349-354, @RolesOrModuleManage STAFF_WRITE_ROLES incl. TEACHER; 201 -> AS:1239-1299).
    ValidationPipe (MAIN:69-75, whitelist) with BulkMarkEntryDto/SingleMarkDto AD:150-171: assessmentId MongoId, subject string, grade
    string, marks[] each studentId MongoId, studentName string, rollNumber string, section? string, obtainedMarks? number >= 0
    (null/undefined skip validation: @IsOptional), isAbsent?/isExempt? boolean, remarks? string. First failing message is returned
    (FLT:43-48). Then: 404 'Assessment not found', 400 'Subject X not in assessment'. The server does NOT check obtainedMarks <= totalMarks,
    NOR the `verified` flag (verified rows are overwritten and stay verified: `verified` is not in the $set), NOR that the student belongs
    to the class, NOR the assessment status. Per row: absent wins over exempt wins over a number (AS:1252-1269)."""
    seed()
    if not _is_oid(body.get("assessmentId")):
        return 400, "assessmentId must be a mongodb id"
    if not isinstance(body.get("subject"), str):
        return 400, "subject must be a string"
    if not isinstance(body.get("grade"), str):
        return 400, "grade must be a string"
    marks = body.get("marks")
    if not isinstance(marks, list):
        return 400, "marks must be an array"
    for i, m in enumerate(marks):
        if not isinstance(m, dict):
            return 400, f"marks.{i} must be an object"
        if not _is_oid(m.get("studentId")):
            return 400, f"marks.{i}.studentId must be a mongodb id"
        if not isinstance(m.get("studentName"), str):
            return 400, f"marks.{i}.studentName must be a string"
        if not isinstance(m.get("rollNumber"), str):
            return 400, f"marks.{i}.rollNumber must be a string"
        if m.get("section") is not None and not isinstance(m.get("section"), str):
            return 400, f"marks.{i}.section must be a string"
        o = m.get("obtainedMarks")
        if o is not None:
            if not _num(o):
                return 400, f"marks.{i}.obtainedMarks must be a number conforming to the specified constraints"
            if o < 0:
                return 400, f"marks.{i}.obtainedMarks must not be less than 0"
        for k in ("isAbsent", "isExempt"):
            if m.get(k) is not None and not isinstance(m.get(k), bool):
                return 400, f"marks.{i}.{k} must be a boolean value"
        if m.get("remarks") is not None and not isinstance(m.get("remarks"), str):
            return 400, f"marks.{i}.remarks must be a string"
    a = _state["assessments"].get(body["assessmentId"])
    if not a:
        return 404, "Assessment not found"
    cfg = next((x for x in a["subjects"] if x["subject"] == body["subject"]), None)
    if not cfg:
        return 400, f"Subject {body['subject']} not in assessment"
    if mode == "toobig":  # PLANNED backend behaviour, UNVERIFIED (see the module docstring)
        names = ", ".join(f"{m['studentName']} (roll {m['rollNumber']})" for m in marks[:3])
        return 400, f"Marks exceed the total ({cfg['totalMarks']:g}) for: {names}"
    if mode in ("lockedrows", "lockedrows409") and marks:  # PLANNED backend behaviour, UNVERIFIED
        first = marks[0]
        key = (body["assessmentId"], first["studentId"], body["subject"])
        old = _state["marks"].get(key)
        if old is None:
            old = _mark(a, {"_id": first["studentId"], "firstName": first["studentName"], "lastName": "", "currentSection": first.get("section") or "",
                            "currentRollNumber": first["rollNumber"]}, body["subject"], 10)
        old["verified"] = True
        old["verifiedBy"] = "Admin (DUMMY)"
        _state["marks"][key] = old
        return (409 if mode == "lockedrows409" else 403), f"1 mark is verified and locked and cannot be changed: {first['studentName']} (roll {first['rollNumber']})"
    _state["bulk_calls"] += 1
    _state["last_academic_year_header"] = academic_year_header
    _state["last_bulk"] = {"size": len(marks), "assessmentId": body["assessmentId"], "subject": body["subject"], "grade": body["grade"],
                           "keys": sorted({k for m in marks for k in m if k in BULK_FIELDS}),
                           "sawOverTotal": any(_num(m.get("obtainedMarks")) and m["obtainedMarks"] > cfg["totalMarks"] for m in marks)}
    limit = len(marks) // 2 if mode == "partial500" else len(marks)
    for m in marks[:limit]:
        key = (body["assessmentId"], m["studentId"], body["subject"])
        old = _state["marks"].get(key)
        doc = dict(old) if old else _mark(a, {"_id": m["studentId"], "firstName": "", "lastName": "", "currentSection": m.get("section") or "",
                                              "currentRollNumber": m["rollNumber"]}, body["subject"], None)
        absent, exempt, obtained = bool(m.get("isAbsent")), bool(m.get("isExempt")), m.get("obtainedMarks")
        pct = grade = gpa = result = None
        if absent:
            result = "absent"
        elif exempt:
            result = "exempt"
        elif obtained is not None:
            pct = round(obtained / cfg["totalMarks"] * 100, 1)
            grade, gpa = _grade(pct)
            result = "pass" if pct >= cfg["passingMarks"] / cfg["totalMarks"] * 100 else "fail"
        doc.update({"assessmentTitle": a["title"], "studentName": m["studentName"], "rollNumber": m["rollNumber"], "grade": body["grade"],
                    "section": m.get("section"), "totalMarks": cfg["totalMarks"], "passingMarks": cfg["passingMarks"],
                    "obtainedMarks": obtained, "isAbsent": absent, "isExempt": exempt, "result": result, "remarks": m.get("remarks"),
                    "enteredBy": account["name"], "academicYear": academic_year_header or S.ACADEMIC_YEAR, "updatedAt": _now()})
        # mongoose strips `undefined` from $set: a previous percentage/grade/gpa SURVIVES when the new row has none (AS:1269-1291,
        # UNVERIFIED how bulkWrite treats undefined; the stub keeps the old values, the pessimistic reading)
        for k, v in (("percentage", pct), ("grade_result", grade), ("gpa", gpa)):
            if v is not None:
                doc[k] = v
        _state["marks"][key] = doc  # `verified` / `verifiedBy` are NOT in the $set: untouched
    if mode == "partial500":
        return 500, "Internal server error"
    return 201, {"message": f"Marks entered for {len(marks)} students", "subject": body["subject"]}


def list_report_cards(account, q):
    """GET /assessments/report-cards (AC:96-100 -> AS:1695-1711): ReportCardQueryDto AD:207-213: assessmentId/studentId MongoId,
    grade (exact), academicYear, published bool, page/limit; sort classPosition. Campus: schoolSlug only."""
    seed()
    for k in ("assessmentId", "studentId"):
        if _arg(q, k) and not _is_oid(_arg(q, k)):
            return 400, f"{k} must be a mongodb id"
    rows = [dict(c) for c in _state["cards"].values()]
    for k in ("assessmentId", "studentId", "grade", "academicYear"):
        if _arg(q, k):
            rows = [c for c in rows if c.get(k) == _arg(q, k)]
    if _arg(q, "published") is not None:
        rows = [c for c in rows if c["published"] == (_arg(q, "published") == "true")]
    rows.sort(key=lambda c: c["classPosition"])
    return _paged(rows, q)


def update_remarks(account, cid, body, mode="ok"):
    """PATCH /assessments/report-cards/:id/remarks (AC:118-127, @RolesOrModuleManage incl. TEACHER -> AS:1723-1727): body
    UpdateReportCardRemarksDto AD:196-199 (classTeacherRemarks?, principalRemarks?: strings; whitelist drops anything else) then a
    raw findOneAndUpdate {$set: dto}: an UNKNOWN id answers 200 with an EMPTY body (null), an invalid id a CastError (500). No
    class-teacher / published check: a teacher can also write principalRemarks and edit a published card."""
    seed()
    if mode == "notclassteacher":  # PLANNED backend behaviour, UNVERIFIED (see the module docstring)
        return 403, "Only the class teacher of this class can edit these remarks."
    if mode == "notfound":  # PLANNED backend behaviour, UNVERIFIED
        return 404, "Report card not found"
    for k in ("classTeacherRemarks", "principalRemarks"):
        if body.get(k) is not None and not isinstance(body.get(k), str):
            return 400, f"{k} must be a string"
    if not _is_oid(cid):
        return 500, "Internal server error"
    card = next((c for c in _state["cards"].values() if c["_id"] == cid), None)
    if not card:
        return 200, None
    patch = {k: body[k] for k in ("classTeacherRemarks", "principalRemarks") if k in body}
    card.update(patch)
    card["updatedAt"] = _now()
    _state["last_remarks"] = {"id": cid, "keys": sorted(patch)}
    return 200, dict(card)


# ---- quiz attempts ----------------------------------------------------------------------------------------------------

def list_attempts(account, q):
    """GET /assessments/quiz-attempts (AC:165-169 -> AS:1468-1473): optional assessmentId (cast to ObjectId: invalid = 500), subject;
    ALWAYS status 'submitted' (pending review); sort submittedAt asc; bare array of lean documents (answers included, WITHOUT the
    hydrated question); no pagination, no campus/class scoping (schoolSlug only)."""
    seed()
    aid = _arg(q, "assessmentId")
    if aid and not _is_oid(aid):
        return 500, "Internal server error"
    rows = [dict(a) for a in _state["attempts"].values() if a["status"] == "submitted"]
    if aid:
        rows = [a for a in rows if a["assessmentId"] == aid]
    if _arg(q, "subject"):
        rows = [a for a in rows if a["subject"] == _arg(q, "subject")]
    rows.sort(key=lambda a: a["submittedAt"])
    return 200, rows


def get_attempt(account, aid, mode="ok"):
    """GET /assessments/quiz-attempts/:attemptId (AC:171-175 -> AS:1475-1484): the attempt with `answers[].question` hydrated from the
    linked exam paper (the WHOLE question incl. options[].isCorrect and correctAnswer). 404 'Quiz attempt not found'; 404 'This
    subject has no quiz paper linked ...' when the paper is gone (AS:1355-1358)."""
    seed()
    if not _is_oid(aid):
        return 500, "Internal server error"
    att = _state["attempts"].get(aid)
    if not att:
        return 404, "Quiz attempt not found"
    if mode == "nopaper":
        return 404, "This subject has no quiz paper linked - ask your teacher to link one in Paper Generation."
    qs = _questions(att["examPaperId"])
    d = dict(att)
    d["answers"] = [{**a, "question": qs.get(a["questionId"])} for a in att["answers"]]
    return 200, d


def grade_attempt(account, aid, body, mode="ok"):
    """POST /assessments/quiz-attempts/:attemptId/grade (AC:177-182, 200 -> AS:1490-1516). GradeQuizAttemptDto AD:85-94:
    grades[] of {questionId MongoId, marksAwarded number}. NO bound check (negative or above the question's marks are saved).
    400 'This attempt has not been submitted yet.' for in_progress. Only answers with needsManualGrading are touched; when none is
    still null the attempt becomes 'graded' (obtainedMarks = sum of marksAwarded, gradedBy = name) and a MarkEntry is UPSERTED for the
    student/subject (AS:1523-1544): enteredBy 'Online Quiz (auto)', isAbsent/isExempt false, overwriting ANY existing mark (verified or
    not; `verified` untouched). A re-grade of an already graded attempt is accepted too."""
    seed()
    grades = body.get("grades")
    if not isinstance(grades, list):
        return 400, "grades must be an array"
    for i, g in enumerate(grades):
        if not isinstance(g, dict) or not _is_oid(g.get("questionId")):
            return 400, f"grades.{i}.questionId must be a mongodb id"
        if not _num(g.get("marksAwarded")):
            return 400, f"grades.{i}.marksAwarded must be a number conforming to the specified constraints"
    if not _is_oid(aid):
        return 500, "Internal server error"
    att = _state["attempts"].get(aid)
    if not att:
        return 404, "Quiz attempt not found"
    if att["status"] == "in_progress":
        return 400, "This attempt has not been submitted yet."
    if mode == "quizbounds":  # PLANNED backend behaviour, UNVERIFIED (see the module docstring)
        qs = _questions(att["examPaperId"])
        for g in grades:
            q = qs.get(g["questionId"])
            if q and (g["marksAwarded"] < 0 or g["marksAwarded"] > q["marks"]):
                return 400, f"marksAwarded for question {g['questionId']} must be between 0 and {q['marks']:g}"
        return 400, "marksAwarded is out of bounds for at least one question"
    if mode == "regrade":  # PLANNED backend behaviour, UNVERIFIED
        att["status"] = "graded"
        for a in att["answers"]:
            if a["needsManualGrading"] and a["marksAwarded"] is None:
                a["marksAwarded"] = 1
        att["obtainedMarks"] = sum((a["marksAwarded"] or 0) for a in att["answers"])
        return 409, "This attempt has already been graded and cannot be graded again."
    by_q = {g["questionId"]: g["marksAwarded"] for g in grades}
    _state["last_grade"] = {"attemptId": aid, "grades": [{"questionId": k, "marksAwarded": v} for k, v in by_q.items()]}
    for a in att["answers"]:
        if a["needsManualGrading"] and by_q.get(a["questionId"]) is not None:
            a["marksAwarded"] = by_q[a["questionId"]]
            a["isCorrect"] = None
    pending = any(a["needsManualGrading"] and a["marksAwarded"] is None for a in att["answers"])
    if not pending:
        att["obtainedMarks"] = sum((a["marksAwarded"] or 0) for a in att["answers"])
        att["status"] = "graded"
        att["gradedAt"] = _now()
        att["gradedBy"] = account["name"]
        a = _state["assessments"][att["assessmentId"]]
        s = S.STUDENTS_BY_ID.get(att["studentId"], {"_id": att["studentId"], "firstName": att["studentName"], "lastName": "", "currentSection": att["section"], "currentRollNumber": att["rollNumber"]})
        pct = round(att["obtainedMarks"] / att["totalMarks"] * 100, 1) if att["totalMarks"] > 0 else 0
        g, gpa = _grade(pct)
        key = (att["assessmentId"], att["studentId"], att["subject"])
        doc = _state["marks"].get(key) or _mark(a, s, att["subject"], None)
        doc.update({"obtainedMarks": att["obtainedMarks"], "isAbsent": False, "isExempt": False, "percentage": pct, "grade_result": g,
                    "gpa": gpa, "result": "pass" if pct >= att["passingMarks"] / (att["totalMarks"] or 1) * 100 else "fail",
                    "enteredBy": "Online Quiz (auto)"})
        _state["marks"][key] = doc
    att["updatedAt"] = _now()
    return 200, dict(att)


# ============================== CURRICULUM ==============================

def _slo(code, desc, strand, blooms, assessed=True, atype="written"):
    return {"sloCode": code, "description": desc, "bloomsLevel": blooms, "strand": strand, "isAssessed": assessed, "assessmentType": atype}


def _curriculum(n, name, grade, subject, slos, *, status="active", framework="national", year="2026-27"):
    """Curriculum document, CUR:6-43 (verified). tenantId/institutionId/createdBy/approvedBy are real fields, NOT parsed."""
    return {"_id": S._oid(0xf00 + n), "tenantId": S._oid(0xa1), "institutionId": S._oid(0xa2), "name": name, "framework": framework,
            "gradeLevel": grade, "subjectId": S._oid(0xf80 + n), "subjectName": subject, "academicYearId": S._oid(0xf90),
            "academicYearLabel": year, "slos": slos,
            "standardsMapping": [{"standard": "Pakistan SNC 2020", "code": f"M-{grade[-1]}-01", "description": "Number and operations (DUMMY)"}],
            "status": status, "createdBy": S._oid(0xc9), "approvedBy": "Admin (DUMMY)", "approvedAt": "2026-08-01T05:00:00.000Z",
            "createdAt": "2026-07-01T05:00:00.000Z", "updatedAt": "2026-08-01T05:00:00.000Z", "__v": 0}


def _seed_curricula():
    rows = [
        _curriculum(1, "Mathematics Grade 5 (SNC)", "Grade 5", "Mathematics", [
            _slo("M5-N-01", "Add and subtract fractions with unlike denominators", "Number", "apply"),
            _slo("M5-N-02", "Read, write and round decimals to two places", "Number", "understand"),
            _slo("M5-M-01", "Calculate perimeter and area of rectangles", "Measurement", "apply"),
            _slo("M5-M-02", "Solve word problems involving time and money", "Measurement", "analyze", False, ""),
        ]),
        _curriculum(2, "Science Grade 6 (SNC)", "Grade 6", "Science", [
            _slo("S6-L-01", "Describe photosynthesis and its inputs and outputs", "Living things", "understand"),
            _slo("S6-L-02", "Compare plant and animal cells", "Living things", "analyze"),
        ]),
        _curriculum(3, "English Grade 5 (SNC)", "Grade 5", "English", [_slo("E5-R-01", "Read a short text and summarise it", "Reading", "understand")]),
        _curriculum(4, "Mathematics Grade 7 (SNC)", "Grade 7", "Mathematics", [_slo("M7-A-01", "Solve one-step equations", "Algebra", "apply")]),
        _curriculum(5, "Mathematics Grade 5 (draft revision)", "Grade 5", "Mathematics", [_slo("M5-X-01", "Draft SLO (DUMMY)", "Number", "apply")], status="draft"),
        _curriculum(6, "Mathematics Grade 5 (2024 edition)", "Grade 5", "Mathematics", [], status="archived", year="2024-25"),
    ]
    for r in rows:
        _state["curricula"][r["_id"]] = r


def list_curricula(account, q):
    """GET /academics/curriculum (ACC:111-114 -> ACS:375-383, verified): filters gradeLevel, status, framework, academicYearLabel,
    subjectId (ObjectId cast: invalid = 500), tenant-wide (NO campus, NO teacher scoping, drafts included unless status is passed);
    sort gradeLevel, subjectName; bare array (lean)."""
    seed()
    if _arg(q, "subjectId") and not _is_oid(_arg(q, "subjectId")):
        return 500, "Internal server error"
    rows = [dict(c) for c in _state["curricula"].values()]
    for k in ("gradeLevel", "status", "framework", "academicYearLabel", "subjectId"):
        if _arg(q, k):
            rows = [c for c in rows if c.get(k) == _arg(q, k)]
    rows.sort(key=lambda c: (c["gradeLevel"], c["subjectName"]))
    return 200, rows


def get_curriculum(account, cid):
    """GET /academics/curriculum/:id (ACC:123-126 -> ACS:386-390): 404 'Curriculum not found'; invalid id = 500."""
    seed()
    if not _is_oid(cid):
        return 500, "Internal server error"
    c = _state["curricula"].get(cid)
    return (200, dict(c)) if c else (404, "Curriculum not found")


# ============================== LIBRARY ==============================

CATEGORIES = ["fiction", "non_fiction", "textbook", "reference", "periodical", "islamic", "science", "biography", "children", "other"]


def _book(n, title, author, category, total, avail, **more):
    """Book document, BK:24-70 (verified). purchasePrice, purchaseDate, tenantId, institutionId, copies[] (barcodes), issue
    counters are real fields and are NOT parsed by the app."""
    d = {"_id": S._oid(0x1000 + n), "tenantId": S._oid(0xa1), "institutionId": S._oid(0xa2), "campusId": S.CAMPUS_ID,
         "accessionNo": f"ACC-2026-{n:05d}", "title": title, "author": author, "isbn": f"978000000{n:04d}", "publisher": "Dummy Press",
         "publishYear": 2015 + n % 10, "edition": "2nd", "callNumber": f"{500 + n}.{n % 9}", "category": category, "subjects": ["Science"] if category == "science" else [],
         "gradeLevels": ["Grade 5", "Grade 6"] if category in ("science", "textbook") else [], "language": "English", "location": "Main library",
         "shelfNo": f"S-{n % 12}", "copies": [{"accessionNo": f"ACC-2026-{n:05d}", "barcode": f"BC{n:05d}", "status": "available", "condition": "good"}],
         "totalCopies": total, "availableCopies": avail, "issuedCopies": total - avail, "damagedCopies": 0, "lostCopies": 0, "reservedCopies": 0,
         "purchasePrice": 1450, "purchaseDate": "2024-04-02T00:00:00.000Z",
         "status": "available" if avail > 0 else "fully_issued", "coverImageUrl": "", "description": "A DUMMY catalogue entry.",
         "totalIssues": 12, "rating": 4, "createdAt": "2025-01-01T05:00:00.000Z", "updatedAt": "2026-01-01T05:00:00.000Z", "__v": 0}
    d.update(more)
    return d


def _seed_books():
    titles = [
        ("The Water Cycle Explained", "Maria Lopez", "science", 4, 3), ("Fractions Made Easy", "Imran Khan", "textbook", 6, 6),
        ("Stories of the Prophets", "Dr Aisha Noor", "islamic", 3, 0), ("The Life of Marie Curie", "Anna Brooks", "biography", 2, 1),
        ("Oxford Junior Dictionary", "Oxford", "reference", 5, 5), ("The Little Prince", "Antoine de Saint-Exupery", "fiction", 3, 2),
        ("Space Atlas for Kids", "Neil Sky", "science", 2, 0), ("Grade 5 Mathematics Textbook", "National Book Foundation", "textbook", 40, 22),
        ("Grade 6 Science Textbook", "National Book Foundation", "textbook", 35, 30), ("Urdu Poems for Children", "Faiz Ahmed", "children", 4, 4),
        ("Learning to Code", "Sam Patel", "non_fiction", 2, 2), ("National Geographic Kids (Oct)", "NatGeo", "periodical", 1, 1),
        ("The Great Pyramid Mystery", "Hassan Ali", "non_fiction", 2, 1), ("Plants Around Us", "Maria Lopez", "science", 3, 3),
        ("Fractions and Decimals Workbook", "Imran Khan", "textbook", 10, 8), ("Tales from the Orchard", "Layla Rahman", "children", 3, 1),
        ("Atlas of the World", "Oxford", "reference", 2, 2), ("Ibn Sina: The Physician", "Dr Aisha Noor", "biography", 2, 2),
        ("Mystery at Midnight", "Rob Hunt", "fiction", 4, 4), ("Friendly Robots", "Sam Patel", "children", 2, 0),
        ("Chemistry Experiments at Home", "Dr Omar Sheikh", "science", 3, 2), ("History of the Subcontinent", "Ayesha Qazi", "non_fiction", 3, 3),
        ("Deaccessioned Old Atlas", "Oxford", "reference", 1, 0),
    ]
    for i, (t, a, c, total, avail) in enumerate(titles, 1):
        b = _book(i, t, a, c, total, avail)
        if t.startswith("Deaccessioned"):
            b["status"] = "deaccessioned"
        _state["books"].append(b)


def list_books(account, q):
    """GET /academics/library/books (ACC:165-168 -> ACS:497-518, verified): page (def 1) limit (def 20, NO max), category, status,
    `available=true` (availableCopies > 0), `search` (a MongoDB $text search: WORD matching, not substring), deaccessioned excluded unless
    a status or includeInactive=true is passed; campus forced for a teacher (SCOPE); sort title ASC; lean docs (copies as stored, NO
    borrower data: that is only in GET .../books/:id which also writes (ensureCopies) and returns issue history: not used)."""
    seed()
    rows = [dict(b) for b in _state["books"]]
    if _arg(q, "category"):
        rows = [b for b in rows if b["category"] == _arg(q, "category")]
    if _arg(q, "status"):
        rows = [b for b in rows if b["status"] == _arg(q, "status")]
    elif _arg(q, "includeInactive") != "true":
        rows = [b for b in rows if b["status"] != "deaccessioned"]
    if _arg(q, "available") == "true":
        rows = [b for b in rows if b["availableCopies"] > 0]
    if _arg(q, "search"):
        words = [w.lower() for w in re.split(r"\W+", _arg(q, "search")) if w]
        def hit(b):
            hay = set(re.split(r"\W+", f"{b['title']} {b['author']} {b['isbn']}".lower()))
            return any(w in hay for w in words)  # $text: OR of the (unstemmed here) words
        rows = [b for b in rows if hit(b)]
    rows.sort(key=lambda b: b["title"])
    return _paged(rows, q)
