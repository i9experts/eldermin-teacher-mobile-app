#!/usr/bin/env python3
"""Tests for the Phase 5b stub (homework, upload, behaviour, tarbiyah): the contract the Dart repositories rely on.
Run: python3 tool/dev/test_stub_5b.py"""
import http.client
import json
import os
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_5b as b

T = s.ACCOUNTS["teacher"]
CT = s.ACCOUNTS["classteacher"]


class Logic(unittest.TestCase):
    def setUp(self):
        b.reset()

    def test_list_filters_by_teacher_and_sorts_due_desc(self):
        st, rows = b.list_assignments(T, {"teacherId": [T["staffId"]]})
        self.assertEqual(st, 200)
        self.assertEqual(len(rows), 4)
        self.assertTrue(all(r["teacherId"] == T["staffId"] for r in rows))
        dues = [r["dueDate"] for r in rows]
        self.assertEqual(dues, sorted(dues, reverse=True))
        st, all_rows = b.list_assignments(T, {})
        self.assertIn(s.OTHER_STAFF, {r["teacherId"] for r in all_rows})

    def test_invalid_teacher_id_is_500(self):
        self.assertEqual(b.list_assignments(T, {"teacherId": ["nope"]})[0], 500)

    def test_create_validation_messages_first_only(self):
        st, msg = b.create_assignment(T, {"subject": "Maths", "gradeLevel": "Grade 5"})
        self.assertEqual((st, msg), (400, "title must be a string"))
        st, msg = b.create_assignment(T, {"title": "x", "subject": "M", "gradeLevel": "G", "dueDate": "tomorrow"})
        self.assertEqual((st, msg), (400, "dueDate must be a valid ISO 8601 date string"))
        st, msg = b.create_assignment(T, {"title": "x", "subject": "M", "gradeLevel": "G", "status": "graded"})
        self.assertEqual(st, 400)
        self.assertIn("must be one of the following values: draft, assigned", msg)
        st, msg = b.create_assignment(T, {"title": "x", "subject": "M", "gradeLevel": "G", "totalMarks": -1})
        self.assertEqual((st, msg), (400, "totalMarks must not be less than 0"))

    def test_create_assigned_materialises_exact_match_roster_only(self):
        st, a = b.create_assignment(T, {"title": "t", "subject": "Maths", "gradeLevel": "Grade 5", "sectionName": "A",
                                        "dueDate": "2030-01-05", "status": "assigned", "teacherId": T["staffId"],
                                        "evil": "dropped", "tenantId": "x"})
        self.assertEqual(st, 201)
        self.assertNotIn("evil", a)
        self.assertEqual(a["tenantId"], s._oid(0xa1))  # not client-settable
        st, body = b.get_submissions(T, a["_id"])
        # 31 students in 5A, 1 transferred, 2 stored as '5'/'a' (exact match misses them) -> 28
        self.assertEqual(len(body["submissions"]), 28)
        self.assertTrue(all(r["status"] == "pending" for r in body["submissions"]))

    def test_draft_has_no_submissions_until_assigned(self):
        st, a = b.create_assignment(T, {"title": "t", "subject": "M", "gradeLevel": "Grade 5", "sectionName": "A"})
        self.assertEqual(a["status"], "draft")
        self.assertEqual(b.get_submissions(T, a["_id"])[1]["submissions"], [])
        st, a2 = b.update_assignment(T, a["_id"], {"status": "assigned"})
        self.assertEqual(st, 200)
        self.assertEqual(len(b.get_submissions(T, a["_id"])[1]["submissions"]), 28)

    def test_update_ignores_non_dto_fields_and_404(self):
        b.seed_for(T["staffId"])
        aid = next(iter(b._state["assignments"]))
        st, a = b.update_assignment(T, aid, {"teacherId": "x" * 24, "title": "New"})
        self.assertEqual(a["title"], "New")
        self.assertNotEqual(a["teacherId"], "x" * 24)
        self.assertEqual(b.update_assignment(T, s._oid(1), {"title": "y"}), (404, "Assignment not found"))

    def test_delete_cascades(self):
        b.seed_for(T["staffId"])
        aid = s._oid(0x301)
        self.assertEqual(b.delete_assignment(T, aid), (200, {"deleted": True}))
        self.assertEqual(b.get_submissions(T, aid)[0], 404)

    def test_grade_bounds_and_state(self):
        b.seed_for(T["staffId"])
        aid = s._oid(0x301)
        subs = b.get_submissions(T, aid)[1]["submissions"]
        sub = next(r for r in subs if r["status"] == "submitted")
        self.assertEqual(b.grade_submission(T, aid, sub["_id"], {"grade": 101})[1],
                         "Grade cannot exceed this assignment's maximum of 100.")
        self.assertEqual(b.grade_submission(T, aid, sub["_id"], {"grade": -1})[0], 400)
        self.assertEqual(b.grade_submission(T, aid, sub["_id"], {"grade": "9"})[0], 400)
        self.assertEqual(b.grade_submission(T, aid, sub["_id"], {"grade": 1001})[1], "grade must not be greater than 1000")
        st, r = b.grade_submission(T, aid, sub["_id"], {"grade": 77.5, "feedback": "Nice"})
        self.assertEqual((st, r["status"], r["grade"]), (200, "graded", 77.5))
        self.assertEqual(b.grade_submission(T, aid, s._oid(5), {"grade": 1})[1], "Submission not found")

    def test_pending_grading_follows_grading(self):
        before = b.pending_grading(T["staffId"], "")["total"]
        aid = s._oid(0x301)
        sub = next(r for r in b.get_submissions(T, aid)[1]["submissions"] if r["status"] == "submitted")
        b.grade_submission(T, aid, sub["_id"], {"grade": 5})
        self.assertEqual(b.pending_grading(T["staffId"], "")["total"], before - 1)


