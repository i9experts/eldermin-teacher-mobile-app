"""Phase 7a stub logic: parent messaging (threads / messages / guardians), the notifications inbox and student-leave review.

!! DUMMY DATA ONLY. Lives under tool/dev/, never shipped. Imported by stub_server.py (HTTP routing, auth and the dev mode switches live
!! there). Every function returns (status, body) so tests can call it directly.

Citation legend (paths relative to eldermin-backend/src/, branch feat/staff-portal, HEAD 0b81e55; read-only). "UNVERIFIED" = cannot be
confirmed from code; every one of them is in PHASE7A_REPORT.md.
  SPC = staff-portal/staff-portal.controller.ts     SPS = staff-portal/staff-portal.service.ts   DTO = staff-portal/dto/staff-portal.dto.ts
  NM  = parent-portal/schemas/notification-and-message.schema.ts    CL = parent-portal/schemas/consent-and-leave.schema.ts
  PPS = parent-portal/parent-portal.service.ts      SN = staff-portal/staff-notifier.service.ts
  FLT = filters/sentry.filter.ts (error body {statusCode,message,timestamp,path}; an array message is cut to its first element)
  MAIN = main.ts (global ValidationPipe whitelist:true, transform:true)

/__stub/mode features (value: ok|empty|400|403|404|409|422|500|drop|slow, plus the special values below):
  threads GET /staff-portal/threads         threadmsgs GET /staff-portal/threads/:id/messages   threadsend POST .../messages
  threadread POST .../read                  threadclose PATCH .../close                         threadcreate POST /staff-portal/threads
  guardians GET /staff-portal/students/:id/guardians
  notifs GET /staff-portal/notifications   unread GET .../unread-count   notifread POST .../:id/read   notifreadall POST .../read-all
  leaves GET /staff-portal/student-leaves  leavereview PATCH /staff-portal/student-leaves/:id
  special values (each message is copied from the backend code at the cited line):
    threadmsgs=notfound        404 'Thread not found' (SPS:229-231)
    threadmsgs=ignoreafter     answers the whole thread whatever `after` says (an older deployment; UNVERIFIED whether any exists)
    threadsend=closed          409 'This conversation is closed.' (SPS:241); the thread is flipped to closed so a reload shows it
    threadsend=blank           400 'Message body is required.' (SPS:244) (a whitespace-only body passes the DTO, the service rejects it)
    guardians=notteach         403 'You do not teach this student.' (SPS:292)
    threadcreate=notteach      403 'You do not teach this student.' (SPS:292)
    threadcreate=notguardian   403 'That person is not a registered guardian of this student.' (SPS:304)
    leaves=notclassteacher     403 'Only class teachers can review student leave requests.' (SPS:105)
    leavereview=notclassteacher the same 403         leavereview=notmyclass 403 'This student is not in your class.' (SPS:352)
    leavereview=decided        409 'This request was already approved.' (SPS:354); the request is flipped to approved by 'Clara Classteacher'
                               (as if decided on another device) so a refresh shows who decided it
  Dev controls (not part of the real API): POST /__stub/guardian-reply?thread=<id>&body=<text> (a guardian answers: new message +
  staffHasUnread=true), POST /__stub/notify?type=&title=&body=&entity= (a new unread notification for the teacher).
"""
import datetime
import re

S = None  # the stub_server module, injected by bind()


def bind(mod):
    global S
    S = mod


_state = {"seeded": False, "threads": {}, "messages": {}, "notifs": {}, "leaves": {}, "seq": 0, "last_send": None, "last_create": None,
          "last_review": None, "read_calls": [], "send_calls": 0}


def reset():
    _state.update({"seeded": False, "threads": {}, "messages": {}, "notifs": {}, "leaves": {}, "seq": 0, "last_send": None,
                   "last_create": None, "last_review": None, "read_calls": [], "send_calls": 0})


