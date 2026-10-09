"""Phase 7c stub logic: school calendar + circulars, school events, safeguarding concern (write only), avatar upload, knowledge base, account deletion request.

!! DUMMY DATA ONLY. Lives under tool/dev/, never shipped. Imported by stub_server.py (HTTP routing, auth and the dev mode switches live there).
!! Every function returns (status, body) so tests can call it directly. NOT run against staging/production/MongoDB.

Citation legend (paths relative to eldermin-backend/src/, branch feat/staff-portal, HEAD 265fcfa; read-only). "UNVERIFIED" = cannot be confirmed from code;
every one of them is in PHASE7C_REPORT.md.
  SCC = school-calendar/school-calendar.controller.ts   SCS = school-calendar/school-calendar.service.ts
  CES = school-calendar/schemas/calendar-event.schema.ts CIS = school-calendar/schemas/circular.schema.ts  CAS = .../circular-acknowledgment.schema.ts
  EC  = events/events.controller.ts   ES = events/events.service.ts   EV = events/schemas/event.schema.ts
  CC  = compliance/compliance.controller.ts  CS = compliance/compliance.service.ts  CSC = compliance/schemas/compliance.schema.ts
  AC  = modules/auth/auth.controller.ts  AS = modules/auth/auth.service.ts  UP = upload/upload.service.ts
  KC  = modules/knowledge-base/knowledge-base.controller.ts  KS = .../knowledge-base.service.ts  KSC = .../schemas/kb-article.schema.ts  KU = .../kb-search.util.ts
  SPC = staff-portal/staff-portal.controller.ts  SPS = staff-portal/staff-portal.service.ts  DTO = staff-portal/dto/staff-portal.dto.ts
  FLT = filters/sentry.filter.ts (error body {statusCode,message,timestamp,path}; an array message is cut to its first element)

LEAKS ON PURPOSE (the app must ignore them): GET /school-calendar/events carries a "Fee Due (n invoices)" row with description "Total outstanding: <amount>"
(SCS:91-103) for every role; GET /events/:id carries ticketTypes (prices) and promoCodes (ES:154-162); GET /events and /school-calendar/circulars return drafts,
private events and parent-only circulars to every role (ES:147-152, SCS:190-195).

/__stub/mode features (value: ok|empty|400|403|404|422|500|503|drop|slow):
  calendar GET /school-calendar/events   circulars GET /school-calendar/circulars   circularack POST /school-calendar/circulars/:id/acknowledge
  events GET /events   eventone GET /events/:id   safeguarding POST /compliance/safeguarding   avatar POST /auth/me/avatar (503 = storage not configured, UP + commit 9890ad1)
  kb GET /kb/articles   kbsearch GET /kb/search   kbone GET /kb/articles/:module/:tabKey   deletereq POST /staff-portal/account/delete-request
  special values: calendar=badshape (200 with an object instead of an array), circulars=badshape, events=badshape, kb=badshape
"""
import base64
import datetime
import re
import struct
import zlib

S = None  # the stub_server module, injected by bind()


def bind(mod):
    global S
    S = mod


_state = {"acked": {}, "last_safeguarding": None, "safeguarding_calls": 0, "last_avatar": None, "avatars": {}, "deletions": {}, "seq": 0, "calls": []}


def reset():
    _state.update({"acked": {}, "last_safeguarding": None, "safeguarding_calls": 0, "last_avatar": None, "avatars": {}, "deletions": {}, "seq": 0, "calls": []})
    for a in S.ACCOUNTS.values():
        a.pop("avatarUrl", None)


def state_summary():
    return {"lastSafeguardingKeys": (_state["last_safeguarding"] or {}).get("keys"), "safeguardingCalls": _state["safeguarding_calls"],
            "lastAvatar": _state["last_avatar"], "deletionRequests": {k: v["requestId"] for k, v in _state["deletions"].items()},
            "acked": {k: sorted(v) for k, v in _state["acked"].items()}, "calls": list(_state["calls"][-20:])}


def _today():
    return datetime.date.today()


def _iso(d):
    return d.strftime("%Y-%m-%dT%H:%M:%S.") + f"{d.microsecond // 1000:03d}Z"


def _now_iso():
    return _iso(datetime.datetime.utcnow())


