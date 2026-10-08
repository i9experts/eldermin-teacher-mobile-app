"""Phase 7b stub logic: parent-teacher meetings (PTM), substitutions ("fixtures", teacher view) and My Leave (staff self-service).

!! DUMMY DATA ONLY. Lives under tool/dev/, never shipped. Imported by stub_server.py (HTTP routing, auth and the dev mode switches live
!! there). Every function returns (status, body) so tests can call it directly. NOT run against staging/production/MongoDB.

Citation legend (paths relative to eldermin-backend/src/, branch feat/staff-portal, HEAD 265fcfa; read-only). "UNVERIFIED" = cannot be
confirmed from code; every one of them is in PHASE7B_REPORT.md.
  PC  = modules/teaching/ptm.controller.ts            PS  = modules/teaching/ptm.service.ts           PSC = modules/teaching/schemas/ptm-meeting.schema.ts
  SC  = modules/teaching/substitution.controller.ts   SS  = modules/teaching/substitution.service.ts  SSC = modules/teaching/schemas/substitution.schema.ts
  HC  = modules/hr/hr.controller.ts                   HS  = modules/hr/hr.service.ts                  LA  = modules/hr/schemas/leave-application.schema.ts
  LB  = modules/hr/schemas/leave-balance.schema.ts    LD  = modules/hr/leave-days.util.ts            LS  = modules/hr/leave-self.util.ts
  TI  = staff-portal/teacher-identity.util.ts         TP  = students/teacher-student-projection.util.ts  OID = common/utils/object-id.util.ts
  FLT = filters/sentry.filter.ts (error body {statusCode,message,timestamp,path}; an array message is cut to its first element)

/__stub/mode features (value: ok|empty|400|403|404|409|422|500|drop|slow, plus the special values below):
  ptmlist GET /teaching/ptm       ptm GET /teaching/ptm/upcoming/mine    ptmone GET /teaching/ptm/:id       ptmhistory GET .../student/:id/history
  ptmcreate POST /teaching/ptm    ptmconfirm PATCH :id/confirm           ptmreschedule PATCH :id/reschedule  ptmoutcome PATCH :id/outcome
  ptmitem PATCH :id/action-items/:aid                                     ptmcancel PATCH :id/cancel
  fixtures GET /teaching/fixtures                                         fxcomplete PATCH /teaching/fixtures/:id/complete
  leavebalance GET /hr/leave/self/balance   leavehistory GET /hr/leave/self/history   leaveapply POST /hr/leave/self
  special values (each message is copied from the backend code at the cited line):
    ptmcreate=notmine       403 'You can only create meetings for yourself' (PS:71-73 + TI:67-70)
    ptmcreate=nostudent     404 'Student not found' (PS:78)
    ptmconfirm=notrequested 404 'Meeting not found or not in a requested state' (PS:161); the meeting is flipped to confirmed (as if confirmed elsewhere)
    ptmreschedule=notmine   403 'You can only modify your own meetings' (PS:37, TI:92)
    ptmreschedule=closed    404 'Meeting not found or already completed/cancelled' (PS:174); the meeting is flipped to completed
    ptmoutcome=notmine      403 'You can only modify your own meetings'
    ptmoutcome=cancelled    400 'Cannot record an outcome for a cancelled meeting' (PS:186); the meeting is flipped to cancelled
    ptmitem=notfound        404 'Action item not found' (PS:205)
    ptmone=notfound         404 'Meeting not found' (PS:142)
    fxcomplete=notassigned  404 'Fixture not found or not in an assigned state' (SS:228); the fixture is flipped to completed
    leavebalance=nostaff    404 'No staff record is linked to your account. Contact HR to have your login connected to your employee record.' (HS:1426)
    leaveapply=invalid      400 'LeaveApplication validation failed: reason: Path `reason` is required.' (Mongoose text; the HTTP status is UNVERIFIED:
                            the service has no DTO, an unhandled ValidationError is a 500 unless a filter maps it)
  Dev controls (not part of the real API): POST /__stub/leave-decide?id=<leave>&status=approved|rejected|cancelled&note=&by=  (an HR decision, as hr.service.ts:1290-1330 would do it),
  POST /__stub/fixture-set?id=<fixture>&status=...  (an admin action: assign/cancel).
"""
import datetime
import re