def state_summary():
    return {"threads": len(_state["threads"]), "messages": sum(len(v) for v in _state["messages"].values()),
            "notifications": sum(len(v) for v in _state["notifs"].values()), "studentLeaves": len(_state["leaves"]),
            "sendCalls": _state["send_calls"], "lastSend": _state["last_send"], "lastCreate": _state["last_create"],
            "lastReview": _state["last_review"], "threadReadCalls": list(_state["read_calls"])}


def _now():
    return datetime.datetime.utcnow()


def _iso(d):
    return d.strftime("%Y-%m-%dT%H:%M:%S.") + f"{d.microsecond // 1000:03d}Z"


def _ago(**kw):
    return _iso(_now() - datetime.timedelta(**kw))


def _oid(n):
    return f"64e{n:021x}"


def _is_oid(v):
    return isinstance(v, str) and re.fullmatch(r"[0-9a-fA-F]{24}", v) is not None


def _next_id(base):
    _state["seq"] += 1
    return _oid(base + _state["seq"])


def _js_int(v, default):
    """parseInt(v || default, 10) || default (SPS:174, :331): '12abc' -> 12, 'x' / '0' / '' -> default."""
    m = re.match(r"\s*([+-]?\d+)", v or "")
    n = int(m.group(1)) if m else 0
    return n or default


def _parse_date(v):
    """new Date(v) for the ISO forms the app sends; None when it cannot be understood (the filter is then ignored, SPS:178-179)."""
    try:
        return datetime.datetime.fromisoformat(v.replace("Z", "+00:00")).replace(tzinfo=None) if v.endswith("Z") else datetime.datetime.fromisoformat(v)
    except Exception:
        return None


# --------------------------- classes / students / guardians ---------------------------

def _classes_of(a):
    """SPS:82-91 classesOf: the class-teacher class + current assignments (the stub's staff_me profile)."""
    out = []
    if a["classTeacher"]:
        out.append(("Grade 5", "A"))
    out += [("Grade 5", "A"), ("Grade 6", "B")]
    return out


def _teaches(a, student):
    """SPS:93-98 teachesStudent (tolerant grade/section match, CM)."""
    g, sec = S._norm_grade(student["currentGrade"]), S._norm_section(student["currentSection"])
    return any(S._norm_grade(cg) == g and (not cs or S._norm_section(cs) == sec) for cg, cs in _classes_of(a))


def guardians_of(student):
    """User documents with guardianOfStudentIds containing the student (SPS:277-279). DUMMY: the guardian rows of the student document,
    one account each (de-duplicated by name); the student at roll 6 of Grade 5 A has NO guardian account (empty state)."""
    if student["currentRollNumber"] == "6" and student["currentGrade"] in ("Grade 5", "5"):
        return []
    seen, out = set(), []
    for i, g in enumerate(student["guardians"]):
        if g["name"] in seen:
            continue
        seen.add(g["name"])
        out.append({"userId": S._oid(0x7000 + int(student["_id"][-3:], 16) * 4 + i), "name": g["name"]})
    return out


def list_guardians(a, student_id, mode=""):
    """GET /staff-portal/students/:studentId/guardians (SPC:72-75 -> SPS:274-284, 286-296): bare array [ { userId, name } ] - names only,
    NO phone / email (owner rule)."""
    if a["role"] != "teacher":
        return 403, "Forbidden resource"
    if not _is_oid(student_id):
        return 404, "Student not found"  # SPS:288
    st = S.STUDENTS_BY_ID.get(student_id)
    if not st:
        return 404, "Student not found"  # SPS:290
    if mode == "notteach" or not _teaches(a, st):
        return 403, "You do not teach this student."  # SPS:292
    return 200, guardians_of(st)


# --------------------------- threads / messages ---------------------------

