#!/usr/bin/env python3
"""Dev-only: writes the stub's Home response bodies to test/fixtures/home/*.json so the Dart parser
tests run against the EXACT shapes the stub serves (which mirror the shapes doc). DUMMY data."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s

out = os.path.join(os.path.dirname(__file__), "..", "..", "test", "fixtures", "home")
os.makedirs(out, exist_ok=True)
t = s.ACCOUNTS["teacher"]; c = s.ACCOUNTS["classteacher"]
s._attendance["count"] = 27
files = {
    "timetable.json": s.timetable_docs(t["staffId"], t["name"]),
    "roster.json": s.roster_diagnostic("Grade 5", "A"),
    "attendance_list.json": s.attendance_list("Grade 5", "A", 1),
    "assignments.json": s.assignments(t["staffId"]),
    "submissions.json": s.submissions("64f000000000000000000301"),
    "lesson_plans.json": s.lesson_plans(t["staffId"], ""),
    "ptm_upcoming.json": s.upcoming_ptms(t["staffId"]),
    "fixtures_covering.json": s.fixtures(t["staffId"], "", ""),
    "fixtures_covered.json": s.fixtures(c["staffId"], "", ""),
    "threads.json": s.threads(t["staffId"]),
    "unread_count.json": s.unread_count(),
}
for name, body in files.items():
    with open(os.path.join(out, name), "w") as f:
        json.dump(body, f, indent=1)
print("wrote", len(files), "fixtures to", os.path.normpath(out))
