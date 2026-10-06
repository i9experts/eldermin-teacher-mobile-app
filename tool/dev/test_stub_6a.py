#!/usr/bin/env python3
"""Tests for the Phase 6a stub (lesson plans, syllabus tracking): the contract the Dart repositories rely on.
Run: python3 tool/dev/test_stub_6a.py"""
import http.client
import json
import os
import sys
import threading
import unittest
import uuid
from http.server import ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_6a as p

T = s.ACCOUNTS["teacher"]


def multipart(fields=None, file=None):
    """file = (field, filename, bytes)."""
    b = uuid.uuid4().hex
    out = b""
    for k, v in (fields or {}).items():
        out += f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    if file:
        f, name, data = file
        out += f'--{b}\r\nContent-Disposition: form-data; name="{f}"; filename="{name}"\r\nContent-Type: application/octet-stream\r\n\r\n'.encode() + data + b"\r\n"
    out += f"--{b}--\r\n".encode()
    return f"multipart/form-data; boundary={b}", out


class LessonPlans(unittest.TestCase):
    def setUp(self):
        p.reset()

    def valid(self, **kw):
        d = {"teacherId": T["staffId"], "subject": "Mathematics", "gradeLevel": "Grade 5", "sectionName": "A", "topic": "T",
             "planDate": "2030-01-05", "objectives": ["a"], "status": "draft"}
        d.update(kw)
        return d

    def test_list_filters_sorts_and_limits(self):
        st, rows = p.list_plans(T, {"teacherId": [T["staffId"]]})
        self.assertEqual(st, 200)
        self.assertTrue(all(r["teacherId"] == T["staffId"] for r in rows))
        self.assertEqual([r["planDate"] for r in rows], sorted((r["planDate"] for r in rows), reverse=True))
        st, rej = p.list_plans(T, {"teacherId": [T["staffId"]], "status": ["rejected"]})
        self.assertEqual([r["topic"][:9] for r in rej], ["Fractions"])
        self.assertEqual(p.list_plans(T, {"teacherId": ["nope"]})[0], 500)
        self.assertIn(s.OTHER_STAFF, {r["teacherId"] for r in p.list_plans(T, {})[1]})  # no owner scoping without teacherId

    def test_stale_rejection_reason_survives_on_submitted(self):
        rows = p.list_plans(T, {"status": ["submitted"], "teacherId": [T["staffId"]]})[1]
        self.assertTrue(any("rejectionReason" in r for r in rows))

    def test_create_derives_teacher_and_renames_objectives(self):
        st, d = p.create_plan(T, self.valid(teacherId=T["teacherProfileId"], status="submitted"))
        self.assertEqual(st, 201)
        self.assertEqual(d["teacherId"], T["staffId"])  # profile id normalised to Staff (TID:61-65)
        self.assertEqual(d["learningObjectives"], ["a"])
        self.assertNotIn("objectives", d)
        self.assertEqual(d["planDate"], "2030-01-05T00:00:00.000Z")
        self.assertEqual(d["status"], "submitted")

    def test_create_other_teacher_is_403(self):
        self.assertEqual(p.create_plan(T, self.valid(teacherId=s.OTHER_STAFF)), (403, "You can only create lesson plans for yourself"))

    def test_create_validation_mongoose_messages(self):
        st, m = p.create_plan(T, self.valid(topic=""))
        self.assertEqual(st, 400)
        self.assertIn("Path `topic` is required", m)
        self.assertEqual(p.create_plan(T, self.valid(status="bogus"))[0], 400)
        self.assertEqual(p.create_plan(T, self.valid(planDate="tomorrow"))[0], 400)

    def test_create_is_not_whitelisted_status_can_be_set(self):
        st, d = p.create_plan(T, self.valid(status="approved"))
        self.assertEqual(d["status"], "approved")  # UI-gating only: documented hazard

    def test_patch_raw_set_drops_unknown_paths_and_keeps_rejection_reason(self):
        pid = [r for r in p.list_plans(T, {"status": ["rejected"]})[1]][0]["_id"]
        st, d = p.update_plan(T, pid, {"status": "submitted", "objectives": ["lost"], "topic": "New"})
        self.assertEqual(st, 200)
        self.assertEqual(d["status"], "submitted")
        self.assertIn("rejectionReason", d)  # never cleared
        self.assertNotEqual(d["learningObjectives"], ["lost"])
        self.assertEqual(p._state["last_patch"]["dropped"], ["objectives"])

    def test_patch_unknown_id_is_200_empty_and_foreign_is_403(self):
        self.assertEqual(p.update_plan(T, s._oid(0x1), {"topic": "x"}), (200, None))
        foreign = [r for r in p.list_plans(T, {})[1] if r["teacherId"] == s.OTHER_STAFF][0]["_id"]
        self.assertEqual(p.update_plan(T, foreign, {"topic": "x"})[0], 403)

    def test_patch_cannot_change_tenant_or_campus_and_teacher_only_to_me(self):
        pid = p.list_plans(T, {"teacherId": [T["staffId"]]})[1][0]["_id"]
        st, d = p.update_plan(T, pid, {"tenantId": "x", "campusId": "y"})
        self.assertEqual(d["tenantId"], s._oid(0xa1))
        self.assertEqual(p.update_plan(T, pid, {"teacherId": s.OTHER_STAFF})[0], 403)

    def test_parse_upload_cases(self):
        ct, b = multipart(file=("file", "plan.docx", b"x" * 60))
        st, d = p.parse_upload(T, ct, b)
        self.assertEqual(st, 200)
        self.assertEqual(d["sourceFileName"], "plan.docx")
        for k in ("topic", "description", "durationMins", "teachingMethodology", "objectives", "resources", "otherResource", "homework",
                  "subjectGuess", "gradeLevelGuess", "warnings", "sourceFileName"):
            self.assertIn(k, d)
        self.assertEqual(p.parse_upload(T, *multipart(file=("file", "plan.pdf", b"x" * 60)))[0], 400)
        self.assertIn("PDF", p.parse_upload(T, *multipart(file=("file", "plan.pdf", b"x" * 60)))[1])
        self.assertIn(".docx", p.parse_upload(T, *multipart(file=("file", "plan.doc", b"x" * 60)))[1])
        self.assertIn("Unsupported", p.parse_upload(T, *multipart(file=("file", "plan.png", b"x" * 60)))[1])
        self.assertIn("readable text", p.parse_upload(T, *multipart(file=("file", "plan.txt", b"short")))[1])
        self.assertEqual(p.parse_upload(T, *multipart(file=("file", "big.docx", b"x" * (p.MAX_UPLOAD + 1)))), (413, "File too large"))
        self.assertEqual(p.parse_upload(T, *multipart(file=("avatar", "a.docx", b"x" * 60)))[0], 400)  # wrong field name
        self.assertEqual(p.parse_upload(T, *multipart()), (400, "Upload a file or paste a Google Doc link."))

    def test_parse_upload_link_and_modes(self):
        ok = p.parse_upload(T, *multipart({"sourceUrl": "https://docs.google.com/document/d/abc123/edit"}))
        self.assertEqual((ok[0], ok[1]["sourceFileName"]), (200, None))
        self.assertEqual(p.parse_upload(T, *multipart({"sourceUrl": "https://example.com/x"}))[0], 400)
        ct, b = multipart(file=("file", "plan.docx", b"x" * 60))
        self.assertEqual(p.parse_upload(T, ct, b, mode="aioff"), (500, "AI assistance is not configured on this server."))
        self.assertEqual(p.parse_upload(T, ct, b, mode="badjson")[0], 502)