def _thread(n, a, student, guardian, subject, preview, *, st="open", unread=False, minutes=30, g_unread=False):
    t_id = _oid(0x900 + n)
    return {"_id": t_id, "subject": subject, "studentId": student["_id"],
            "studentName": f"{student['firstName']} {student['lastName']}", "guardianUserId": guardian["userId"],
            "guardianName": guardian["name"], "staffId": a["staffId"], "staffName": a["name"], "lastMessagePreview": preview[:140],
            "lastMessageAt": _ago(minutes=minutes), "guardianHasUnread": g_unread, "staffHasUnread": unread, "status": st,
            "schoolSlug": "demo-school", "createdAt": _ago(days=3), "updatedAt": _ago(minutes=minutes), "__v": 0}


def _msg(thread, mid, role, name, body, *, minutes=0, hours=0, days=0):
    return {"_id": _oid(0xB00 + mid), "threadId": thread["_id"], "senderRole": role, "senderName": name, "body": body,
            "schoolSlug": "demo-school", "createdAt": _ago(minutes=minutes, hours=hours, days=days),
            "updatedAt": _ago(minutes=minutes, hours=hours, days=days), "__v": 0}


def seed():
    if _state["seeded"]:
        return
    _state["seeded"] = True
    rosters = {}
    for acc in ("teacher", "classteacher"):
        a = S.ACCOUNTS[acc]
        studs = [s for s in S.STUDENTS if s["status"] == "active" and _teaches(a, s)]
        rosters[acc] = studs
        base = 0x100 if acc == "teacher" else 0x200

        def pick(i):
            s = studs[i]
            return s, guardians_of(s)[0]
        s1, g1 = pick(1)
        s2, g2 = pick(2)
        s3, g3 = pick(3)
        s4, g4 = pick(4)
        defs = [
            (1, s1, g1, "Homework query", "Thank you ma'am, we will send it tomorrow.", dict(unread=True, minutes=12, g_unread=False)),
            (2, s2, g2, "Science fair project", "Could you share the worksheet for the project?", dict(unread=True, minutes=95)),
            (3, s3, g3, "Parent meeting", "See you at the meeting on Thursday.", dict(unread=False, minutes=60 * 26)),
            (4, s4, g4, "Old topic", "Closed topic, thank you.", dict(unread=True, st="closed", minutes=60 * 24 * 5)),
        ]
        for n, s, g, subj, prev, kw in defs:
            t = _thread(base + n, a, s, g, subj, prev, **kw)
            _state["threads"][t["_id"]] = t
            _state["messages"][t["_id"]] = _seed_messages(base + n * 10, t, a, n)
        # notifications for this user (newest first)
        _state["notifs"][a["id"]] = _seed_notifs(a, base, [t for t in _state["threads"].values() if t["staffId"] == a["staffId"]])
    # student leaves (Grade 5 A, class teacher's class): 3 pending, 2 approved, 1 rejected
    ct = S.ACCOUNTS["classteacher"]
    roster5a = [s for s in rosters["classteacher"] if S._norm_grade(s["currentGrade"]) == "5" and S._norm_section(s["currentSection"]) == "a"]
    today = S._today()

    def leave(n, student, days_from, length, typ, reason, status="pending", approver=None, note=None, created_days=1, by=None):
        g = guardians_of(student)
        by_g = by or (g[0] if g else {"userId": S._oid(0x7fff), "name": "Guardian"})
        f = today + datetime.timedelta(days=days_from)
        d = {"_id": _oid(0xC00 + n), "studentId": student["_id"], "studentName": f"{student['firstName']} {student['lastName']}",
             "fromDate": f"{f.isoformat()}T00:00:00.000Z", "toDate": f"{(f + datetime.timedelta(days=length - 1)).isoformat()}T00:00:00.000Z",
             "reason": reason, "leaveType": typ, "requestedByUserId": by_g["userId"], "requestedByName": by_g["name"], "status": status,
             "schoolSlug": "demo-school", "campusId": S.CAMPUS_ID, "createdAt": _ago(days=created_days), "updatedAt": _ago(days=created_days), "__v": 0}
        if approver:
            d.update({"approverName": approver, "approvedAt": _ago(hours=5)})
            if note:
                d["approverNote"] = note
        return d
    rows = [
        leave(1, roster5a[0], 1, 2, "sick", "Fever and a doctor's appointment.", created_days=0),
        leave(2, roster5a[1], 3, 1, "family", "Family wedding out of town.", created_days=1),
        leave(3, roster5a[2], 7, 5, "travel", "Visiting grandparents abroad; flights already booked.", created_days=2),
        leave(4, roster5a[3], -3, 2, "sick", "Stomach infection.", status="approved", approver="Clara Classteacher", note="Get well soon.", created_days=4),
        leave(5, roster5a[4], -6, 1, "other", "Dentist.", status="approved", approver="Clara Classteacher", created_days=7),
        leave(6, roster5a[5], -10, 3, "travel", "Trip.", status="rejected", approver="Clara Classteacher", note="Exams that week; please reapply for another date.", created_days=12),
    ]
    for r in rows:
        _state["leaves"][r["_id"]] = r
    _finish_seed_notifs()