class Upload(unittest.TestCase):
    def mp(self, field, name, data, ctype="application/pdf"):
        bd = "----t"
        body = (f'--{bd}\r\nContent-Disposition: form-data; name="{field}"; filename="{name}"\r\nContent-Type: {ctype}\r\n\r\n').encode() \
            + data + f"\r\n--{bd}--\r\n".encode()
        return f"multipart/form-data; boundary={bd}", body

    def test_single_upload_shape(self):
        ct, body = self.mp("file", "Worksheet 1.PDF", b"%PDF-1.4 dummy")
        st, r = b.upload_single(T, "homework-attachments", ct, body)
        self.assertEqual(st, 201)
        d = r["data"]
        self.assertTrue(r["success"])
        self.assertEqual(set(d), {"url", "key", "fileName", "fileSize", "fileType"})
        self.assertRegex(d["key"], r"^demo-school/homework-attachments/[0-9a-f-]{36}\.pdf$")
        self.assertEqual((d["fileName"], d["fileSize"], d["fileType"]), ("Worksheet 1.PDF", 14, "application/pdf"))

    def test_wrong_field_name_and_too_large(self):
        ct, body = self.mp("files", "a.pdf", b"x")
        self.assertEqual(b.upload_single(T, "f", ct, body), (400, "Unexpected field - files"))
        ct, body = self.mp("file", "a.pdf", b"x" * (b.MAX_FILE_SIZE + 1))
        self.assertEqual(b.upload_single(T, "f", ct, body), (413, "File too large"))


class UploadUnavailable(unittest.TestCase):
    def test_mode_503_message_is_the_planned_storage_text(self):
        """upload=503 is served by stub_server's generic error modes (feature `upload`); the text is the PLANNED backend wording
        (2026-10-08, UNVERIFIED until the backend task documents it)."""
        src = open(os.path.join(os.path.dirname(__file__), "stub_server.py")).read()
        self.assertIn("File uploads are not available on this server (storage is not configured).", src)
        self.assertIn('"500", "503")', src)