S = None  # the stub_server module, injected by bind()


def bind(mod):
    global S
    S = mod


_state = {"seeded": False, "ptm": {}, "fx": {}, "leave": {}, "seq": 0, "calls": [], "last_create": None, "last_apply": None}


def reset():
    _state.update({"seeded": False, "ptm": {}, "fx": {}, "leave": {}, "seq": 0, "calls": [], "last_create": None, "last_apply": None})


def state_summary():
    return {"meetings": len(_state["ptm"]), "fixtures": len(_state["fx"]), "leaveRequests": len(_state["leave"]),
            "lastPtmCreate": _state["last_create"], "lastLeaveApply": _state["last_apply"], "calls": list(_state["calls"][-20:])}


def _today():
    return datetime.date.today()


def _iso(d):
    return d.strftime("%Y-%m-%dT%H:%M:%S.") + f"{d.microsecond // 1000:03d}Z"


def _now_iso():
    return _iso(datetime.datetime.utcnow())


def _midnight(d):
    return f"{d.isoformat()}T00:00:00.000Z"


def _oid(n):
    return f"64d{n:021x}"


def _is_oid(v):
    return isinstance(v, str) and re.fullmatch(r"[0-9a-fA-F]{24}", v) is not None


def _next(base):
    _state["seq"] += 1
    return _oid(base + _state["seq"])


def _parse_date(v):
    """new Date(v) for the ISO forms the app sends; None = Invalid Date."""
    if not isinstance(v, str) or not v:
        return None
    try:
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", v):
            return datetime.datetime.fromisoformat(v)  # date-only strings are UTC midnight in JS
        return datetime.datetime.fromisoformat(v.replace("Z", "+00:00")).astimezone(datetime.timezone.utc).replace(tzinfo=None)
    except Exception:
        return None


def _is_teacher(a):
    return a["role"] == "teacher"


def project_for_teacher(doc):
    """TP:59-70 deny-list for the TEACHER role: any key containing phone|email|... is removed at any depth (the stored meeting carries
    guardianPhone / guardianEmail, PSC:44-45, exactly like the real collection; the teacher never receives them)."""
    deny = re.compile(r"phone|mobile|whatsapp|landline|telephone|cnic|nationalid|bform|passport|visa|email|address|street|postal|zipcode|geo|latitude|longitude|mailing|hostel|pickup|dropoff|driver|vehicle")
    if isinstance(doc, list):
        return [project_for_teacher(x) for x in doc]
    if isinstance(doc, dict):
        return {k: project_for_teacher(v) for k, v in doc.items() if not deny.search(k.lower())}
    return doc


# ================================== PTM ==================================

def _student_by(grade, section, n):
    pool = [s for s in S.STUDENTS if s["status"] == "active" and s["currentGrade"] == grade and s["currentSection"] == section]
    return pool[n % len(pool)]


def _meeting(n, staff, student, day, status, start, end, points=(), **kw):
    """One PTMMeeting document, fields PSC:26-70 (verified). Stored with guardianPhone/guardianEmail like the real collection."""
    g = (student["guardians"] or [{}])[0]
    m = {
        "_id": _oid(0x1000 + n), "tenantId": _oid(0xa1), "institutionId": _oid(0xa2), "campusId": student.get("campusId"),
        "studentId": student["_id"], "studentName": f"{student['firstName']} {student['lastName']}".strip(),
        "gradeLevel": student["currentGrade"], "sectionName": student["currentSection"],
        "teacherId": staff["staffId"], "teacherName": staff["name"],
        "scheduledDate": _midnight(day), "startTime": start, "endTime": end,
        "guardianName": g.get("name"), "guardianPhone": g.get("phone"), "guardianEmail": g.get("email") or "guardian.dummy@example.test",
        "status": status, "academicYear": student["currentAcademicYear"], "discussionPoints": list(points),
        "meetingNotes": "", "actionItems": [], "parentAttended": False, "requestedBy": staff["name"],
        "notifiedAt": _now_iso(), "notificationStatus": "sent",
        "createdAt": "2026-09-20T06:00:00.000Z", "updatedAt": "2026-09-20T06:00:00.000Z", "__v": 0,
    }
    m.update(kw)
    return m