def _seed_messages(base, t, a, n):
    g, me = t["guardianName"], a["name"]
    if n == 1:
        return [_msg(t, base + 1, "guardian", g, "Assalamu alaikum, what is the homework for Monday?", hours=26),
                _msg(t, base + 2, "staff", me, "Walaikum assalam. Please complete exercise 4 on page 32.", hours=25),
                _msg(t, base + 3, "guardian", g, "Thank you ma'am, we will send it tomorrow.", minutes=12)]
    if n == 2:
        return [_msg(t, base + 1, "staff", me, "Hello, the science fair project is due next Friday.", hours=5),
                _msg(t, base + 2, "guardian", g, "Could you share the worksheet for the project?", minutes=95)]
    if n == 3:
        return [_msg(t, base + 1, "staff", me, "I would like to meet you about the term progress.", days=2),
                _msg(t, base + 2, "guardian", g, "Sure, which day suits you?", days=2, hours=-1),
                _msg(t, base + 3, "staff", me, "Thursday 4 pm?", days=1, hours=2),
                _msg(t, base + 4, "guardian", g, "See you at the meeting on Thursday.", hours=26)]
    return [_msg(t, base + 1, "staff", me, "Following up on last month's topic.", days=6),
            _msg(t, base + 2, "guardian", g, "Closed topic, thank you.", days=5)]


def _notif(n, a, typ, title, body, ago, entity=None, read=False):
    d = {"_id": _oid(0xD00 + n), "recipientUserId": a["id"], "type": typ, "title": title, "body": body, "isRead": read,
         "schoolSlug": "demo-school", "createdAt": _ago(**ago), "updatedAt": _ago(**ago), "__v": 0}
    if entity is not None:
        d["relatedEntityId"] = entity
    if read:
        d["readAt"] = _ago(**ago)
    return d