def _midnight(d):
    """A calendar day stored the way the web / this app write it: UTC midnight (the stored instant's UTC y/m/d IS the day)."""
    return f"{d.isoformat()}T00:00:00.000Z"


def _oid(n):
    return f"64c{n:021x}"


def _parse(v):
    """new Date(v): None = Invalid Date."""
    if not isinstance(v, str) or not v:
        return None
    try:
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", v):
            return datetime.datetime.fromisoformat(v)
        return datetime.datetime.fromisoformat(v.replace("Z", "+00:00")).astimezone(datetime.timezone.utc).replace(tzinfo=None)
    except Exception:
        return None


COLORS = {  # CES:15-28 CALENDAR_EVENT_COLORS
    "holiday": "#E24B4A", "exam": "#7F77DD", "event": "#1D9E75", "fee_due": "#EF9F27", "admission_deadline": "#378ADD", "training": "#BA7517",
    "half_day": "#888888", "public_holiday": "#D85A30", "other": "#0C447C", "academic_term": "#008300",
}


# ============================== calendar ==============================

def _manual(n, title, typ, start, end, all_day=True, desc="", grades=(), color=None):
    """One CalendarEvent document, fields CES:30-47 (+ timestamps / __v like a lean() result)."""
    return {"_id": _oid(0x100 + n), "title": title, "description": desc, "type": typ, "color": color, "startDate": start, "endDate": end, "allDay": all_day,
            "campusId": None, "gradeLevels": list(grades), "academicYear": "2026-2027", "createdBy": "Admin (DUMMY)", "schoolSlug": "stub-school",
            "createdAt": "2026-08-01T06:00:00.000Z", "updatedAt": "2026-08-01T06:00:00.000Z", "__v": 0}


def _all_calendar_rows():
    t = _today()
    d = lambda n: t + datetime.timedelta(days=n)
    first = t.replace(day=1)
    nxt = (first + datetime.timedelta(days=32)).replace(day=1)
    rows = [
        _manual(1, "Autumn break", "holiday", _midnight(d(3)), _midnight(d(5)), desc="School closed for three days."),
        _manual(2, "Founders' Day", "public_holiday", _midnight(d(9)), _midnight(d(9))),
        _manual(3, "Staff training: safeguarding refresher", "training", _midnight(d(1)), _midnight(d(1)), all_day=False, desc="Hall B, 14:00 to 16:00 school time.", color="#BA7517"),
        _manual(4, "Half day (parent meetings)", "half_day", _midnight(d(6)), _midnight(d(6))),
        _manual(5, "Sports week", "event", _midnight(d(12)), _midnight(d(16)), grades=["Grade 5", "Grade 6"], desc="Inter-house sports, all grades 5 and 6."),
        _manual(6, "Admission deadline", "admission_deadline", _midnight(nxt + datetime.timedelta(days=4)), _midnight(nxt + datetime.timedelta(days=4))),
        _manual(7, "Parents' evening", "event", _midnight(d(0)), _midnight(d(0))),
        _manual(8, "Science fair", "event", _midnight(nxt + datetime.timedelta(days=10)), _midnight(nxt + datetime.timedelta(days=11))),
    ]
    # timed training: stored as real instants (allDay false): 14:00-16:00 UTC on d(1)
    rows[2]["startDate"] = f"{d(1).isoformat()}T14:00:00.000Z"
    rows[2]["endDate"] = f"{d(1).isoformat()}T16:00:00.000Z"
    # SCS:155-156: color falls back to the type colour, source 'manual'
    rows = [dict(r, color=r["color"] or COLORS[r["type"]], source="manual") for r in rows]
    # exams from Assessments (SCS:117-129): title, description 'mid term - Grade 5 A', source 'assessments'
    rows.append({"_id": "exam-" + _oid(0x300), "title": "Mid-term Mathematics", "description": "mid term - Grade 5 A", "type": "exam", "color": COLORS["exam"],
                 "startDate": _midnight(d(7)), "endDate": _midnight(d(8)), "allDay": True, "campusId": None, "gradeLevels": ["Grade 5"], "source": "assessments"})
    # terms from Academics (SCS:139-150): 'academic_term', source 'academics'
    rows.append({"_id": "term-" + _oid(0x400) + "-" + _oid(0x401), "title": "Term 2 (2026-2027)", "description": "Academic term", "type": "academic_term",
                 "color": COLORS["academic_term"], "startDate": _midnight(first), "endDate": _midnight(nxt + datetime.timedelta(days=20)), "allDay": True,
                 "campusId": None, "gradeLevels": [], "source": "academics"})
    # THE LEAK (SCS:91-103): fee-due rows for every role, with the outstanding total in the description
    for n, off in enumerate((2, 10)):
        day = d(off)
        rows.append({"_id": f"fee-due-{day.isoformat()}", "title": f"Fee Due ({3 + n} invoices)", "description": f"Total outstanding: {845000 + n * 1250}.50",
                     "type": "fee_due", "color": COLORS["fee_due"], "startDate": day.isoformat(), "endDate": day.isoformat(), "allDay": True, "campusId": None,
                     "gradeLevels": [], "source": "finance"})
    return rows


