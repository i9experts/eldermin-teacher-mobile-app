#!/usr/bin/env python3
"""Dev-only: writes the stub's Phase 6b response bodies to test/fixtures/phase6b/*.json so the Dart parser tests run against the
EXACT shapes the stub serves (which mirror the backend code, see the citations in stub_6b.py). DUMMY data only.
Run: TZ=UTC python3 tool/dev/dump_6b_fixtures.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_6b as p

out = os.path.join(os.path.dirname(__file__), "..", "..", "test", "fixtures", "phase6b")
os.makedirs(out, exist_ok=True)
t = s.ACCOUNTS["teacher"]
p.reset()
p.seed()
a1 = next(a for a in p._state["assessments"].values() if a["title"].startswith("Unit Test 1"))
mid = next(a for a in p._state["assessments"].values() if a["title"].startswith("Mid-Term"))
att = p.list_attempts(t, {})[1]
pend = next(a for a in att if a["section"] == "A" and a["subject"] == "Mathematics")
files = {
    "assessments.json": p.list_assessments(t, {"limit": ["100"]})[1],
    "marks_unit_test.json": p.list_marks(t, {"assessmentId": [a1["_id"]], "subject": ["Mathematics"], "limit": ["200"]})[1],
    "marks_mid_term.json": p.list_marks(t, {"assessmentId": [mid["_id"]], "subject": ["Mathematics"], "limit": ["200"]})[1],
    "report_cards.json": p.list_report_cards(t, {"assessmentId": [mid["_id"]], "limit": ["100"]})[1],
    "quiz_attempts.json": att,
    "quiz_attempt_detail.json": p.get_attempt(t, pend["_id"])[1],
    "curricula.json": p.list_curricula(t, {})[1],
    "books.json": p.list_books(t, {"limit": ["100"]})[1],
}
for name, data in files.items():
    with open(os.path.join(out, name), "w") as f:
        json.dump(data, f, indent=1)
print("wrote", len(files), "fixtures to", os.path.normpath(out))