def _seed_notifs(a, base, threads):
    """Newest first. Types and entity semantics per the emitters (see stub docstring / notification_target.dart). 3 unread. UNVERIFIED rows:
    the future type 'zzz_future' and the 'other' row with free text exist to prove the app never crashes on them."""
    t = sorted(threads, key=lambda x: x["lastMessageAt"], reverse=True)
    rows = [
        _notif(base + 1, a, "message", f"New message from {t[0]['guardianName']}", t[0]["lastMessagePreview"], dict(minutes=12), t[0]["_id"]),
        _notif(base + 2, a, "message", f"New message from {t[1]['guardianName']}", t[1]["lastMessagePreview"], dict(minutes=95), t[1]["_id"]),
        _notif(base + 3, a, "substitution", "Substitution assigned", "You are covering Grade 6 B, Period 3 for Other Teacher.", dict(hours=4), _oid(0xF01)),
        _notif(base + 4, a, "ptm", "Parent meeting requested", "Aarav Ahmed on Thursday at 16:00-16:20.", dict(hours=20), _oid(0xF02), read=True),
        _notif(base + 5, a, "lesson_plan", "Lesson plan approved", "Fractions - week 3 was approved.", dict(hours=30), _oid(0xF03), read=True),
        _notif(base + 6, a, "homework", "Submission received: Fractions worksheet", "Zara Siddiqui submitted \"Fractions worksheet\".", dict(hours=33), _oid(0xF04), read=True),
    ]
    if a["classTeacher"]:
        rows.insert(2, _notif(base + 7, a, "leave_status", "New leave request", "Aarav Ahmed: Fri Oct 09 2026 - Sat Oct 10 2026. Fever.", dict(hours=3), _oid(0xC01)))
    else:
        rows.insert(2, _notif(base + 7, a, "leave_status", "Leave request approved", "Your sick leave (Mon Oct 05 2026 - Mon Oct 05 2026) was approved.", dict(hours=3), _oid(0xF05)))
    rows += [
        _notif(base + 8, a, "other", "Welcome to the staff app", "Messages, meetings and leave updates appear here.", dict(days=3), None, read=True),
        _notif(base + 9, a, "zzz_future", "A future kind of notification", "Unknown types stay in the inbox.", dict(days=3, hours=2), "not-an-id", read=True),
    ]
    # older history for infinite scroll (25 rows, 6 h apart)
    for i in range(25):
        rows.append(_notif(base + 20 + i, a, "ptm" if i % 3 == 0 else "message", f"Earlier update {i + 1}", "Older notification (DUMMY history).",
                           dict(days=4, hours=6 * i), _oid(0xF10 + i), read=True))
    return rows


def _finish_seed_notifs():
    """Unread seeding: the first three rows of each list (message, message, leave/substitution) are unread, the rest read."""
    for rows in _state["notifs"].values():
        for i, r in enumerate(rows):
            r["isRead"] = i >= 3
            if r["isRead"]:
                r.setdefault("readAt", r["createdAt"])
            else:
                r.pop("readAt", None)


def _own_threads(a):
    seed()
    return [t for t in _state["threads"].values() if t["staffId"] == a["staffId"]]


def list_threads(a, q):
    """GET /staff-portal/threads?status= (SPC:49-50 -> SPS:217-223): filter by status ONLY when exactly open|closed (SPS:220), sorted
    lastMessageAt desc, limit 100 (SPS:221); { items, unreadCount } where, since backend b069872 (SPS:222-224 at 265fcfa), unreadCount counts ALL
    matching unread threads, not only the returned rows. (Line numbers of the other SPS citations in this file are those of 0b81e55; at 265fcfa
    getThreadMessages grew and everything after it moved by 7 lines.)"""
    if a["role"] != "teacher":
        return 403, "Forbidden resource"
    status = (q.get("status") or [""])[0]
    items = _own_threads(a)
    if status in ("open", "closed"):
        items = [t for t in items if t["status"] == status]
    unread_all = sum(1 for t in items if t["staffHasUnread"])
    items = sorted(items, key=lambda t: t["lastMessageAt"], reverse=True)[:100]
    return 200, {"items": items, "unreadCount": unread_all}


def _own(a, thread_id):
    seed()
    if not _is_oid(thread_id):
        return None, (404, "Thread not found")  # SPS:227
    t = _state["threads"].get(thread_id)
    if not t or t["staffId"] != a["staffId"]:
        return None, (404, "Thread not found")  # SPS:229-230
    return t, None