def seed():
    if _state["seeded"]:
        return
    _state["seeded"] = True
    t = _today()
    d = lambda n: t + datetime.timedelta(days=n)
    T, CT = S.ACCOUNTS["teacher"], S.ACCOUNTS["classteacher"]
    other = {"staffId": S.OTHER_STAFF, "name": "Other Teacher (DUMMY)"}
    ptm = []
    # Tess Teacher (plain teacher, Grade 5 A + Grade 6 B subject classes)
    s5 = lambda n: _student_by("Grade 5", "A", n)
    ptm += [
        _meeting(1, T, s5(0), t, "requested", "23:00", "23:30", ["Maths progress", "Homework routine"]),  # today, still ahead
        _meeting(2, T, s5(1), t, "confirmed", "00:10", "00:30", ["Reading level"]),  # today, already over by any clock (shown as 'Earlier today')
        _meeting(3, T, s5(2), d(2), "confirmed", "10:00", "10:20", ["Behaviour in class"]),
        _meeting(4, T, s5(3), d(5), "requested", "11:00", "11:30", ["Term results", "Attendance"]),
        _meeting(5, T, s5(4), d(-3), "completed", "09:00", "09:20", ["Spelling"],
                 meetingNotes="Parent attended. Agreed daily reading for 15 minutes.", parentAttended=True,
                 actionItems=[{"_id": _oid(0x2001), "description": "Read 15 minutes every evening", "assignedTo": "Parent", "dueDate": _midnight(d(7)), "status": "pending"},
                              {"_id": _oid(0x2002), "description": "Send the reading log on Friday", "assignedTo": "Teacher", "status": "done"}]),
        _meeting(6, T, s5(5), d(-10), "no_show", "10:00", "10:20", ["Homework completion"], meetingNotes="Parent did not come.", parentAttended=False),
        _meeting(7, T, s5(6), d(-2), "requested", "12:00", "12:20", ["Support plan"]),  # past, never recorded
        _meeting(8, T, s5(7), d(-1), "cancelled", "14:00", "14:20", ["Trip form"], cancelledReason="Parent is travelling", cancelledBy="Tess Teacher"),
        # someone else's meeting about a student I also teach (visible in the student's history, and by id: the server has no ownership read check)
        _meeting(9, other, s5(0), d(-30), "completed", "09:00", "09:20", ["Science project"], meetingNotes="Went well (another teacher).", parentAttended=True),
    ]
    # Clara Classteacher (class teacher of Grade 5 A)
    ptm += [
        _meeting(21, CT, s5(8), t, "confirmed", "23:10", "23:40", ["Settling in"]),
        _meeting(22, CT, s5(9), d(3), "requested", "09:30", "10:00", ["Friendships"]),
        _meeting(23, CT, s5(10), d(-4), "completed", "10:30", "10:50", ["Reading"], meetingNotes="Fine.", parentAttended=True),
    ]
    _state["ptm"] = {m["_id"]: m for m in ptm}

    # ---- fixtures (DUMMY) ----
    def fx(n, day, period, start, end, grade, section, subject, room, orig, sub, status, **kw):
        f = {"_id": _oid(0x3000 + n), "tenantId": _oid(0xa1), "institutionId": _oid(0xa2), "campusId": None,
             "date": _midnight(day), "dayOfWeek": (day.weekday() + 1) % 7, "timetableId": _oid(0x101), "periodNo": period,
             "startTime": start, "endTime": end, "gradeLevel": grade, "sectionName": section, "subject": subject, "roomNo": room,
             "originalTeacherId": orig["staffId"], "originalTeacherName": orig["name"],
             "substituteTeacherId": sub["staffId"] if sub else None, "substituteTeacherName": sub["name"] if sub else None,
             "reason": "leave", "leaveApplicationId": None, "status": status, "assignedBy": "Admin",
             "notificationStatus": "sent", "createdAt": "2026-10-01T06:00:00.000Z", "updatedAt": "2026-10-01T06:00:00.000Z", "__v": 0}
        f.update(kw)
        return f
    fxs = [
        fx(1, t, 3, "09:20", "10:00", "Grade 4", "B", "Mathematics", "101", other, T, "assigned"),
        fx(2, d(1), 2, "08:40", "09:20", "Grade 6", "A", "English", "204", other, T, "assigned"),
        fx(3, d(-2), 5, "11:40", "12:20", "Grade 3", "A", "Science", "Lab 1", other, T, "completed"),
        fx(4, t, 5, "11:40", "12:20", "Grade 6", "B", "Science", "Lab 2", T, None, "open", reason="training"),
        fx(5, d(1), 4, "10:20", "11:00", "Grade 5", "A", "Mathematics", "101", T, other, "assigned", reason="training"),
        fx(6, d(-1), 1, "08:00", "08:40", "Grade 6", "B", "Science", "Lab 2", T, other, "cancelled", reason="other", notes="Timetable changed"),
        fx(7, t, 2, "08:40", "09:20", "Grade 2", "A", "Art", "Art room", other, CT, "assigned"),
        fx(8, d(2), 6, "12:20", "13:00", "Grade 5", "A", "Mathematics", "101", CT, other, "assigned"),
        fx(9, t, 7, "13:00", "13:40", "Grade 1", "A", "Reading", "112", other, {"staffId": _oid(0xa8), "name": "Third Teacher (DUMMY)"}, "assigned"),  # someone else's cover
    ]
    _state["fx"] = {f["_id"]: f for f in fxs}

    # ---- leave (DUMMY) ----
    def lv(n, staff, typ, a, b, days, reason, status, **kw):
        l = {"_id": _oid(0x4000 + n), "tenantId": _oid(0xa1), "institutionId": _oid(0xa2), "staffId": staff["staffId"], "staffName": staff["name"],
             "staffEmployeeId": "EMP-STUB", "department": staff["department"], "leaveNo": f"LV-{t.year}-{n:04d}", "leaveType": typ,
             "fromDate": _midnight(a), "toDate": _midnight(b), "totalDays": days, "isHalfDay": False, "reason": reason, "status": status,
             "createdAt": _iso(datetime.datetime.utcnow() - datetime.timedelta(days=30 - n)), "updatedAt": "2026-10-01T06:00:00.000Z", "__v": 0}
        l.update(kw)
        return l
    # `approvedBy` is POPULATED by the real history query ('profile email', HS:684): the app must never read or show it.
    approver = {"_id": _oid(0xb1), "email": "hr.admin.dummy@example.test", "profile": {"firstName": "Hina", "lastName": "HR (DUMMY)"}}
    leaves = [
        lv(1, T, "annual", d(-40), d(-38), 3, "Family wedding out of town", "approved", approverName="Hina HR (DUMMY)", approvedAt=_iso(datetime.datetime.utcnow() - datetime.timedelta(days=42)), approverNote="Enjoy.", approvedBy=approver),
        lv(2, T, "sick", d(-20), d(-19), 2, "Fever and a doctor's rest advice", "approved", approverName="Hina HR (DUMMY)", approvedAt=_iso(datetime.datetime.utcnow() - datetime.timedelta(days=20)), approvedBy=approver),
        lv(3, T, "casual", d(-12), d(-12), 1, "Personal errand at the bank", "rejected", approverName="Hina HR (DUMMY)", approvedAt=_iso(datetime.datetime.utcnow() - datetime.timedelta(days=13)), approverNote="Exam week: please pick another day.", rejectionReason="Exam week", approvedBy=approver),
        lv(4, T, "annual", d(10), d(12), 3, "Brother's graduation ceremony", "pending"),
        lv(5, CT, "sick", d(-8), d(-7), 2, "Flu, resting at home", "approved", approverName="Hina HR (DUMMY)", approvedAt=_iso(datetime.datetime.utcnow() - datetime.timedelta(days=9)), approvedBy=approver),
    ]
    _state["leave"] = {l["_id"]: l for l in leaves}