class Syllabus(unittest.TestCase):
    def setUp(self):
        p.reset()

    def first(self, subject="Mathematics", grade="Grade 5", section="A"):
        return [d for d in p.list_syllabi(T, {})[1] if (d["subjectName"], d["gradeLevel"], d.get("sectionName")) == (subject, grade, section)][0]

    def test_list_filters_and_validation(self):
        st, rows = p.list_syllabi(T, {"teacherId": [T["staffId"]]})
        self.assertTrue(all(r["teacherId"] == T["staffId"] for r in rows))
        self.assertEqual(p.list_syllabi(T, {"teacherId": ["bad"]}), (400, "teacherId must be a mongodb id"))
        self.assertEqual(p.list_syllabi(T, {"trackStatus": ["x"]})[0], 400)
        grade = p.list_syllabi(T, {"gradeLevel": ["Grade 5"]})[1]
        self.assertTrue(all(r["gradeLevel"] == "Grade 5" for r in grade))

    def test_rollup_counts_subtopics_when_present(self):
        d = self.first()
        self.assertEqual((d["totalTopics"], d["coveredTopics"]), (9, 3))  # 3+2 sub-topics, 1 plain topic, 2 sub-topics, 1 plain topic; covered 2 sub-topics + 1 topic
        self.assertEqual(d["coveragePct"], round(d["coveredTopics"] / d["totalTopics"] * 100))

    def test_mark_sub_topic_derives_topic_and_rerolls(self):
        d = self.first()
        before = d["coveredTopics"]
        st, r = p.mark_sub_topic(T, d["_id"], {"unitNo": 1, "topicNo": 1, "subTopicNo": 3, "isCovered": True, "coveredBy": "Tess"})
        self.assertEqual(st, 200)
        topic = r["units"][0]["topics"][0]
        self.assertTrue(topic["isCovered"])  # all three sub-topics covered now
        self.assertEqual(r["coveredTopics"], before + 1)
        st, r = p.mark_sub_topic(T, d["_id"], {"unitNo": 1, "topicNo": 1, "subTopicNo": 3, "isCovered": False})
        self.assertFalse(r["units"][0]["topics"][0]["isCovered"])
        self.assertNotIn("coveredDate", r["units"][0]["topics"][0]["subTopics"][2])

    def test_mark_resets_behind_flag_like_the_real_service(self):
        d = self.first("Science", "Grade 6", "B")
        self.assertEqual(d["trackStatus"], "behind")
        r = p.mark_sub_topic(T, d["_id"], {"unitNo": 1, "topicNo": 1, "subTopicNo": 2, "isCovered": True})[1]
        self.assertEqual(r["trackStatus"], "on_track")

    def test_mark_topic_without_subtopics_and_validation_messages(self):
        d = self.first()
        st, r = p.mark_topic(T, d["_id"], {"unitNo": 2, "topicNo": 2, "isCovered": True, "coveredBy": "Tess"})
        self.assertEqual(st, 200)
        self.assertTrue(r["units"][1]["topics"][1]["isCovered"])
        self.assertEqual(p.mark_topic(T, d["_id"], {"unitNo": "1", "topicNo": 1, "isCovered": True}),
                         (400, "unitNo must be a number conforming to the specified constraints"))
        self.assertEqual(p.mark_topic(T, d["_id"], {"unitNo": 1, "topicNo": 1, "isCovered": "yes"}), (400, "isCovered must be a boolean value"))
        self.assertEqual(p.mark_topic(T, d["_id"], {"unitNo": 9, "topicNo": 1, "isCovered": True}), (404, "Unit 9 not found"))
        self.assertEqual(p.mark_topic(T, d["_id"], {"unitNo": 1, "topicNo": 9, "isCovered": True}), (404, "Topic 9 not found in unit 1"))
        self.assertEqual(p.mark_sub_topic(T, d["_id"], {"unitNo": 1, "topicNo": 1, "subTopicNo": 9, "isCovered": True})[0], 404)
        self.assertEqual(p.mark_topic(T, s._oid(1), {"unitNo": 1, "topicNo": 1, "isCovered": True}), (404, "Syllabus not found"))
        self.assertEqual(p.mark_topic(T, "zz", {"unitNo": 1, "topicNo": 1, "isCovered": True})[0], 500)

    def test_get_one(self):
        d = self.first()
        self.assertEqual(p.get_syllabus(T, d["_id"])[0], 200)
        self.assertEqual(p.get_syllabus(T, s._oid(2)), (404, "Syllabus not found"))
        self.assertEqual(p.get_syllabus(T, "behind-schedule")[0], 500)  # there is NO GET /syllabus/behind-schedule

    def test_weekly_planner_current_week_only(self):
        st, rows = p.weekly_planner(T, {"teacherId": [T["staffId"]]})
        self.assertEqual(st, 200)
        names = {r["subjectName"] for r in rows}
        self.assertEqual(names, {"Mathematics", "Science"})  # Term 3 + draft + other teacher skipped
        self.assertTrue(all(r["currentWeek"] == 5 for r in rows))
        maths = [r for r in rows if r["subjectName"] == "Mathematics"][0]
        self.assertEqual({x["subTopicName"] for x in maths["subTopics"]}, {"Mixed numbers", "Place value"})
        self.assertEqual(p.weekly_planner(T, {})[1], [])  # absent id -> random ObjectId -> empty, not an error
        self.assertEqual(p.weekly_planner(T, {"teacherId": ["bad"]})[0], 500)
        legacy = p.weekly_planner(T, {"teacherId": [T["teacherProfileId"]]})[1]
        self.assertEqual([r["gradeLevel"] for r in legacy], ["Grade 7"])