def thread_messages(a, thread_id, mode="", after=None):
    """GET /staff-portal/threads/:id/messages[?after=<ISO>] (SPC:56-57 -> SPS:240-251, backend 265fcfa): { thread, messages }.
    Without a valid `after`: the NEWEST 500, returned oldest -> newest (SPS:249-250). With a valid `after`: createdAt strictly > after,
    oldest first, limit 500 (SPS:244-247); an unparseable `after` is ignored (SPS:244). mode=ignoreafter imitates an OLDER deployment
    that does not know the parameter (always the whole thread; the app must merge by _id without duplicates)."""
    if mode == "notfound":
        return 404, "Thread not found"
    t, err = _own(a, thread_id)
    if err:
        return err
    rows = sorted(_state["messages"].get(t["_id"], []), key=lambda m: m["createdAt"])
    cut = None if mode == "ignoreafter" or not after else _parse_date(after)
    if cut is not None:
        msgs = [m for m in rows if (_parse_date(m["createdAt"]) or datetime.datetime.min) > cut][:500]
    else:
        msgs = rows[-500:]
    return 200, {"thread": dict(t), "messages": [dict(m) for m in msgs]}


def _dto_body(b):
    """SendThreadMessageDto (DTO:3-5): @IsString @MinLength(1) @MaxLength(4000); class-validator texts. Which message comes first when
    several fail is UNVERIFIED (FLT:43-48 keeps only the first)."""
    v = b.get("body")
    if not isinstance(v, str):
        return "body must be a string"
    if len(v) < 1:
        return "body must be longer than or equal to 1 characters"
    if len(v) > 4000:
        return "body must be shorter than or equal to 4000 characters"
    return None


def send_message(a, thread_id, body, mode=""):
    """POST /staff-portal/threads/:id/messages (SPC:59-63 -> SPS:239-258), 201 -> the created Message document."""
    t, err = _own(a, thread_id)
    if err:
        return err
    bad = _dto_body(body if isinstance(body, dict) else {})
    if bad:
        return 400, bad
    _state["send_calls"] += 1
    if mode == "closed":
        t["status"] = "closed"
    if t["status"] == "closed":
        return 409, "This conversation is closed."  # SPS:241
    text = body["body"].strip()
    if not text or mode == "blank":
        return 400, "Message body is required."  # SPS:244
    m = _msg(t, 0x5000 + _state["seq"] + 1, "staff", a["name"], text)
    _state["seq"] += 1
    m["_id"] = _oid(0xB00 + 0x5000 + _state["seq"])
    _state["messages"].setdefault(t["_id"], []).append(m)
    t.update({"lastMessagePreview": text[:140], "lastMessageAt": m["createdAt"], "guardianHasUnread": True, "staffHasUnread": False,
              "updatedAt": m["createdAt"]})  # SPS:248-252
    _state["last_send"] = {"threadId": t["_id"], "body": text}
    return 201, dict(m)


def mark_thread_read(a, thread_id):
    """POST /staff-portal/threads/:id/read (SPC:65-67 -> SPS:260-265): { ok: true } (200)."""
    t, err = _own(a, thread_id)
    if err:
        return err
    t["staffHasUnread"] = False
    _state["read_calls"].append(t["_id"])
    return 200, {"ok": True}


def close_thread(a, thread_id):
    """PATCH /staff-portal/threads/:id/close (SPC:69-70 -> SPS:267-272): the closed thread document (200; Nest PATCH default)."""
    t, err = _own(a, thread_id)
    if err:
        return err
    t["status"] = "closed"
    return 200, dict(t)