def list_calendar(q, mode=""):
    """SCS:74-161: overlap filter startDate <= to && endDate >= from (SCS:78). Default window = this calendar year (SCS:75-76). Sorted by startDate asc (SCS:160)."""
    if mode == "badshape":
        return 200, {"events": []}
    today = _today()
    frm = _parse((q.get("from") or [""])[0]) or datetime.datetime(today.year, 1, 1)
    to = _parse((q.get("to") or [""])[0]) or datetime.datetime(today.year, 12, 31)
    out = []
    for r in _all_calendar_rows():
        s, e = _parse(r["startDate"]), _parse(r["endDate"])
        if s is None or e is None:
            continue
        if s <= to and e >= frm:
            out.append(r)
    out.sort(key=lambda r: _parse(r["startDate"]))
    return 200, out


# ============================== circulars ==============================

def _circ(n, title, body, status="published", roles=("parent", "staff"), scope="school", category="administrative", priority="normal", ack=False,
          campus=None, staff_ids=(), published_days_ago=1, attachments=()):
    """One Circular document, fields CIS:29-46 (+ audience subdocument CIS:18-26)."""
    pub = datetime.datetime.utcnow() - datetime.timedelta(days=published_days_ago)
    return {"_id": _oid(0x500 + n), "title": title, "body": body, "attachmentUrls": list(attachments), "category": category, "priority": priority,
            "audience": {"roles": list(roles), "scope": scope, "campusId": campus, "gradeLevels": [], "individualStudentIds": [], "individualStaffIds": list(staff_ids), "userIds": []},
            "requiresAcknowledgment": ack, "status": status, "publishedAt": _iso(pub) if status == "published" else None, "recipientCount": 120 if status == "published" else 0,
            "createdBy": "Admin (DUMMY)", "schoolSlug": "stub-school", "createdAt": _iso(pub - datetime.timedelta(hours=2)), "updatedAt": _iso(pub), "__v": 0}


def _circulars(a):
    """The list endpoint returns EVERY status and audience (SCS:190-195); only some are for a teacher. Order: createdAt DESC (SCS:194)."""
    mine = a["staffId"]
    rows = [
        _circ(1, "Staff meeting moved to Thursday", "<p>The weekly <strong>staff meeting</strong> moves to <em>Thursday 15:30</em>.</p><ul><li>Room: Library</li><li>Bring your mark sheets</li></ul>"
              "<p>Agenda: <a href=\"https://example.test/agenda\">see the agenda</a>.</p>", roles=("staff",), category="administrative", ack=True, published_days_ago=0),
        _circ(2, "Fire drill on Wednesday", "<p>There will be a fire drill at 10:00.</p><script>alert('x')</script><img src=\"https://tracker.example.test/p.png\" onerror=\"alert(1)\">"
              "<p>Please read the <a href=\"javascript:alert(1)\">notice</a> and the <a href=\"https://example.test/evac\">evacuation plan</a>.</p>",
              roles=("parent", "staff"), category="emergency", priority="urgent", ack=True, published_days_ago=2, attachments=["https://files.example.test/evac-plan.pdf"]),
        _circ(3, "Library hours this term", "<p>The library is open 08:00 to 15:00.</p>", roles=("parent", "staff", "student"), category="academic", published_days_ago=5),
        _circ(4, "Term fee reminder (PARENTS ONLY)", "<p>Fees are due on the 10th.</p>", roles=("parent",), category="fee", published_days_ago=3),
        _circ(5, "Draft: exam timetable", "<p>Not ready yet.</p>", status="draft", roles=("staff",), category="academic"),
        _circ(6, "Scheduled: holiday notice", "<p>Goes out next week.</p>", status="scheduled", roles=("staff",), category="administrative"),
        _circ(7, "Written for another campus", "<p>Other campus only.</p>", roles=("staff",), scope="campus", campus="64a0000000000000000000d9", published_days_ago=4),
        _circ(8, "Just for you: timetable change", "<p>Your Tuesday cover moved to period 4.</p>", roles=("staff",), scope="individual", staff_ids=[mine], category="academic", published_days_ago=1),
        _circ(9, "Written for someone else", "<p>Not for you.</p>", roles=("staff",), scope="individual", staff_ids=["64a0000000000000000000ff"], published_days_ago=1),
    ]
    rows.sort(key=lambda r: r["createdAt"], reverse=True)
    return rows