class Http(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv = ThreadingHTTPServer(("127.0.0.1", 0), s.Handler)
        cls.port = cls.srv.server_address[1]
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()

    def setUp(self):
        self.call("POST", "/__stub/reset-state")

    def call(self, method, path, body=None, headers=None, token="stub.teacher.dummy"):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        h = {"Authorization": f"Bearer {token}"}
        h.update(headers or {})
        data = body
        if isinstance(body, (dict, list)):
            data = json.dumps(body)
            h["Content-Type"] = "application/json"
        c.request(method, path, body=data, headers=h)
        r = c.getresponse()
        raw = r.read()
        return r.status, (json.loads(raw) if raw else None)

    def test_lesson_plan_roundtrip_and_error_shape(self):
        st, rows = self.call("GET", "/api/v1/teaching/lesson-plans?teacherId=" + T["staffId"])
        self.assertEqual(st, 200)
        self.assertTrue(isinstance(rows, list) and len(rows) >= 5)
        st, d = self.call("POST", "/api/v1/teaching/lesson-plans", {"teacherId": T["staffId"], "subject": "M", "gradeLevel": "G", "topic": "t", "planDate": "2030-01-01"})
        self.assertEqual(st, 201)
        st, d2 = self.call("PATCH", "/api/v1/teaching/lesson-plans/" + d["_id"], {"status": "submitted"})
        self.assertEqual((st, d2["status"]), (200, "submitted"))
        st, e = self.call("POST", "/api/v1/teaching/lesson-plans", {"teacherId": T["staffId"]})
        self.assertEqual(st, 400)
        self.assertEqual(set(e), {"statusCode", "message", "timestamp", "path"})
        self.call("POST", "/__stub/mode?feature=lpupdate&value=403")
        self.assertEqual(self.call("PATCH", "/api/v1/teaching/lesson-plans/" + d["_id"], {"topic": "x"})[0], 403)

    def test_patch_unknown_returns_empty_body_over_http(self):
        self.assertEqual(self.call("PATCH", "/api/v1/teaching/lesson-plans/" + s._oid(5), {"topic": "x"}), (200, None))

    def test_parse_upload_over_http_and_modes(self):
        ct, b = multipart(file=("file", "plan.docx", b"x" * 60))
        st, d = self.call("POST", "/api/v1/teaching/lesson-plans/parse-upload", b, headers={"Content-Type": ct})
        self.assertEqual(st, 200)
        self.call("POST", "/__stub/mode?feature=lpparse&value=aioff")
        st, e = self.call("POST", "/api/v1/teaching/lesson-plans/parse-upload", b, headers={"Content-Type": ct})
        self.assertEqual((st, e["message"]), (500, "AI assistance is not configured on this server."))

    def test_syllabus_over_http(self):
        st, rows = self.call("GET", "/api/v1/syllabus?teacherId=" + T["staffId"])
        self.assertEqual(st, 200)
        sid = rows[0]["_id"]
        st, one = self.call("GET", "/api/v1/syllabus/" + sid)
        self.assertEqual(st, 200)
        st, r = self.call("PATCH", f"/api/v1/syllabus/{sid}/mark-sub-topic", {"unitNo": 1, "topicNo": 1, "subTopicNo": 3, "isCovered": True})
        self.assertEqual(st, 200)
        st, pl = self.call("GET", "/api/v1/syllabus/weekly-planner?teacherId=" + T["staffId"])
        self.assertEqual(st, 200)
        self.call("POST", "/__stub/mode?feature=sylmark&value=403")
        self.assertEqual(self.call("PATCH", f"/api/v1/syllabus/{sid}/mark-topic", {"unitNo": 1, "topicNo": 1, "isCovered": True})[0], 403)

    def test_non_teacher_gets_403(self):
        self.assertEqual(self.call("GET", "/api/v1/syllabus", token="stub.principal.dummy")[0], 403)
        self.assertEqual(self.call("GET", "/api/v1/syllabus", token="stub.expired.dummy")[0], 401)


if __name__ == "__main__":
    unittest.main()