def create_thread(a, body, mode=""):
    """POST /staff-portal/threads (SPC:52-54 -> SPS:298-323), 201 -> the thread document. CreateStaffThreadDto DTO:7-12."""
    seed()
    if not isinstance(body, dict):
        body = {}
    for k in ("studentId", "guardianUserId"):
        if not _is_oid(body.get(k)):
            return 400, f"{k} must be a mongodb id"
    for k, mx in (("subject", 200), ("firstMessage", 4000)):
        v = body.get(k)
        if not isinstance(v, str):
            return 400, f"{k} must be a string"
        if len(v) < 1:
            return 400, f"{k} must be longer than or equal to 1 characters"
        if len(v) > mx:
            return 400, f"{k} must be shorter than or equal to {mx} characters"
    st = S.STUDENTS_BY_ID.get(body["studentId"])
    if not st:
        return 404, "Student not found"  # SPS:290
    if mode == "notteach" or not _teaches(a, st):
        return 403, "You do not teach this student."  # SPS:292
    g = next((x for x in guardians_of(st) if x["userId"] == body["guardianUserId"]), None)
    if mode == "notguardian" or not g:
        return 403, "That person is not a registered guardian of this student."  # SPS:304
    _state["seq"] += 1
    t = _thread(0x7000 + _state["seq"], a, st, g, body["subject"].strip(), body["firstMessage"], minutes=0, g_unread=True)
    _state["threads"][t["_id"]] = t
    m = _msg(t, 0x6000 + _state["seq"], "staff", a["name"], body["firstMessage"].strip())
    _state["messages"][t["_id"]] = [m]
    _state["last_create"] = {"studentId": st["_id"], "guardianUserId": g["userId"], "subject": t["subject"]}
    return 201, dict(t)


def guardian_reply(thread_id, text):
    """Dev control: a guardian answers (not an app endpoint). Mirrors PPS guardian send: a Message + staffHasUnread=true."""
    seed()
    t = _state["threads"].get(thread_id)
    if not t:
        return 404, "Thread not found"
    m = _msg(t, 0x7000 + _state["seq"] + 1, "guardian", t["guardianName"], text)
    _state["seq"] += 1
    m["_id"] = _oid(0xB00 + 0x7000 + _state["seq"])
    _state["messages"].setdefault(thread_id, []).append(m)
    t.update({"lastMessagePreview": text[:140], "lastMessageAt": m["createdAt"], "staffHasUnread": True, "updatedAt": m["createdAt"]})
    return 200, dict(m)


# --------------------------- notifications ---------------------------

def _mine(a):
    seed()
    return _state["notifs"].setdefault(a["id"], [])


def list_notifications(a, q):
    """GET /staff-portal/notifications?limit&before&unread (SPC:34-35 -> SPS:172-189): newest first; limit = clamp(parseInt(limit||30)||30, 1, 100);
    unread=='true' only; `before` = createdAt < new Date(before) (an unparseable date is ignored); fetches limit+1 to know hasMore;
    { items, nextCursor (createdAt of the last item, null at the end), unreadCount (ALL unread, not just this page) }."""
    if a["role"] != "teacher":
        return 403, "Forbidden resource"
    limit = min(max(_js_int((q.get("limit") or [""])[0], 30), 1), 100)
    rows = sorted(_mine(a), key=lambda n: n["createdAt"], reverse=True)
    if (q.get("unread") or [""])[0] == "true":
        rows = [n for n in rows if not n["isRead"]]
    before = (q.get("before") or [""])[0]
    if before:
        d = _parse_date(before)
        if d is not None:
            rows = [n for n in rows if _parse_date(n["createdAt"]) < d]
    has_more = len(rows) > limit
    items = rows[:limit]
    return 200, {"items": [dict(n) for n in items], "nextCursor": items[-1]["createdAt"] if has_more else None,
                 "unreadCount": sum(1 for n in _mine(a) if not n["isRead"])}


def unread_count(a):
    """GET /staff-portal/notifications/unread-count (SPC:37-38 -> SPS:191-195): { unreadCount }."""
    return 200, {"unreadCount": sum(1 for n in _mine(a) if not n["isRead"])}


def read_notification(a, nid):
    """POST /staff-portal/notifications/:id/read (SPC:44-46 -> SPS:197-205): the updated notification; 404 'Notification not found'
    (an id that is not an ObjectId is a Mongoose CastError in the real service: UNVERIFIED what status that gives; the stub answers 404)."""
    for n in _mine(a):
        if n["_id"] == nid:
            n["isRead"] = True
            n["readAt"] = _iso(_now())
            return 200, dict(n)
    return 404, "Notification not found"