def _balances(a):
    """LeaveBalance numbers per account (LB:9-22 defaults). The class teacher has NO LeaveBalance document -> hasPolicy false (HS:1432-1433)."""
    if a["staffId"] == S.ACCOUNTS["teacher"]["staffId"]:
        return {"annual": (21, 4), "sick": (10, 2), "casual": (10, 0), "maternity": (90, 0), "paternity": (10, 0), "hajj": (0, 0)}, True
    return None, False


# ---- PTM endpoints ----

def _guard_oid(v, label):
    return None if _is_oid(v) else (400, f"Invalid {label} id")  # OID:11


def list_meetings(a, q, mode=""):
    """GET /teaching/ptm?teacherId&studentId&status&from&to (PC:19-22 -> PS:124-137): filters, sorted scheduledDate DESC, limit 200, teacher
    projection (TP). An invalid teacherId/studentId makes `new Types.ObjectId(...)` throw (unhandled -> 500; UNVERIFIED mapping)."""
    seed()
    arg = lambda k: (q.get(k) or [""])[0]
    for k in ("teacherId", "studentId"):
        if arg(k) and not _is_oid(arg(k)):
            return 500, "Internal server error"
    f, t = _parse_date(arg("from")), _parse_date(arg("to"))
    out = []
    for m in _state["ptm"].values():
        if arg("status") and m["status"] != arg("status"):
            continue
        if arg("teacherId") and m["teacherId"] != arg("teacherId"):
            continue
        if arg("studentId") and m["studentId"] != arg("studentId"):
            continue
        sd = _parse_date(m["scheduledDate"])
        if (arg("from") and f is not None and sd < f) or (arg("to") and t is not None and sd > t):
            continue
        out.append(m)
    out.sort(key=lambda m: m["scheduledDate"], reverse=True)
    return 200, project_for_teacher(out[:200])