class Behaviour(unittest.TestCase):
    def setUp(self):
        b.reset()

    def valid(self, **kw):
        d = {"studentId": s._oid(0x205), "studentName": "A B", "grade": "Grade 5", "section": "A", "date": "2026-10-05",
             "type": "positive", "category": "helping_others", "title": "T", "description": "D", "points": 5,
             "reportedBy": "Tess Teacher", "reportedById": T["id"], "academicYear": "2026-27"}
        d.update(kw)
        return d

    def test_list_is_campus_wide_no_reporter_filter_and_paged_strings(self):
        st, r = b.list_records(T, {})
        self.assertEqual(st, 200)
        self.assertEqual(r["meta"]["page"], 1)
        st, r = b.list_records(T, {"page": ["1"], "limit": ["3"]})
        self.assertEqual((r["meta"]["page"], r["meta"]["limit"], len(r["data"])), ("1", "3", 3))
        self.assertGreater(r["meta"]["pages"], 1)
        names = {x["reportedBy"] for x in b.list_records(T, {"limit": ["100"]})[1]["data"]}
        self.assertIn("Omar Colleague", names)  # a colleague's records are returned too

    def test_grade_filter_is_exact(self):
        rows = b.list_records(T, {"grade": ["Grade 5"], "limit": ["100"]})[1]["data"]
        self.assertTrue(all(x["grade"] == "Grade 5" for x in rows))
        rows5 = b.list_records(T, {"grade": ["5"], "limit": ["100"]})[1]["data"]
        self.assertEqual(len(rows5), 1)

    def test_create_ok_and_persisted(self):
        st, r = b.create_record(T, self.valid())
        self.assertEqual(st, 201)
        self.assertEqual((r["resolved"], r["verified"], r["parentNotified"], r["severity"]), (False, False, False, "medium"))
        self.assertEqual(b.list_records(T, {"studentId": [s._oid(0x205)]})[1]["data"][0]["_id"], r["_id"])

    def test_create_invalid_is_500_like_mongoose(self):
        for kw in ({"category": "nope"}, {"type": "x"}, {"title": ""}, {"studentId": "bad"}, {"date": "x"}):
            self.assertEqual(b.create_record(T, self.valid(**kw)), (500, "Internal server error"), kw)

    def test_reported_by_defaults_to_name(self):
        v = self.valid()
        del v["reportedBy"]
        self.assertEqual(b.create_record(T, v)[1]["reportedBy"], "Tess Teacher")

    def test_resolve_and_unknown(self):
        rid = b.list_records(T, {})[1]["data"][0]["_id"]
        st, r = b.resolve_record(T, rid, {"note": "ok"})
        self.assertTrue(r["resolved"])
        self.assertEqual(b.resolve_record(T, s._oid(1), {"note": "x"}), (200, None))

    def test_tarbiyah(self):
        st, r = b.list_tarbiyah(T, {"studentId": [s._oid(0x200)]})
        self.assertEqual(len(r["data"]), 1)
        self.assertEqual(b.list_tarbiyah(T, {"studentId": [s._oid(0x201)]})[1]["data"], [])


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

    def test_error_shape_and_modes(self):
        self.call("POST", "/__stub/mode?feature=hwwrite&value=400")
        st, e = self.call("POST", "/api/v1/teaching/assignments", {"title": "x"})
        self.assertEqual(st, 400)
        self.assertEqual(set(e), {"statusCode", "message", "timestamp", "path"})
        self.call("POST", "/__stub/mode?feature=hwwrite&value=403")
        self.assertEqual(self.call("PATCH", "/api/v1/teaching/assignments/" + s._oid(0x301), {"title": "x"})[0], 403)
        self.call("POST", "/__stub/mode?feature=upload&value=413")
        self.assertEqual(self.call("POST", "/api/v1/upload/single/x", b"")[0], 413)

    def test_crud_roundtrip_over_http(self):
        st, a = self.call("POST", "/api/v1/teaching/assignments", {"title": "N", "subject": "Maths", "gradeLevel": "Grade 5",
                          "sectionName": "A", "dueDate": "2030-02-01", "status": "assigned", "teacherId": T["staffId"]})
        self.assertEqual(st, 201)
        st, rows = self.call("GET", "/api/v1/teaching/assignments?teacherId=" + T["staffId"])
        self.assertIn(a["_id"], [r["_id"] for r in rows])
        self.assertEqual(self.call("DELETE", "/api/v1/teaching/assignments/" + a["_id"])[1], {"deleted": True})
        st, rows = self.call("GET", "/api/v1/teaching/assignments?teacherId=" + T["staffId"])
        self.assertNotIn(a["_id"], [r["_id"] for r in rows])

    def test_signed_url_and_unauth(self):
        st, r = self.call("GET", "/api/v1/upload/signed-url?key=demo-school/f/a.pdf")
        self.assertEqual(st, 200)
        self.assertIn("/__stub/files/demo-school/f/a.pdf", r["url"])
        self.assertEqual(self.call("GET", "/api/v1/upload/signed-url?key=x", token="stub.expired.dummy")[0], 401)

    def test_resolve_unknown_empty_body(self):
        st, body = self.call("PATCH", "/api/v1/behaviour/records/" + s._oid(1) + "/resolve", {"note": "x"})
        self.assertEqual((st, body), (200, None))


if __name__ == "__main__":
    unittest.main()