def read_all(a):
    """POST /staff-portal/notifications/read-all (SPC:40-42 -> SPS:207-213): { updated } = modifiedCount."""
    c = 0
    for n in _mine(a):
        if not n["isRead"]:
            n["isRead"] = True
            n["readAt"] = _iso(_now())
            c += 1
    return 200, {"updated": c}


def add_notification(a, typ, title, body, entity):
    n = _notif(0x900 + _state["seq"] + 100, a, typ, title, body, dict(seconds=0), entity or None)
    _state["seq"] += 1
    n["_id"] = _next_id(0xD00 + 0x900)
    _mine(a).insert(0, n)
    return 200, dict(n)


# --------------------------- student leaves ---------------------------

def _class_teacher_check(a, mode):
    if a["role"] != "teacher":
        return 403, "Forbidden resource"
    if mode == "notclassteacher" or not a["classTeacher"]:
        return 403, "Only class teachers can review student leave requests."  # SPS:105
    return None


def list_leaves(a, q, mode=""):
    """GET /staff-portal/student-leaves?status&limit (SPC:78-79 -> SPS:327-341): { items }, createdAt desc, limit clamp(parseInt||50, 1, 200),
    status filter only for pending|approved|rejected, students of the class-teacher class (tolerant match)."""
    bad = _class_teacher_check(a, mode)
    if bad:
        return bad
    seed()
    limit = min(max(_js_int((q.get("limit") or [""])[0], 50), 1), 200)
    status = (q.get("status") or [""])[0]
    rows = list(_state["leaves"].values())
    if status in ("pending", "approved", "rejected"):
        rows = [r for r in rows if r["status"] == status]
    rows = sorted(rows, key=lambda r: r["createdAt"], reverse=True)[:limit]
    return 200, {"items": [dict(r) for r in rows]}


def review_leave(a, lid, body, mode=""):
    """PATCH /staff-portal/student-leaves/:id {status, remarks?} (SPC:81-84 -> SPS:343-367): the updated StudentLeave. ReviewStudentLeaveDto
    DTO:14-17. Order of checks as in the service: class teacher (SPS:105), id validity / existence (SPS:347-349), class scope (SPS:351-353),
    already decided -> 409 (SPS:354), then write approverName / approverNote / approvedAt (SPS:355-359); the guardian gets a
    'leave_decision' notification (SPS:360-365, not visible to the teacher)."""
    bad = _class_teacher_check(a, mode)
    if bad:
        return bad
    seed()
    body = body if isinstance(body, dict) else {}
    if body.get("status") not in ("approved", "rejected"):
        return 400, "status must be one of the following values: approved, rejected"
    rem = body.get("remarks")
    if rem is not None and not isinstance(rem, str):
        return 400, "remarks must be a string"
    if isinstance(rem, str) and len(rem) > 1000:
        return 400, "remarks must be shorter than or equal to 1000 characters"
    if not _is_oid(lid):
        return 404, "Leave request not found"
    lv = _state["leaves"].get(lid)
    if not lv:
        return 404, "Leave request not found"
    if mode == "notmyclass":
        return 403, "This student is not in your class."  # SPS:352
    if mode == "decided":
        lv.update({"status": "approved", "approverName": "Clara Classteacher", "approvedAt": _ago(minutes=2)})
    if lv["status"] != "pending":
        return 409, f"This request was already {lv['status']}."  # SPS:354
    lv["status"] = body["status"]
    lv["approverName"] = a["name"]
    note = (rem or "").strip()
    if note:
        lv["approverNote"] = note
    else:
        lv.pop("approverNote", None)
    lv["approvedAt"] = _iso(_now())
    _state["last_review"] = {"id": lid, "status": body["status"], "remarks": note or None}
    return 200, dict(lv)