def upcoming_mine(a, q):
    """GET /teaching/ptm/upcoming/mine?teacherId (PC:24-30 -> PS:223-228): requested|confirmed with scheduledDate >= now, ascending. Drops
    today's meetings once the day has started (the stored value is midnight)."""
    seed()
    tid = (q.get("teacherId") or [""])[0]
    if not _is_oid(tid):
        return 500, "Internal server error"
    now = _now_iso()
    out = [m for m in _state["ptm"].values() if m["teacherId"] == tid and m["status"] in ("requested", "confirmed") and m["scheduledDate"] >= now]
    out.sort(key=lambda m: m["scheduledDate"])
    return 200, project_for_teacher(out)


def get_meeting(a, mid, mode=""):
    """GET /teaching/ptm/:id (PC:37-40 -> PS:139-145): 400 'Invalid meeting id' / 404 'Meeting not found'. NO ownership check."""
    seed()
    bad = _guard_oid(mid, "meeting")
    if bad:
        return bad
    m = _state["ptm"].get(mid)
    if mode == "notfound" or not m:
        return 404, "Meeting not found"
    return 200, project_for_teacher(m)


def student_history(a, sid):
    """GET /teaching/ptm/student/:studentId/history (PC:32-35 -> PS:147-153): all meetings of the student (any teacher), newest first."""
    seed()
    bad = _guard_oid(sid, "student")
    if bad:
        return bad
    rows = sorted([m for m in _state["ptm"].values() if m["studentId"] == sid], key=lambda m: m["scheduledDate"], reverse=True)
    return 200, project_for_teacher(rows)


