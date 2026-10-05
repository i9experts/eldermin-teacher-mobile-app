"""Unit tests for tool/dev/verify_staging.py helpers (fake responses only, no network).
Run: python3 -m unittest discover -s tool/dev -p 'test_*.py' -v
"""
import io
import os
import sys
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify_staging as v  # noqa: E402

SECRET_EMAIL = "jane.teacher@school.example"
SECRET_NAME = "Jane Teacher"
SECRET_ID = "665f00000000000000000a01"
SECRET_TOKEN = "eyJhbGciOi.SECRET.TOKEN"


class TypeAndEnvTests(unittest.TestCase):
    def test_type_name_bool_is_not_int(self):
        self.assertEqual(v.type_name(True), "bool")
        self.assertEqual(v.type_name(3), "int")
        self.assertEqual(v.type_name(3.5), "float")
        self.assertEqual(v.type_name(None), "null")
        self.assertEqual(v.type_name([]), "list")
        self.assertEqual(v.type_name({}), "dict")
        self.assertEqual(v.type_name("x"), "str")

    def test_parse_env(self):
        env = v.parse_env('# c\nA=1\nB = "two words"\nC=\nbad line\nD=x=y\n')
        self.assertEqual(env, {"A": "1", "B": "two words", "C": "", "D": "x=y"})

    def test_normalize_base(self):
        self.assertEqual(v.normalize_base("https://s.example/"), "https://s.example/api/v1")
        self.assertEqual(v.normalize_base("https://s.example/api/v1/"), "https://s.example/api/v1")


class GuardTests(unittest.TestCase):
    def test_production_host_is_blocked_in_every_spelling(self):
        for u in ["https://api.eldermin.com", "https://API.ELDERMIN.COM/api/v1", "https://api.eldermin.com:443/api/v1",
                  "https://user:pw@api.eldermin.com/x", "https://api.eldermin.com./api/v1", "https://eu.api.eldermin.com/api/v1"]:
            self.assertTrue(v.host_is_blocked(u), u)

    def test_staging_and_local_hosts_are_not_blocked(self):
        for u in ["https://staging-api.eldermin.com", "http://127.0.0.1:3999", "https://api-staging.example.com/api/v1",
                  "https://notapi.eldermin.com.evil.example"]:
            self.assertFalse(v.host_is_blocked(u), u)

    def test_only_get_and_login_post_are_allowed(self):
        self.assertTrue(v.request_allowed("GET", "/staff-portal/me"))
        self.assertTrue(v.request_allowed("POST", "/auth/login"))
        for m in ["POST", "PUT", "PATCH", "DELETE"]:
            self.assertFalse(v.request_allowed(m, "/staff-portal/threads"), m)
        self.assertFalse(v.request_allowed("PUT", "/auth/login"))

    def test_http_refuses_a_forbidden_method_before_any_io(self):
        with self.assertRaises(RuntimeError):
            v.http("DELETE", "http://127.0.0.1:1", "/anything")
        with self.assertRaises(RuntimeError):
            v.http("POST", "http://127.0.0.1:1", "/staff-portal/threads", json_body={})


