#!/usr/bin/env python3
"""Dev-only: writes the stub's Phase 6a response bodies to test/fixtures/phase6a/*.json so the Dart parser tests run
against the EXACT shapes the stub serves (which mirror the backend code, see the citations in stub_6a.py).
DUMMY data only. Run: TZ=UTC python3 tool/dev/dump_6a_fixtures.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_6a as p

out = os.path.join(os.path.dirname(__file__), "..", "..", "test", "fixtures", "phase6a")
os.makedirs(out, exist_ok=True)
t = s.ACCOUNTS["teacher"]
p.reset()
_, plans = p.list_plans(t, {})  # unfiltered: includes the legacy profile-id row and a colleague row
b = "x"
body = (f'--{b}\r\nContent-Disposition: form-data; name="file"; filename="plan.docx"\r\nContent-Type: application/octet-stream\r\n\r\n'
        + "x" * 60 + f"\r\n--{b}--\r\n").encode()
_, parsed = p.parse_upload(t, f"multipart/form-data; boundary={b}", body)
_, created = p.create_plan(t, {"teacherId": t["staffId"], "subject": "Mathematics", "gradeLevel": "Grade 5", "sectionName": "A",
                               "topic": "New", "planDate": "2030-01-05", "objectives": ["a"], "status": "draft"})
_, syl = p.list_syllabi(t, {"teacherId": [t["staffId"]]})
syl_all = json.loads(json.dumps(p.list_syllabi(t, {})[1]))
syl = json.loads(json.dumps(syl))  # snapshot BEFORE the mark below mutates the stub state
plans = json.loads(json.dumps(plans))
maths = next(d for d in syl if d["subjectName"] == "Mathematics")
_, marked = p.mark_sub_topic(t, maths["_id"], {"unitNo": 1, "topicNo": 1, "subTopicNo": 3, "isCovered": True, "coveredBy": "Tess Teacher"})
p.reset()
_, planner = p.weekly_planner(t, {"teacherId": [t["staffId"]]})
files = {"lesson_plans.json": plans, "parse_upload.json": parsed, "lesson_plan_created.json": created, "syllabi.json": syl, "syllabi_all.json": syl_all,
         "syllabus_marked.json": marked, "weekly_planner.json": planner}
for name, data in files.items():
    with open(os.path.join(out, name), "w") as f:
        json.dump(data, f, indent=1)
print("wrote", len(files), "fixtures to", os.path.normpath(out))