def list_circulars(a, q, mode=""):
    if mode == "badshape":
        return 200, {"data": []}
    rows = _circulars(a)
    st = (q.get("status") or [""])[0]
    cat = (q.get("category") or [""])[0]
    if st:
        rows = [r for r in rows if r["status"] == st]
    if cat:
        rows = [r for r in rows if r["category"] == cat]
    lim = int((q.get("limit") or ["0"])[0] or 0) or 100
    return 200, rows[:lim]


def acknowledge(a, cid, mode=""):
    """SCC:105-109 -> SCS:283-291: 404 'Circular not found' (SCS:285); otherwise an idempotent upsert keyed (circularId, userId); answers the ack document (CAS:6-13)."""
    if cid not in {r["_id"] for r in _circulars(a)}:
        return 404, "Circular not found"
    mine = _state["acked"].setdefault(a["id"], set())
    mine.add(cid)
    ts = _now_iso()
    return 201, {"_id": _oid(0x600), "circularId": cid, "userId": a["id"], "userName": a["name"], "acknowledgedAt": ts, "schoolSlug": "stub-school",
                 "createdAt": ts, "updatedAt": ts, "__v": 0}


# ============================== events ==============================

def _event(n, title, category, sessions, status="published", visibility="public", venue="Main Hall", desc="", **kw):
    """One Event document, fields EV:43-68."""
    e = {"_id": _oid(0x700 + n), "title": title, "description": desc, "category": category, "campusId": None, "venueName": venue, "venueAddress": "1 School Road (DUMMY)",
         "sessions": [{"_id": _oid(0x800 + n * 10 + i), "label": lab, "startAt": s, "endAt": e_, "capacity": 200} for i, (lab, s, e_) in enumerate(sessions)],
         "theme": {"primaryColor": "#0C447C"}, "sponsors": [{"_id": _oid(0x900 + n), "name": "Sponsor (DUMMY)", "tier": "gold", "sortOrder": 0}],
         "slug": f"event-{n}", "visibility": visibility, "status": status, "createdBy": "Admin (DUMMY)", "schoolSlug": "stub-school",
         "createdAt": f"2026-09-{10 + n:02d}T06:00:00.000Z", "updatedAt": "2026-09-20T06:00:00.000Z", "__v": 0}
    e.update(kw)
    return e


def _events():
    t = _today()
    at = lambda days, h, m=0: _iso(datetime.datetime(t.year, t.month, t.day, h, m) + datetime.timedelta(days=days))
    return [
        _event(1, "Annual Day", "annual_day", [("Day 1", at(10, 9), at(10, 12)), ("Day 2", at(11, 9), at(11, 11, 30))],
               desc="<p>Our <b>annual day</b> with performances by every grade.</p><p>More: <a href=\"https://example.test/annual\">programme</a></p><script>steal()</script>"),
        _event(2, "Open house", "open_house", [("Open house", at(4, 10), at(4, 13))], visibility="internal", venue="Reception", desc="<p>Welcome for new families.</p>"),
        _event(3, "Graduation ceremony", "graduation", [("Ceremony", at(-20, 10), at(-20, 12))], status="completed", desc="<p>Done.</p>"),
        _event(4, "Charity fun run", "fundraiser", [("Run", at(7, 8), at(7, 10))], status="cancelled", venue="Sports field", desc="<p>Cancelled because of the weather forecast.</p>"),
        _event(5, "DRAFT: teacher awards night", "other", [("Evening", at(30, 18), at(30, 20))], status="draft"),
        _event(6, "Private board dinner", "other", [("Dinner", at(15, 19), at(15, 22))], visibility="private"),
        _event(7, "Unlisted pilot workshop", "workshop", [("Workshop", at(8, 14), at(8, 16))], visibility="unlisted"),
        _event(8, "Parent workshop (date to be confirmed)", "workshop", [], desc="<p>Date to be confirmed.</p>"),
    ]