class CheckFieldTests(unittest.TestCase):
    def test_pass_fail_and_na(self):
        body = {"total": 3, "items": [{"assignmentId": SECRET_ID, "sectionName": None, "submittedCount": 2},
                                      {"assignmentId": SECRET_ID, "sectionName": "A", "submittedCount": "2"}]}
        self.assertEqual(v.check_field(body, ("total", {"int"}, True, None))[0], "PASS")
        self.assertEqual(v.check_field(body, ("items[].sectionName", {"str", "null"}, False, None))[0], "PASS")
        st, detail = v.check_field(body, ("items[].submittedCount", {"int"}, True, None))
        self.assertEqual(st, "FAIL")
        self.assertIn("wrong type in 1/2", detail)
        self.assertEqual(v.check_field(body, ("generatedAt", {"str"}, True, None))[0], "FAIL")
        self.assertEqual(v.check_field(body, ("generatedAt", {"str"}, False, None))[0], "N/A")
        self.assertEqual(v.check_field({"items": []}, ("items[].title", {"str"}, True, None))[0], "N/A")

    def test_bool_is_not_accepted_as_int(self):
        self.assertEqual(v.check_field({"n": True}, ("n", {"int"}, True, None))[0], "FAIL")

    def test_bare_array_paths(self):
        body = [{"_id": SECRET_ID, "status": "confirmed"}, {"_id": SECRET_ID, "status": "weird"}]
        self.assertEqual(v.check_field(body, ("[]._id", {"str"}, True, ("fmt", "id")))[0], "PASS")
        st, d = v.check_field(body, ("[].status", {"str"}, True, ("enum", ["requested", "confirmed"])))
        self.assertEqual(st, "FAIL")
        self.assertIn("unexpected value/format in 1/2", d)
        self.assertEqual(v.check_field([], ("[]._id", {"str"}, True, None))[0], "N/A")

    def test_nested_null_parent_is_skipped_not_failed(self):
        body = {"days": [{"slots": [{"splitGroup": None}, {"splitGroup": {"name": "G1"}}]}]}
        st, d = v.check_field(body, ("days[].slots[].splitGroup.name", {"str"}, True, None))
        self.assertEqual(st, "PASS")
        self.assertIn("checked 1", d)

    def test_formats(self):
        ok = {"hm": "08:00", "ymd": "2026-10-05", "iso": "2026-10-05T08:00:00.000Z", "id": SECRET_ID}
        for fmt, val in ok.items():
            self.assertEqual(v.check_field({"k": val}, ("k", {"str"}, True, ("fmt", fmt)))[0], "PASS", fmt)
        bad = {"hm": "8am", "ymd": "05/10/2026", "iso": "yesterday", "id": "123"}
        for fmt, val in bad.items():
            self.assertEqual(v.check_field({"k": val}, ("k", {"str"}, True, ("fmt", fmt)))[0], "FAIL", fmt)

    def test_missing_required_key_in_some_rows_fails(self):
        st, d = v.check_field({"items": [{"a": "x"}, {}]}, ("items[].a", {"str"}, True, None))
        self.assertEqual(st, "FAIL")
        self.assertIn("missing in 1/2", d)

    def test_only_first_50_items_are_checked(self):
        body = {"items": [{"a": "x"} for _ in range(120)]}
        st, d = v.check_field(body, ("items[].a", {"str"}, True, None))
        self.assertEqual(st, "PASS")
        self.assertIn("checked 50", d)


class RedactionTests(unittest.TestCase):
    """Whatever the response contains, the report may only carry types, key names from the table, counts."""

    BODY = {
        "staffId": SECRET_ID,
        "user": {"name": SECRET_NAME, "email": SECRET_EMAIL, "avatarUrl": None},
        "accessToken": SECRET_TOKEN,
        "teacherProfile": {"classTeacherOf": {"gradeName": "Grade 5", "sectionName": "A"}},
        "department": "Science",
        "campus": {"name": "North Campus"},
        "institution": {"name": "Secret School"},
    }

    def test_detail_lines_never_contain_response_values(self):
        lines = []
        for key in ("staff_me", "staff_me_class", "login"):
            for path, st, detail in v.check_expectations(self.BODY, v.EXPECTATIONS[key]):
                lines.append(f"{st} {path} {detail}")
        text = "\n".join(lines)
        for secret in [SECRET_EMAIL, SECRET_NAME, SECRET_ID, SECRET_TOKEN, "Science", "North Campus", "Secret School", "Grade 5"]:
            self.assertNotIn(secret, text)
        self.assertIn("types seen: strx1", text)

    def test_wrong_type_report_shows_type_not_value(self):
        st, d = v.check_field({"name": SECRET_NAME}, ("name", {"int"}, True, None))
        self.assertEqual(st, "FAIL")
        self.assertNotIn(SECRET_NAME, d)
        st, d = v.check_field({"t": SECRET_ID + "-bad"}, ("t", {"str"}, True, ("fmt", "id")))
        self.assertNotIn("bad", d.replace("unexpected", ""))

    def test_body_summary_is_shape_only(self):
        self.assertEqual(v.body_summary([1, 2, 3]), "list[3]")
        self.assertEqual(v.body_summary(self.BODY), "dict")
        self.assertEqual(v.body_summary(None), "null")

    def test_report_endpoint_prints_only_status_types_counts(self):
        rep = v.Report()
        buf = io.StringIO()
        with redirect_stdout(buf):
            rep.endpoint("teacher", "GET /staff-portal/me", 200, self.BODY, "staff_me")
            rep.endpoint("teacher", "GET /staff-portal/timetable?date=<today>", 404, {"message": SECRET_NAME}, "timetable")
            rep.endpoint("teacher", "GET /x", 500, {"message": SECRET_EMAIL}, "unread_count")
            rep.endpoint("teacher", "GET /y", None, None, "unread_count")
        out = buf.getvalue()
        for secret in [SECRET_EMAIL, SECRET_NAME, SECRET_ID, SECRET_TOKEN, "Science"]:
            self.assertNotIn(secret, out)
        self.assertIn("[NOT-DEPLOYED(404)]", out)
        self.assertEqual(rep.counts["PASS"], 1)
        self.assertEqual(rep.counts["NOT-DEPLOYED(404)"], 1)
        self.assertEqual(rep.counts["FAIL"], 2)
        self.assertEqual(rep.fails, 2)

    def test_verdicts(self):
        self.assertEqual(v.endpoint_verdict(200), "PASS")
        self.assertEqual(v.endpoint_verdict(404), "NOT-DEPLOYED(404)")
        for s in (400, 401, 403, 500, 302):
            self.assertEqual(v.endpoint_verdict(s), "FAIL")