def create_meeting(a, body, mode=""):
    """POST /teaching/ptm (PC:43-47 -> PS:69-122), 201. A TEACHER caller: teacherId absent -> mine; mine -> mine; other -> 403 (PS:71-73, TI:67-70).
    Student / teacher lookups (PS:75-79): 404. The document is saved with status 'requested', guardian fields copied from the student's primary
    guardian (PS:81, :97-99). Mongoose requires studentId, studentName, gradeLevel, teacherId, teacherName, scheduledDate, academicYear (PSC:36-52):
    a missing one is a ValidationError (status UNVERIFIED, modelled as 500)."""
    seed()
    if not _is_teacher(a):
        return 403, "Forbidden resource"
    me = a["staffId"]
    tid = body.get("teacherId")
    if mode == "notmine" or (tid not in (None, "", me, a.get("teacherProfileId"))):
        return 403, "You can only create meetings for yourself"
    sid = body.get("studentId")
    if not _is_oid(sid):
        return 500, "Internal server error"  # findById(CastError) UNVERIFIED mapping
    student = S.STUDENTS_BY_ID.get(sid)
    if mode == "nostudent" or not student:
        return 404, "Student not found"
    when = _parse_date(body.get("scheduledDate"))
    if when is None or not isinstance(body.get("academicYear"), str) or not body.get("academicYear").strip():
        return 500, "Internal server error"  # PTMMeeting validation failed (UNVERIFIED status)
    n = _next(0x5000)
    m = _meeting(0, a, student, when.date(), "requested", body.get("startTime"), body.get("endTime"), body.get("discussionPoints") or [])
    m["_id"] = n
    m["teacherId"] = me
    m["teacherName"] = a["name"]
    m["academicYear"] = body["academicYear"]
    m["scheduledDate"] = when.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    m["createdAt"] = m["updatedAt"] = _now_iso()
    _state["ptm"][n] = m
    _state["last_create"] = {k: body.get(k) for k in ("studentId", "teacherId", "scheduledDate", "startTime", "endTime", "academicYear", "discussionPoints")}
    return 201, project_for_teacher(m)


def confirm_meeting(a, mid, mode=""):
    """PATCH /teaching/ptm/:id/confirm (PC:49-53 -> PS:155-164): only from `requested`; NO ownership check."""
    seed()
    bad = _guard_oid(mid, "meeting")
    if bad:
        return bad
    m = _state["ptm"].get(mid)
    if mode == "notrequested" and m:
        m["status"] = "confirmed"
    if not m or m["status"] != "requested":
        return 404, "Meeting not found or not in a requested state"
    m["status"] = "confirmed"
    return 200, project_for_teacher(m)


def _own_check(a, mid, mode):
    """assertTeacherOwnsMeeting (PS:30-37): 404 'Meeting not found' / 403 'You can only modify your own meetings' for teacher callers."""
    m = _state["ptm"].get(mid)
    if not m:
        return None, (404, "Meeting not found")
    if mode == "notmine" or m["teacherId"] not in (a["staffId"], a.get("teacherProfileId")):
        return None, (403, "You can only modify your own meetings")
    return m, None


def reschedule_meeting(a, mid, body, mode=""):
    """PATCH /teaching/ptm/:id/reschedule (PC:55-59 -> PS:166-179): ownership first, then only from requested|confirmed (else 404), sets
    scheduledDate = new Date(body.scheduledDate), startTime/endTime = body values (OMITTED -> cleared), status -> 'requested'."""
    seed()
    bad = _guard_oid(mid, "meeting")
    if bad:
        return bad
    m, err = _own_check(a, mid, mode)
    if err:
        return err
    if mode == "closed":
        m["status"] = "completed"
    if m["status"] not in ("requested", "confirmed"):
        return 404, "Meeting not found or already completed/cancelled"
    when = _parse_date(body.get("scheduledDate"))
    if when is None:
        return 500, "Internal server error"  # Invalid Date cast (UNVERIFIED mapping)
    m["scheduledDate"] = when.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    m["startTime"], m["endTime"] = body.get("startTime"), body.get("endTime")
    m["status"] = "requested"
    return 200, project_for_teacher(m)


