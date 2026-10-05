#!/usr/bin/env python3
"""Dev-only: writes the stub's Phase 5a response bodies to test/fixtures/classroom/*.json so the Dart parser
tests run against the EXACT shapes the stub serves (which mirror the backend code, see the citations in stub_server.py).
DUMMY data only. Run: TZ=UTC python3 tool/dev/dump_classroom_fixtures.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s

out = os.path.join(os.path.dirname(__file__), "..", "..", "test", "fixtures", "classroom")
os.makedirs(out, exist_ok=True)
ct = s.ACCOUNTS["classteacher"]
s.set_today_attendance(0)
roster = s._roster_5a()
_, students = s.students_list({"grade": ["5", "Grade 5"], "section": ["A", "a"], "status": ["active"], "limit": ["200"]}, ct)
_, att = s.attendance_list_real(ct, {"grade": ["Grade 5"], "section": ["A"], "limit": ["40"]})
_, bulk = s.attendance_bulk(ct, {"records": [{"studentId": roster[0]["_id"], "studentName": "X", "grade": "Grade 5", "section": "A",
                                              "date": "2026-10-05T12:00:00.000Z", "status": "present"}]}, "2026-27")
s.seed_attendance(0)
_, d360 = s.student_360(roster[2]["_id"])  # roll 3 = the one with a duplicate guardian row
files = {
    "students_list.json": students,
    "grades_sections.json": s.grades_sections(),
    "student_360.json": d360,
    "attendance_list.json": att,
    "attendance_summary.json": s.attendance_summary(roster[0]["_id"], ""),
    "bulk_result.json": bulk,
    "staff_me_classteacher.json": s.staff_me(ct),
    "staff_me_teacher.json": s.staff_me(s.ACCOUNTS["teacher"]),
}
for name, body in files.items():
    with open(os.path.join(out, name), "w") as f:
        json.dump(body, f, indent=1)
print("wrote", len(files), "fixtures to", os.path.normpath(out))