class ExpectationsTableTests(unittest.TestCase):
    def test_a_good_timetable_and_pending_grading_response_pass_every_row(self):
        tt = {"from": "2026-10-05", "to": "2026-10-05", "days": [{"date": "2026-10-05", "dayOfWeek": 1, "weekCycle": None, "slots": [
            {"timetableId": SECRET_ID, "gradeLevel": "Grade 5", "sectionName": None, "periodNo": 1, "startTime": "08:00",
             "endTime": "08:40", "subject": "Maths", "roomNo": "1", "type": "regular", "weekCycle": "both", "splitGroup": None},
            {"timetableId": SECRET_ID, "gradeLevel": "Grade 7", "sectionName": "B", "periodNo": 3, "startTime": "09:20",
             "endTime": "10:00", "subject": "Lang", "roomNo": "2", "type": "regular", "weekCycle": "A",
             "splitGroup": {"name": "French", "subject": "Lang", "roomNo": "2"}}]}]}
        res = v.check_expectations(tt, v.EXPECTATIONS["timetable"])
        self.assertEqual([r for r in res if r[1] == "FAIL"], [])
        pg = {"total": 1, "items": [{"assignmentId": SECRET_ID, "title": "T", "subject": "S", "gradeLevel": "G", "sectionName": None,
                                     "dueDate": None, "submittedCount": 1, "totalSubmissions": 2, "oldestSubmittedAt": None}],
              "generatedAt": "2026-10-05T08:00:00.000Z"}
        self.assertEqual([r for r in v.check_expectations(pg, v.EXPECTATIONS["pending_grading"]) if r[1] == "FAIL"], [])

    def test_a_drifted_timetable_is_caught(self):
        tt = {"from": "2026-10-05", "to": "2026-10-05", "days": [{"date": "2026-10-05", "dayOfWeek": "1", "weekCycle": "A", "slots": [
            {"timetableId": SECRET_ID, "weekCycle": "C"}]}]}
        failed = {p for p, st, _ in v.check_expectations(tt, v.EXPECTATIONS["timetable"]) if st == "FAIL"}
        self.assertIn("days[].dayOfWeek", failed)
        self.assertIn("days[].slots[].weekCycle", failed)
        self.assertIn("days[].slots[].periodNo", failed)

    def test_open_only_threads_flags_a_closed_row(self):
        body = {"items": [{"_id": SECRET_ID, "staffHasUnread": True, "status": "closed"}], "unreadCount": 1}
        failed = {p for p, st, _ in v.check_expectations(body, v.EXPECTATIONS["threads_open"]) if st == "FAIL"}
        self.assertEqual(failed, {"items[].status"})

    def test_every_expectation_block_has_a_citation_comment(self):
        with open(v.__file__, encoding="utf-8") as f:
            src = f.read()
        for key in v.EXPECTATIONS:
            self.assertIn(f'"{key}": [', src)
        self.assertGreaterEqual(src.count("Backend"), 10)


if __name__ == "__main__":
    unittest.main()
