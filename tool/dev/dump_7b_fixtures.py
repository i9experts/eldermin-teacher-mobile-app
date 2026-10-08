#!/usr/bin/env python3
"""Dev-only: writes the stub's Phase 7b response bodies to test/fixtures/phase7b/*.json so the Dart parser tests run against the EXACT shapes the
stub serves (which mirror the backend code, see the citations in stub_7b.py). DUMMY data only. Dates are relative to the day it is run: the tests
assert structure, never a calendar date.
Run: TZ=UTC python3 tool/dev/dump_7b_fixtures.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_7b as p

out = os.path.join(os.path.dirname(__file__), "..", "..", "test", "fixtures", "phase7b")
os.makedirs(out, exist_ok=True)
t, ct = s.ACCOUNTS["teacher"], s.ACCOUNTS["classteacher"]
p.reset()
p.seed()
meetings = p.list_meetings(t, {"teacherId": [t["staffId"]]})[1]
done = next(m for m in meetings if m["status"] == "completed")
files = {
    "ptm_list.json": meetings,
    "ptm_completed.json": p.get_meeting(t, done["_id"])[1],
    "ptm_history.json": p.student_history(t, done["studentId"])[1],
    "fixtures.json": p.list_fixtures(t, {"teacherId": [t["staffId"]]})[1],
    "leave_balance.json": p.leave_balance(t)[1],
    "leave_balance_nopolicy.json": p.leave_balance(ct)[1],
    "leave_history.json": p.leave_history(t)[1],
}
for name, data in files.items():
    with open(os.path.join(out, name), "w") as f:
        json.dump(data, f, indent=1)
print("wrote", len(files), "fixtures to", os.path.normpath(out))