def record_outcome(a, mid, body, mode=""):
    """PATCH /teaching/ptm/:id/outcome (PC:61-65 -> PS:181-198): ownership; 400 on a cancelled meeting; status = completed|no_show from
    parentAttended; notes `|| ''`; actionItems REPLACED (description, assignedTo, dueDate, status||'pending')."""
    seed()
    bad = _guard_oid(mid, "meeting")
    if bad:
        return bad
    m, err = _own_check(a, mid, mode)
    if err:
        return err
    if mode == "cancelled":
        m["status"] = "cancelled"
    if m["status"] == "cancelled":
        return 400, "Cannot record an outcome for a cancelled meeting"
    attended = bool(body.get("parentAttended"))
    m["status"] = "completed" if attended else "no_show"
    m["meetingNotes"] = body.get("meetingNotes") or ""
    m["parentAttended"] = attended
    if body.get("actionItems") is not None:
        items = []
        for it in body["actionItems"]:
            due = it.get("dueDate")
            items.append({"_id": _next(0x2000), "description": it.get("description"), "assignedTo": it.get("assignedTo"),
                          **({"dueDate": _parse_date(due).strftime("%Y-%m-%dT00:00:00.000Z")} if due and _parse_date(due) else {}),
                          "status": it.get("status") or "pending"})
        m["actionItems"] = items
    return 200, project_for_teacher(m)


def set_action_item(a, mid, aid, body, mode=""):
    """PATCH /teaching/ptm/:id/action-items/:aid (PC:67-74 -> PS:200-209): NO ownership check; 404 'Meeting not found' / 'Action item not
    found'; status must be pending|done (Mongoose enum on save; otherwise a 500, UNVERIFIED mapping)."""
    seed()
    bad = _guard_oid(mid, "meeting")
    if bad:
        return bad
    m = _state["ptm"].get(mid)
    if not m:
        return 404, "Meeting not found"
    item = next((i for i in m["actionItems"] if i["_id"] == aid), None)
    if mode == "notfound" or not item:
        return 404, "Action item not found"
    if body.get("status") not in ("pending", "done"):
        return 500, "Internal server error"
    item["status"] = body["status"]
    return 200, project_for_teacher(m)


def cancel_meeting(a, mid, body, mode=""):
    """PATCH /teaching/ptm/:id/cancel (PC:76-79 -> PS:211-221): NO ownership check, NO status check (a completed meeting can be cancelled);
    sets cancelledReason = body.reason, cancelledBy = the caller's name."""
    seed()
    bad = _guard_oid(mid, "meeting")
    if bad:
        return bad
    m = _state["ptm"].get(mid)
    if not m:
        return 404, "Meeting not found"
    m["status"] = "cancelled"
    m["cancelledReason"] = body.get("reason")
    m["cancelledBy"] = a["name"]
    return 200, project_for_teacher(m)


# ================================== fixtures ==================================

def list_fixtures(a, q):
    """GET /teaching/fixtures?teacherId&status&date&from&to (SC:42-45 -> SS:232-245): `teacherId` matches originalTeacherId OR
    substituteTeacherId (SS:241); sorted date DESC then periodNo ASC; limit 200. No role projection (no student data in a fixture)."""
    seed()
    arg = lambda k: (q.get(k) or [""])[0]
    f, t = _parse_date(arg("from")), _parse_date(arg("to"))
    out = []
    for x in _state["fx"].values():
        if arg("status") and x["status"] != arg("status"):
            continue
        if arg("teacherId") and arg("teacherId") not in (x["originalTeacherId"], x["substituteTeacherId"]):
            continue
        d = _parse_date(x["date"])
        if (arg("from") and f is not None and d < f) or (arg("to") and t is not None and d > t):
            continue
        out.append(x)
    # date DESC, periodNo ASC (SS:244): stable sorts, least significant key first
    out.sort(key=lambda x: x["periodNo"])
    out.sort(key=lambda x: x["date"], reverse=True)
    return 200, out[:200]


def complete_fixture(a, fid, mode=""):
    """PATCH /teaching/fixtures/:id/complete (SC:36-40 -> SS:223-230): `status: 'assigned'` filter, no ownership check; no ObjectId guard
    (a malformed id is a CastError, UNVERIFIED 500)."""
    seed()
    if not _is_oid(fid):
        return 500, "Internal server error"
    x = _state["fx"].get(fid)
    if mode == "notassigned" and x:
        x["status"] = "completed"
    if not x or x["status"] != "assigned":
        return 404, "Fixture not found or not in an assigned state"
    x["status"] = "completed"
    return 200, x


def set_fixture(fid, status):
    seed()
    x = _state["fx"].get(fid)
    if not x:
        return 404, "Fixture not found"
    x["status"] = status
    return 200, x


# ================================== leave ==================================

