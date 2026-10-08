#!/usr/bin/env python3
"""Dev-only: writes the stub's Phase 7a response bodies to test/fixtures/phase7a/*.json so the Dart parser tests run against the EXACT shapes
the stub serves (which mirror the backend code, see the citations in stub_7a.py). DUMMY data only.
Run: TZ=UTC python3 tool/dev/dump_7a_fixtures.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_7a as p

out = os.path.join(os.path.dirname(__file__), "..", "..", "test", "fixtures", "phase7a")
os.makedirs(out, exist_ok=True)
t, ct = s.ACCOUNTS["teacher"], s.ACCOUNTS["classteacher"]
p.reset()
p.seed()
threads = p.list_threads(t, {})[1]
tid = next(x for x in threads["items"] if x["staffHasUnread"] and x["status"] == "open")["_id"]
page1 = p.list_notifications(ct, {"limit": ["10"]})[1]
st5 = next(x for x in s.STUDENTS if x["currentGrade"] == "Grade 5" and x["currentSection"] == "A" and x["currentRollNumber"] == "2")
files = {
    "threads.json": threads,
    "thread_messages.json": p.thread_messages(t, tid)[1],
    "guardians.json": p.list_guardians(t, st5["_id"])[1],
    "notifications_page1.json": page1,
    "notifications_page2.json": p.list_notifications(ct, {"limit": ["10"], "before": [page1["nextCursor"]]})[1],
    "student_leaves.json": p.list_leaves(ct, {})[1],
}
for name, data in files.items():
    with open(os.path.join(out, name), "w") as f:
        json.dump(data, f, indent=1)
print("wrote", len(files), "fixtures to", os.path.normpath(out))