def list_events(mode=""):
    """EC:17-21 -> ES:147-152: EVERY event of the school (drafts too), newest created first, bare array. UNVERIFIED: how/if `internal` events reach teachers."""
    if mode == "badshape":
        return 200, {"events": []}
    return 200, sorted(_events(), key=lambda e: e["createdAt"], reverse=True)


def get_event(eid):
    """ES:154-162: 404 'Event not found'; the event + ticketTypes + promoCodes (THE LEAK: prices and codes)."""
    for e in _events():
        if e["_id"] == eid:
            return 200, dict(e, ticketTypes=[{"_id": _oid(0xa00), "eventId": eid, "name": "General", "price": 2500, "capacity": 200, "isActive": True, "sortOrder": 0}],
                             promoCodes=[{"_id": _oid(0xb00), "eventId": eid, "code": "STAFF50", "discountType": "percent", "discountValue": 50}])
    return 404, "Event not found"


# ============================== safeguarding ==============================

SG_TYPES = ["physical", "emotional", "sexual", "neglect", "bullying", "cyberbullying", "radicalisation", "other"]  # CSC:71-76
SG_SEVERITIES = ["low", "medium", "high", "critical"]  # CSC:77


def create_safeguarding(a, body, mode=""):
    """CC:112-118 -> CS:251-258: the WHOLE body is spread into the new case (mass assignment): `{...dto, schoolSlug, reportedBy: dto.reportedBy || userName}`,
    reportedDate = new Date(dto.reportedDate || Date.now()), campusId from the user. Required by the schema: title, description, type (enum), reportedDate, caseNumber
    (generated: 'SC-<year>-<100-999>', CSC:113-119). A Mongoose ValidationError's HTTP status is UNVERIFIED (400 here). The stub records the KEYS it received."""
    _state["safeguarding_calls"] += 1
    keys = sorted(body.keys()) if isinstance(body, dict) else []
    _state["last_safeguarding"] = {"keys": keys}
    if not isinstance(body, dict):
        body = {}
    problems = []
    if not str(body.get("title") or "").strip():
        problems.append("Path `title` is required.")
    if not str(body.get("description") or "").strip():
        problems.append("Path `description` is required.")
    if body.get("type") not in SG_TYPES:
        problems.append("Path `type` is required." if not body.get("type") else f"`{body.get('type')}` is not a valid enum value for path `type`.")
    if body.get("severity") is not None and body.get("severity") not in SG_SEVERITIES:
        problems.append(f"`{body.get('severity')}` is not a valid enum value for path `severity`.")
    if problems:
        return 400, "SafeguardingCase validation failed: " + ", ".join(problems)  # message text UNVERIFIED (Mongoose); status UNVERIFIED
    _state["seq"] += 1
    n = 100 + (_state["seq"] * 37) % 900
    case = dict(body)
    case.update({"_id": _oid(0xc00 + _state["seq"]), "caseNumber": f"SC-{_today().year}-{n}", "schoolSlug": "stub-school", "reportedBy": body.get("reportedBy") or a["name"],
                 "reportedDate": _midnight(_parse(body.get("reportedDate")).date()) if _parse(body.get("reportedDate")) else _now_iso(), "status": "open",
                 "campusId": a["campus"]["id"], "confidential": False, "attachments": [], "progressNotes": [], "createdAt": _now_iso(), "updatedAt": _now_iso(), "__v": 0})
    case.setdefault("severity", "medium")
    return 201, case


# ============================== avatar ==============================