def leave_balance(a, mode=""):
    """GET /hr/leave/self/balance (HC:241-243 -> HS:1430-1434 -> formatLeaveBalance HS:1397-1409). 404 when no Staff is linked (HS:1426)."""
    seed()
    if mode == "nostaff":
        return 404, "No staff record is linked to your account. Contact HR to have your login connected to your employee record."
    nums, has = _balances(a)
    nums = nums or {}
    out = {"staffId": a["staffId"], "staffName": a["name"], "employeeId": "EMP-STUB", "department": a["department"], "hasPolicy": has}
    for k in ("annual", "sick", "casual", "maternity", "paternity", "hajj"):
        ent, used = nums.get(k, (0, 0))
        out[k] = {"entitled": ent, "used": used, "remaining": ent - used}
    return 200, out


def leave_history(a):
    """GET /hr/leave/self/history (HC:245-247 -> HS:1436-1439 -> getLeaveApplications HS:680-685): MY applications, newest first (createdAt),
    `approvedBy` populated with 'profile email' (HS:684) - the approver's EMAIL reaches the teacher's app (see the report; never read)."""
    seed()
    rows = [(i, l) for i, l in enumerate(_state["leave"].values()) if l["staffId"] == a["staffId"]]
    rows.sort(key=lambda t: (t[1]["createdAt"], t[0]), reverse=True)  # newest first; ties keep the later insert first
    return 200, [l for _, l in rows]


def apply_leave(a, body, mode=""):
    """POST /hr/leave/self (HC:249-253 -> HS:1441-1455 -> createLeaveApplication HS:1248-1268), 201. Identity fields are stripped from the body
    (LS:44-52) and taken from the caller's Staff record. totalDays = calendar days inclusive, ceil((to-from)/day)+1 (LD:46-48; weekend
    exclusion is a per-policy flag the stub does not model). Mongoose requires leaveType (enum LA:14), fromDate, toDate, totalDays, reason
    (LA:14-20). There is NO validation of to >= from: a reversed range gets 0 or a negative totalDays and is saved."""
    seed()
    if mode == "invalid":
        return 400, "LeaveApplication validation failed: reason: Path `reason` is required."
    enum = ("annual", "sick", "casual", "maternity", "paternity", "emergency", "unpaid", "study", "hajj", "other")
    f, t = _parse_date(body.get("fromDate")), _parse_date(body.get("toDate"))
    reason = body.get("reason")
    if body.get("leaveType") not in enum or f is None or t is None or not isinstance(reason, str) or not reason.strip():
        return 400, "LeaveApplication validation failed"  # status UNVERIFIED (no DTO; an unhandled ValidationError)
    total = -((-(t - f).total_seconds()) // 86400) + 1  # Math.ceil(diff / day) + 1
    n = len(_state["leave"]) + 1
    l = {"_id": _next(0x6000), "tenantId": _oid(0xa1), "institutionId": _oid(0xa2), "staffId": a["staffId"], "staffName": a["name"],
         "staffEmployeeId": "EMP-STUB", "department": a["department"], "leaveNo": f"LV-{_today().year}-{n:04d}", "leaveType": body["leaveType"],
         "fromDate": f.strftime("%Y-%m-%dT00:00:00.000Z"), "toDate": t.strftime("%Y-%m-%dT00:00:00.000Z"), "totalDays": int(total),
         "isHalfDay": bool(body.get("isHalfDay")), **({"halfDaySession": body["halfDaySession"]} if body.get("halfDaySession") else {}),
         "reason": reason, "status": "pending", "createdAt": _now_iso(), "updatedAt": _now_iso(), "__v": 0}
    _state["leave"][l["_id"]] = l
    _state["last_apply"] = {k: body.get(k) for k in body}
    return 201, l


def decide_leave(lid, status, note="", by="Hina HR (DUMMY)"):
    seed()
    l = _state["leave"].get(lid)
    if not l:
        return 404, "Leave application not found"
    l.update({"status": status, "approverName": by, "approvedAt": _now_iso(), "approverNote": note})
    if status == "rejected" and note:
        l["rejectionReason"] = note
    return 200, l