def _png(size=96):
    """A small solid-colour PNG (pure python): the 'uploaded' dummy picture the stub serves back."""
    rows = b""
    for y in range(size):
        row = b"\x00"
        for x in range(size):
            row += bytes((37 + x, 110 + y // 2, 170 - x // 2))
        rows += row
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")


AVATAR_PNG = _png()
MAX_FILE = 10 * 1024 * 1024  # UP MAX_FILE_SIZE


def parse_multipart_avatar(content_type, raw):
    """(field names, filename, size) of the multipart body; the real route is FileInterceptor('avatar') (AC:54-58)."""
    m = re.search(r'boundary=([^;\s]+)', content_type or "")
    if not m:
        return None
    boundary = ("--" + m.group(1).strip('"')).encode()
    out = {"fields": [], "filename": None, "size": 0, "contentType": None}
    for part in raw.split(boundary):
        if b"content-disposition" not in part.lower():
            continue
        head, _, data = part.partition(b"\r\n\r\n")
        h = head.decode("latin-1")
        name = re.search(r'\bname="([^"]*)"', h)
        out["fields"].append(name.group(1) if name else "")
        fn = re.search(r'filename="([^"]*)"', h)
        if fn:
            out["filename"] = fn.group(1)
            out["size"] = max(0, len(data) - 2)
            ct = re.search(r"content-type:\s*([^\r\n]+)", h, re.I)
            out["contentType"] = ct.group(1).strip() if ct else None
    return out


def upload_avatar(a, content_type, raw, base_url):
    """AC:54-58 -> AS:330-339 -> UP uploadFile: 400 'No file provided' (no `avatar` file), 400 'File too large. Max 10MB allowed.', else `{ avatarUrl }`.
    (503 is produced by the mode gate: UP + commit 9890ad1.) The route has NO type filter (UNVERIFIED for non-images: the app never sends them)."""
    info = parse_multipart_avatar(content_type, raw)
    _state["last_avatar"] = {"fields": (info or {}).get("fields"), "filename": (info or {}).get("filename"), "size": (info or {}).get("size"), "contentType": (info or {}).get("contentType")}
    if not info or "avatar" not in info["fields"] or not info["filename"]:
        return 400, "No file provided"
    if info["size"] > MAX_FILE:
        return 400, "File too large. Max 10MB allowed."
    _state["seq"] += 1
    url = f"{base_url}/__stub/avatar-{a['id'][-2:]}-{_state['seq']}.png"
    a["avatarUrl"] = url
    return 201, {"avatarUrl": url}


# ============================== knowledge base ==============================

def _kb():
    """KbArticle documents, fields KSC:17-43. The first three are COPIED from seed/seed-kb-articles.ts (hrArticles, lines 27-48); the rest are DUMMY articles
    (markdown, and one adversarial body with HTML/script/image/javascript: links to prove the app renders inert text)."""
    now = "2026-09-01T00:00:00.000Z"
    base = {"createdAt": now, "updatedAt": now, "__v": 0}
    rows = [
        dict(module="hr", tabKey="dashboard", order=1, title="Dashboard", tagline="Your morning read on the whole staff — who's in, who's owed, what needs a decision today.",
             body="Every time you open Staff & HR, this is the screen you land on. It pulls live numbers from every other tab, so there is nothing to refresh and nothing to configure before it means something.",
             steps=["Check the top row first: Present / On Leave / Payroll / Onboarding / Open Positions tell you if today is normal before you dig deeper.",
                    "Use the six Quick Action tiles for the tasks you repeat daily — Add Employee, Mark Attendance, Process Payroll, Apply Leave.",
                    "Export pulls the same numbers into a spreadsheet for a board pack or a campus meeting."]),
        dict(module="hr", tabKey="employees", order=2, title="Employees", tagline="The single source of truth for every person on payroll — one record, every campus.",
             body="This is the master directory. Every other HR tab (payroll, leave, contracts, exit) reads from the record you create here, so getting a hire right in Employees means you never re-type their name again.",
             steps=["Click + Add Employee for a single new hire.", "To change anything about an existing employee, open their profile and click Edit, not a new enrollment."]),
        dict(module="hr", tabKey="leave", order=7, title="Leave", tagline="The approval workflow for time off.",
             body="Leave is the approval workflow for time off. Balances shown here are live — they update the moment a leave request is approved.", steps=[]),
        dict(module="general", tabKey="getting-started", order=1, title="Getting started (DUMMY)", tagline="A short tour of the app.",
             body="# Welcome\n\nThis app helps you with **attendance**, homework and messages.\n\n- Mark attendance from the Attendance tab\n- Message guardians from Messages\n\nRead more at [the school site](https://example.test/help).\n\n1. Open More\n2. Choose Help",
             steps=["Sign in with your school email.", "Open the Classes tab to see your students."]),
        dict(module="general", tabKey="adversarial", order=2, title="Safe rendering check (DUMMY)", tagline="Markup must never run.",
             body="<h1>Heading</h1><p>Text with <b>bold</b> and a <a href=\"javascript:alert(1)\">bad link</a> and a <a href=\"https://example.test/ok\">good link</a>.</p>"
                  "<script>alert('xss')</script><iframe src=\"https://evil.example.test\"></iframe><img src=\"https://tracker.example.test/x.png\" onerror=\"alert(2)\">"
                  "\n\n![remote](https://tracker.example.test/pixel.png)\n\n[click](javascript:alert(3))",
             steps=["Step with <i>markup</i>."]),
    ]
    return [dict(r, **base, _id=_oid(0xd00 + i)) for i, r in enumerate(rows)]


def kb_list(q, mode=""):
    """KC:24-27 -> KS:46-50: sorted by `order` ascending, optional module filter, bare array (global content, no tenant filter)."""
    if mode == "badshape":
        return 200, {"articles": []}
    mod = (q.get("module") or [""])[0]
    rows = [r for r in _kb() if not mod or r["module"] == mod]
    rows.sort(key=lambda r: r["order"])
    return 200, rows


def kb_search(q, mode=""):
    """KC:30-33 -> KS:61-67 + KU: trimmed lowercase substring over title, tagline, body, steps; blank q -> []. Sorted module asc, order asc."""
    needle = ((q.get("q") or [""])[0] or "").strip().lower()
    if not needle:
        return 200, []
    out = []
    for r in _kb():
        hay = [r["title"], r["tagline"], r["body"]] + r["steps"]
        if any(needle in h.lower() for h in hay):
            out.append(r)
    out.sort(key=lambda r: (r["module"], r["order"]))
    return 200, out


def kb_one(module, tab_key):
    """KC:36-39 -> KS:53-59: 404 'No KB article found for <module>/<tabKey>'."""
    for r in _kb():
        if r["module"] == module and r["tabKey"] == tab_key:
            return 200, r
    return 404, f"No KB article found for {module}/{tab_key}"


# ============================== account deletion request ==============================

def delete_request(a, body, mode=""):
    """SPC:103-105 (201) -> SPS:410-436 + DTO:30-33. Order of checks: DTO validation (class-validator, the global ValidationPipe is assumed: UNVERIFIED) -> `!dto.confirm`
    400 'Please confirm the request.' (SPS:411) -> requireStaff -> an existing pending request returns `{requestId, status:'pending', alreadyRequested:true}` (SPS:415-416)
    else creates one and returns `{requestId, status:'pending', message}` (SPS:430-433)."""
    if a["role"] != "teacher":
        return 403, "Forbidden resource"  # the controller @Roles list (SPC:6-14) includes principal etc.; the stub only models teachers
    body = body if isinstance(body, dict) else {}
    if "confirm" in body and not isinstance(body["confirm"], bool):
        return 400, "confirm must be a boolean value"
    if "reason" in body and body["reason"] is not None and not isinstance(body["reason"], str):
        return 400, "reason must be a string"
    if isinstance(body.get("reason"), str) and len(body["reason"]) > 1000:
        return 400, "reason must be shorter than or equal to 1000 characters"
    if "confirm" not in body:
        return 400, "confirm must be a boolean value"  # @IsBoolean on a missing field
    if not body["confirm"]:
        return 400, "Please confirm the request."
    existing = _state["deletions"].get(a["id"])
    if existing:
        return 201, {"requestId": existing["requestId"], "status": "pending", "alreadyRequested": True}
    _state["seq"] += 1
    rid = _oid(0xe00 + _state["seq"])
    _state["deletions"][a["id"]] = {"requestId": rid, "reason": body.get("reason")}
    return 201, {"requestId": rid, "status": "pending", "message": "Your request was sent to the school administration. Your records are retained until they process it."}
