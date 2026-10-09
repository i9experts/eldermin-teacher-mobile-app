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


class TestPhase7aExpectations(unittest.TestCase):
    def fails(self, body, key):
        return {p for p, st, _ in v.check_expectations(body, v.EXPECTATIONS[key]) if st == "FAIL"}

    def test_good_bodies_pass_and_ignore_extra_keys(self):
        threads = {"items": [{"_id": SECRET_ID, "subject": "S", "studentName": "N", "guardianName": "G", "lastMessagePreview": "p", "lastMessageAt": "2026-10-05T08:00:00.000Z",
                              "staffHasUnread": True, "status": "closed", "guardianUserId": SECRET_ID}], "unreadCount": 1}
        self.assertEqual(self.fails(threads, "threads_all"), set())
        msgs = {"thread": {"_id": SECRET_ID, "status": "open", "staffHasUnread": False},
                "messages": [{"_id": SECRET_ID, "senderRole": "guardian", "body": "b", "createdAt": "2026-10-05T08:00:00.000Z"}]}
        self.assertEqual(self.fails(msgs, "thread_messages"), set())
        page = {"items": [{"_id": SECRET_ID, "type": "message", "title": "t", "body": "b", "isRead": False, "createdAt": "2026-10-05T08:00:00.000Z"}],
                "nextCursor": None, "unreadCount": 0}
        self.assertEqual(self.fails(page, "notifications_page"), set())
        leaves = {"items": [{"_id": SECRET_ID, "studentName": "N", "fromDate": "2026-10-05T00:00:00.000Z", "toDate": "2026-10-06T00:00:00.000Z", "reason": "r",
                             "leaveType": "sick", "requestedByName": "G", "status": "pending"}]}
        self.assertEqual(self.fails(leaves, "student_leaves"), set())
        self.assertEqual(self.fails([{"userId": SECRET_ID, "name": "G"}], "guardians"), set())

    def test_drift_is_caught(self):
        self.assertEqual(self.fails({"items": [{"_id": SECRET_ID, "guardianName": "G", "staffHasUnread": "yes", "status": "archived"}], "unreadCount": 1}, "threads_all"),
                         {"items[].staffHasUnread", "items[].status"})
        self.assertIn("messages[].senderRole", self.fails({"thread": {"_id": SECRET_ID, "status": "open", "staffHasUnread": False}, "messages": [
            {"_id": SECRET_ID, "senderRole": "parent", "body": "b", "createdAt": "2026-10-05T08:00:00.000Z"}]}, "thread_messages"))
        self.assertIn("items[].type", self.fails({"items": [{"_id": SECRET_ID, "type": "zzz", "title": "t", "body": "b", "isRead": False, "createdAt": "2026-10-05T08:00:00.000Z"}],
                                                  "nextCursor": None, "unreadCount": 0}, "notifications_page"))
        self.assertIn("items[].status", self.fails({"items": [{"_id": SECRET_ID, "studentName": "N", "fromDate": "2026-10-05", "toDate": "2026-10-06", "reason": "r",
                                                               "requestedByName": "G", "status": "done"}]}, "student_leaves"))
        self.assertIn("[].userId", self.fails([{"name": "G"}], "guardians"))

    def test_contact_key_detector_reports_names_only(self):
        self.assertEqual(v.contact_key_names([{"userId": "1", "name": "G"}]), [])
        self.assertEqual(v.contact_key_names([{"userId": "1", "name": "G", "phone": "0300-5550001", "personalEmail": "a@b.c"}]), ["personalEmail", "phone"])
        self.assertEqual(v.contact_key_names({"not": "a list"}), [])

    def test_phase7a_calls_are_get_only(self):
        self.assertTrue(v.request_allowed("GET", "/staff-portal/threads"))
        for m, path in (("POST", "/staff-portal/threads"), ("POST", "/staff-portal/threads/x/messages"), ("PATCH", "/staff-portal/threads/x/close"),
                        ("POST", "/staff-portal/notifications/read-all"), ("PATCH", "/staff-portal/student-leaves/x")):
            self.assertFalse(v.request_allowed(m, path), (m, path))


class TestPhase5aExpectations(unittest.TestCase):
    def test_good_students_list_passes_and_ignores_fee_keys(self):
        body = {"data": [{"_id": SECRET_ID, "firstName": "A", "lastName": "B", "currentGrade": "Grade 5", "currentSection": "A",
                          "currentRollNumber": "1", "status": "active", "currentAcademicYear": "2026-27",
                          "monthlyTuitionFee": 18500, "guardians": [{"phone": "0300"}]}],
                "meta": {"total": 1, "page": 1, "limit": 200, "pages": 1}}
        res = v.check_expectations(body, v.EXPECTATIONS["students_list"])
        self.assertFalse([r for r in res if r[1] == "FAIL"])
        self.assertFalse(any("monthlyTuitionFee" in r[0] or "phone" in r[0] for r in res))

    def test_drifted_attendance_status_is_caught(self):
        body = {"data": [{"studentId": SECRET_ID, "date": "2026-10-05T00:00:00.000Z", "status": "holiday"}], "meta": {"total": 1, "pages": 1}}
        failed = {p for p, st, _ in v.check_expectations(body, v.EXPECTATIONS["attendance_records"]) if st == "FAIL"}
        self.assertEqual(failed, {"data[].status"})

    def test_360_and_summary_shapes(self):
        body = {"student": {"_id": SECRET_ID, "firstName": "A", "currentGrade": "5", "guardians": [{"name": "G", "relation": "father"}]},
                "attendance": {"totalDays": 3, "percentage": 66.7, "recent": []}, "behaviour": {"recent": []}, "assessments": {"recent": []}}
        self.assertFalse([r for r in v.check_expectations(body, v.EXPECTATIONS["student_360"]) if r[1] == "FAIL"])
        self.assertFalse([r for r in v.check_expectations([{"_id": "present", "count": 2}], v.EXPECTATIONS["attendance_summary"]) if r[1] == "FAIL"])
        self.assertFalse([r for r in v.check_expectations([], v.EXPECTATIONS["attendance_summary"]) if r[1] == "FAIL"])


class TestPhase5bExpectations(unittest.TestCase):
    def test_good_assignments_and_submissions_pass(self):
        a = [{"_id": SECRET_ID, "teacherId": SECRET_ID, "title": "T", "subject": "S", "gradeLevel": "Grade 5", "sectionName": "A", "type": "homework",
              "status": "assigned", "dueDate": "2026-10-07T00:00:00.000Z", "totalMarks": 100, "passingMarks": 50.5, "submissionsCount": 2,
              "attachmentS3Keys": [], "tenantId": "x"}]
        self.assertFalse([r for r in v.check_expectations(a, v.EXPECTATIONS["assignments"]) if r[1] == "FAIL"])
        sub = {"assignment": {"_id": SECRET_ID, "totalMarks": 20}, "submissions": [
            {"_id": SECRET_ID, "studentName": "N", "status": "late", "isLate": True, "maxGrade": 20, "grade": None, "submittedAt": "2026-10-04T09:00:00.000Z",
             "attachmentS3Keys": []}]}
        self.assertFalse([r for r in v.check_expectations(sub, v.EXPECTATIONS["submissions"]) if r[1] == "FAIL"])

    def test_drifted_assignment_status_and_submission_status_are_caught(self):
        a = [{"_id": SECRET_ID, "title": "T", "subject": "S", "gradeLevel": "G", "status": "published"}]
        failed = {p for p, st, _ in v.check_expectations(a, v.EXPECTATIONS["assignments"]) if st == "FAIL"}
        self.assertEqual(failed, {"[].status"})
        sub = {"assignment": {"_id": SECRET_ID}, "submissions": [{"_id": SECRET_ID, "status": "done"}]}
        failed = {p for p, st, _ in v.check_expectations(sub, v.EXPECTATIONS["submissions"]) if st == "FAIL"}
        self.assertEqual(failed, {"submissions[].status"})

    def test_behaviour_records_and_tarbiyah(self):
        rec = {"data": [{"_id": SECRET_ID, "studentId": SECRET_ID, "studentName": "N", "grade": "Grade 5", "section": "A",
                         "date": "2026-10-05T00:00:00.000Z", "type": "positive", "category": "helping_others", "title": "T", "description": "D",
                         "severity": "low", "points": 5, "resolved": False, "reportedBy": "X", "reportedById": SECRET_ID}],
               "meta": {"total": 1, "page": "1", "limit": "5", "pages": 1}}
        self.assertFalse([r for r in v.check_expectations(rec, v.EXPECTATIONS["behaviour_records"]) if r[1] == "FAIL"])
        bad = {"data": [{"_id": SECRET_ID, "studentId": SECRET_ID, "studentName": "N", "grade": "G", "date": "2026-10-05T00:00:00.000Z",
                         "type": "merit", "category": "c", "title": "T", "description": "D", "reportedBy": "X"}], "meta": {"total": 1, "pages": 1}}
        failed = {p for p, st, _ in v.check_expectations(bad, v.EXPECTATIONS["behaviour_records"]) if st == "FAIL"}
        self.assertEqual(failed, {"data[].type"})
        tar = {"data": [{"_id": SECRET_ID, "studentId": SECRET_ID, "period": "Term 1", "assessmentDate": "2026-09-01T00:00:00.000Z",
                         "traits": [{"traitKey": "sidq", "score": 4}], "overallPercentage": 75, "overallRating": "good"}], "meta": {"total": 1}}
        self.assertFalse([r for r in v.check_expectations(tar, v.EXPECTATIONS["tarbiyah"]) if r[1] == "FAIL"])

    def test_values_are_never_printed_for_the_new_endpoints(self):
        rep = v.Report()
        buf = io.StringIO()
        with redirect_stdout(buf):
            rep.endpoint("teacher", "GET /behaviour/records?limit=5", 200,
                         {"data": [{"_id": SECRET_ID, "studentName": SECRET_NAME, "description": SECRET_EMAIL}], "meta": {"total": 1, "pages": 1}}, "behaviour_records")
        out = buf.getvalue()
        for secret in (SECRET_ID, SECRET_NAME, SECRET_EMAIL):
            self.assertNotIn(secret, out)


class TestPhase6aExpectations(unittest.TestCase):
    def test_good_lesson_plans_syllabi_and_planner_pass(self):
        lp = [{"_id": SECRET_ID, "topic": "T", "subject": "S", "gradeLevel": "Grade 5", "sectionName": "A", "teacherId": SECRET_ID,
               "planDate": "2026-10-07T00:00:00.000Z", "durationMins": 40, "learningObjectives": ["a"], "resources": [], "teachingMethodology": "lecture",
               "status": "rejected", "rejectionReason": "r", "tenantId": "x"}]
        self.assertFalse([r for r in v.check_expectations(lp, v.EXPECTATIONS["lesson_plans_mine"]) if r[1] == "FAIL"])
        syl = [{"_id": SECRET_ID, "subjectName": "Maths", "gradeLevel": "Grade 5", "academicYearLabel": "2026-27", "status": "active", "trackStatus": "on_track",
                "teacherId": SECRET_ID, "totalTopics": 3, "coveredTopics": 1, "coveragePct": 33,
                "units": [{"unitNo": 1, "topics": [{"topicNo": 1, "topicName": "T", "isCovered": False, "subTopics": [], "lessons": []}]}]}]
        self.assertFalse([r for r in v.check_expectations(syl, v.EXPECTATIONS["syllabi"]) if r[1] == "FAIL"])
        pl = [{"syllabusId": SECRET_ID, "subjectName": "S", "gradeLevel": "G", "currentWeek": 5,
               "subTopics": [{"unitNo": 1, "topicNo": 1, "subTopicNo": 2, "subTopicName": "N", "isCovered": False}]}]
        self.assertFalse([r for r in v.check_expectations(pl, v.EXPECTATIONS["weekly_planner"]) if r[1] == "FAIL"])
        self.assertFalse([r for r in v.check_expectations([], v.EXPECTATIONS["weekly_planner"]) if r[1] == "FAIL"])

    def test_drift_is_caught(self):
        lp = [{"_id": SECRET_ID, "topic": "T", "subject": "S", "gradeLevel": "G", "teacherId": SECRET_ID, "planDate": "2026-10-07", "status": "published"}]
        failed = {p for p, st, _ in v.check_expectations(lp, v.EXPECTATIONS["lesson_plans_mine"]) if st == "FAIL"}
        self.assertEqual(failed, {"[].status"})
        syl = [{"_id": SECRET_ID, "subjectName": "S", "gradeLevel": "G", "academicYearLabel": "y", "status": "live", "units": {}}]
        failed = {p for p, st, _ in v.check_expectations(syl, v.EXPECTATIONS["syllabi"]) if st == "FAIL"}
        self.assertEqual(failed, {"[].status", "[].units"})
        pl = [{"syllabusId": SECRET_ID, "subjectName": "S", "gradeLevel": "G", "currentWeek": "5", "subTopics": []}]
        failed = {p for p, st, _ in v.check_expectations(pl, v.EXPECTATIONS["weekly_planner"]) if st == "FAIL"}
        self.assertEqual(failed, {"[].currentWeek"})

    def test_values_are_never_printed_for_the_new_endpoints(self):
        rep = v.Report()
        buf = io.StringIO()
        with redirect_stdout(buf):
            rep.endpoint("teacher", "GET /teaching/lesson-plans?teacherId", 200,
                         [{"_id": SECRET_ID, "topic": SECRET_NAME, "rejectionReason": SECRET_EMAIL, "status": "draft", "subject": "S", "gradeLevel": "G",
                           "teacherId": SECRET_ID, "planDate": "2026-10-07"}], "lesson_plans_mine")
        out = buf.getvalue()
        for secret in (SECRET_ID, SECRET_NAME, SECRET_EMAIL):
            self.assertNotIn(secret, out)

    def test_only_get_endpoints_are_called_for_6a(self):
        src = open(v.__file__).read()
        block = src[src.index("# Phase 6a (all GET"):src.index("    if class_teacher:\n        grade =")]
        self.assertNotIn('http("POST"', block)
        self.assertNotIn('"PATCH"', block)
        self.assertNotIn("mark-topic", block)
        self.assertNotIn("parse-upload", block)
        self.assertTrue(v.request_allowed("GET", "/syllabus"))
        self.assertFalse(v.request_allowed("PATCH", "/syllabus/x/mark-topic"))
        self.assertFalse(v.request_allowed("POST", "/teaching/lesson-plans/parse-upload"))


class TestPhase6bExpectations(unittest.TestCase):
    def ok(self, key, body):
        return [r for r in v.check_expectations(body, v.EXPECTATIONS[key]) if r[1] == "FAIL"]

    def test_good_shapes_pass_and_unread_keys_are_ignored(self):
        asm = {"data": [{"_id": SECRET_ID, "title": "T", "type": "unit_test", "grade": "Grade 5", "section": None, "academicYear": "2026-27", "term": "Term 1",
                         "startDate": "2026-10-05T00:00:00.000Z", "status": "ongoing", "resultPublished": False, "gradeCardsGenerated": False,
                         "deliveryMode": "teacher_marked", "subjects": [{"subject": "Maths", "totalMarks": 50, "passingMarks": 20}],
                         "gradingScale": {"A": 1}, "createdBy": SECRET_NAME}], "meta": {"total": 1, "pages": 1}}
        self.assertFalse(self.ok("assessments_list", asm))
        marks = {"data": [{"_id": SECRET_ID, "studentId": SECRET_ID, "studentName": "N", "rollNumber": "1", "subject": "Maths", "totalMarks": 50,
                           "obtainedMarks": None, "isAbsent": True, "isExempt": False, "verified": False, "enteredBy": None}], "meta": {"total": 1, "pages": 1}}
        self.assertFalse(self.ok("marks_list", marks))
        cards = {"data": [{"_id": SECRET_ID, "studentId": SECRET_ID, "studentName": "N", "grade": "Grade 5", "published": False}], "meta": {"pages": 1}}
        self.assertFalse(self.ok("report_cards", cards))
        qa = [{"_id": SECRET_ID, "studentName": "N", "subject": "M", "grade": "G", "status": "submitted", "totalMarks": 10, "answers": [{"questionId": SECRET_ID, "needsManualGrading": True}]}]
        self.assertFalse(self.ok("quiz_attempts", qa))
        self.assertFalse(self.ok("quiz_attempts", []))
        cur = [{"_id": SECRET_ID, "name": "N", "gradeLevel": "G", "status": "active", "slos": [{"sloCode": "A", "description": "d"}]}]
        self.assertFalse(self.ok("curricula", cur))
        books = {"data": [{"_id": SECRET_ID, "title": "T", "author": "A", "totalCopies": 3, "availableCopies": 1, "purchasePrice": 99}], "meta": {"total": 1, "pages": 1}}
        self.assertFalse(self.ok("library_books", books))

    def test_drift_is_caught(self):
        asm = {"data": [{"_id": SECRET_ID, "title": "T", "type": "x", "grade": "G", "academicYear": "y", "startDate": "2026-10-05", "status": "open", "subjects": [{"subject": "M", "totalMarks": "50"}]}], "meta": {"total": 1, "pages": 1}}
        failed = {p for p, st, _ in v.check_expectations(asm, v.EXPECTATIONS["assessments_list"]) if st == "FAIL"}
        self.assertEqual(failed, {"data[].status", "data[].subjects[].totalMarks"})
        marks = {"data": [{"_id": SECRET_ID, "studentId": SECRET_ID, "studentName": "N", "rollNumber": "1", "subject": "M", "totalMarks": 5, "verified": "yes"}], "meta": {"total": 1, "pages": 1}}
        self.assertEqual({p for p, st, _ in v.check_expectations(marks, v.EXPECTATIONS["marks_list"]) if st == "FAIL"}, {"data[].verified"})
        qa = [{"_id": SECRET_ID, "studentName": "N", "subject": "M", "grade": "G", "status": "graded", "totalMarks": 10, "answers": []}]
        self.assertEqual({p for p, st, _ in v.check_expectations(qa, v.EXPECTATIONS["quiz_attempts"]) if st == "FAIL"}, {"[].status"})

    def test_values_are_never_printed(self):
        rep = v.Report()
        buf = io.StringIO()
        with redirect_stdout(buf):
            rep.endpoint("teacher", "GET /assessments", 200, {"data": [{"_id": SECRET_ID, "title": SECRET_NAME, "createdBy": SECRET_EMAIL, "type": "quiz", "grade": "G",
                                                                        "academicYear": "y", "startDate": "2026-10-05", "status": "ongoing", "subjects": []}], "meta": {"total": 1, "pages": 1}},
                         "assessments_list")
        out = buf.getvalue()
        for secret in (SECRET_ID, SECRET_NAME, SECRET_EMAIL):
            self.assertNotIn(secret, out)

    def test_only_get_endpoints_are_called_for_6b(self):
        src = open(v.__file__).read()
        block = src[src.index("# Phase 6b (all GET"):src.index("    if class_teacher:\n        grade =")]
        block = "\n".join(l for l in block.splitlines() if not l.strip().startswith("#"))  # the comment names what is NOT called
        for bad in ('http("POST"', '"PATCH"', '"PUT"', '"DELETE"', "marks/bulk", "marks/verify", "report-cards/generate", "report-cards/publish", "/remarks", "/grade", "library/issue", "library/return", "/slo"):
            self.assertNotIn(bad, block)
        self.assertTrue(v.request_allowed("GET", "/assessments/marks/list"))
        for path in ("/assessments/marks/bulk", "/assessments/marks/verify", "/assessments/report-cards/publish", "/assessments/quiz-attempts/x/grade", "/academics/library/issue"):
            self.assertFalse(v.request_allowed("POST", path), path)
        self.assertFalse(v.request_allowed("PATCH", "/assessments/report-cards/x/remarks"))


class TestPhase7bExpectations(unittest.TestCase):
    def ok(self, key, body):
        return all(st != "FAIL" for _, st, _ in v.check_expectations(body, v.EXPECTATIONS[key]))

    def test_good_stub_bodies_pass(self):
        import stub_server as s
        import stub_7b as p
        T = s.ACCOUNTS["teacher"]
        p.reset()
        p.seed()
        pm = p.list_meetings(T, {"teacherId": [T["staffId"]]})[1]
        self.assertTrue(self.ok("ptm_mine", pm))
        self.assertTrue(self.ok("ptm_one", pm[0]))
        self.assertTrue(self.ok("ptm_history", p.student_history(T, pm[0]["studentId"])[1]))
        self.assertTrue(self.ok("fixtures_mine", p.list_fixtures(T, {"teacherId": [T["staffId"]]})[1]))
        self.assertTrue(self.ok("leave_balance", p.leave_balance(T)[1]))
        self.assertTrue(self.ok("leave_history", p.leave_history(T)[1]))
        self.assertEqual(v.contact_key_names(pm), [])

    def test_drift_is_caught(self):
        bad = [{"_id": SECRET_ID, "studentId": SECRET_ID, "studentName": "N", "teacherId": SECRET_ID, "scheduledDate": "2026-10-05T00:00:00.000Z", "status": "rescheduled"}]
        self.assertEqual({p for p, st, _ in v.check_expectations(bad, v.EXPECTATIONS["ptm_mine"]) if st == "FAIL"}, {"[].status"})
        fx = [{"_id": SECRET_ID, "date": "2026-10-05T00:00:00.000Z", "originalTeacherId": SECRET_ID, "status": "pending"}]
        self.assertEqual({p for p, st, _ in v.check_expectations(fx, v.EXPECTATIONS["fixtures_mine"]) if st == "FAIL"}, {"[].status"})
        lv = [{"_id": SECRET_ID, "leaveType": "vacation", "fromDate": "2026-10-05", "toDate": "2026-10-06", "totalDays": "2", "reason": "r", "status": "pending"}]
        self.assertEqual({p for p, st, _ in v.check_expectations(lv, v.EXPECTATIONS["leave_history"]) if st == "FAIL"}, {"[].leaveType", "[].totalDays"})
        bal = {"hasPolicy": "yes", "annual": {"entitled": 21, "used": 4, "remaining": "17"}, "sick": {}, "casual": {}, "maternity": {}, "paternity": {}, "hajj": {}}
        self.assertEqual({p for p, st, _ in v.check_expectations(bal, v.EXPECTATIONS["leave_balance"]) if st == "FAIL"}, {"hasPolicy", "annual.remaining"})

    def test_guardian_contact_keys_in_ptm_rows_are_reported_by_name_only(self):
        rows = [{"_id": SECRET_ID, "guardianName": SECRET_NAME, "guardianPhone": "0300-1", "guardianEmail": SECRET_EMAIL}]
        self.assertEqual(v.contact_key_names(rows), ["guardianEmail", "guardianPhone"])

    def test_values_are_never_printed(self):
        rep = v.Report()
        buf = io.StringIO()
        with redirect_stdout(buf):
            rep.endpoint("teacher", "GET /hr/leave/self/history", 200, [{"_id": SECRET_ID, "leaveType": "sick", "fromDate": "2026-10-05T00:00:00.000Z", "toDate": "2026-10-06T00:00:00.000Z",
                                                                      "totalDays": 2, "reason": SECRET_NAME, "status": "approved", "approverName": SECRET_NAME,
                                                                      "approvedBy": {"email": SECRET_EMAIL}}], "leave_history")
        out = buf.getvalue()
        for secret in (SECRET_ID, SECRET_NAME, SECRET_EMAIL):
            self.assertNotIn(secret, out)

    def test_only_get_endpoints_are_called_for_7b(self):
        src = open(v.__file__).read()
        block = src[src.index("# Phase 7b (all GET"):src.index("    if class_teacher:\n        grade =")]
        block = "\n".join(l for l in block.splitlines() if not l.strip().startswith("#"))
        for bad in ('http("POST"', '"PATCH"', '"PUT"', '"DELETE"', "/confirm", "/reschedule", "/outcome", "/cancel", "/complete", "action-items", "hr/leave/self\", {"):
            self.assertNotIn(bad, block)
        self.assertTrue(v.request_allowed("GET", "/hr/leave/self/balance"))
        for path in ("/hr/leave/self", "/teaching/ptm", "/teaching/ptm/x/confirm", "/teaching/fixtures/x/complete"):
            self.assertFalse(v.request_allowed("POST", path), path)
        for path in ("/teaching/ptm/x/cancel", "/teaching/ptm/x/outcome", "/teaching/fixtures/x/complete"):
            self.assertFalse(v.request_allowed("PATCH", path), path)


class TestPhase7cExpectations(unittest.TestCase):
    def ok(self, key, body):
        return all(st != "FAIL" for _, st, _ in v.check_expectations(body, v.EXPECTATIONS[key]))

    def test_good_stub_bodies_pass_the_schema_checks(self):
        import stub_server as s
        import stub_7c as p
        T = s.ACCOUNTS["teacher"]
        cal = p.list_calendar({"from": ["2000-01-01"], "to": ["2100-01-01"]})[1]
        self.assertTrue(self.ok("calendar_events", cal))
        self.assertTrue(self.ok("circulars", p.list_circulars(T, {"status": ["published"]})[1]))
        evs = p.list_events()[1]
        self.assertTrue(self.ok("events_list", evs))
        self.assertTrue(self.ok("event_one", p.get_event(evs[0]["_id"])[1]))
        kb = p.kb_list({})[1]
        self.assertTrue(self.ok("kb_list", kb))
        self.assertTrue(self.ok("kb_one", p.kb_one("hr", "employees")[1]))

    def test_fee_leak_in_the_stub_is_detected_by_key_name_and_row_count_only(self):
        import stub_7c as p
        cal = p.list_calendar({"from": ["2000-01-01"], "to": ["2100-01-01"]})[1]
        self.assertGreaterEqual(v.fee_row_count(cal), 2)  # type fee_due / source finance rows (SCS:91-103)
        self.assertEqual(v.fee_like_key_names(cal), [])  # the real calendar rows carry no fee-like KEY names: the leak is in the rows' values
        ev = p.get_event(p.list_events()[1][0]["_id"])[1]
        names = v.fee_like_key_names(ev)
        self.assertIn("ticketTypes", names)
        self.assertIn("promoCodes", names)
        self.assertIn("price", names)
        self.assertEqual(v.fee_like_key_names(p.list_events()[1]), [])

    def test_fee_check_fails_the_run_and_prints_no_values(self):
        import stub_7c as p
        cal = p.list_calendar({"from": ["2000-01-01"], "to": ["2100-01-01"]})[1]
        rep = v.Report()
        buf = io.StringIO()
        with redirect_stdout(buf):
            rep.fee_check(cal, "calendar rows", rows=cal)
        out = buf.getvalue()
        self.assertEqual(rep.fails, 1)
        self.assertIn("FAIL FEE", out)
        self.assertIn("finance row(s)", out)
        for leak in ("Total outstanding", "845000", "Fee Due"):
            self.assertNotIn(leak, out)

    def test_fee_check_passes_on_clean_payloads(self):
        rep = v.Report()
        with redirect_stdout(io.StringIO()):
            rep.fee_check([{"_id": "a", "title": "Holiday", "type": "holiday", "startDate": "2026-10-12T00:00:00.000Z"}], "calendar rows", rows=[{"type": "holiday"}])
            rep.fee_check({"_id": "e", "title": "Annual day", "sessions": []}, "event detail")
        self.assertEqual(rep.fails, 0)

    def test_event_detail_leak_fails_and_only_names_are_printed(self):
        body = {"_id": SECRET_ID, "title": SECRET_NAME, "ticketTypes": [{"name": "VIP", "price": 123456}], "promoCodes": [{"code": "SECRETCODE"}]}
        rep = v.Report()
        buf = io.StringIO()
        with redirect_stdout(buf):
            rep.fee_check(body, "event detail")
        out = buf.getvalue()
        self.assertEqual(rep.fails, 1)
        for secret in (SECRET_ID, SECRET_NAME, "123456", "SECRETCODE"):
            self.assertNotIn(secret, out)
        self.assertIn("ticketTypes", out)

    def test_audience_counts_are_counts_only(self):
        rows = [{"status": "published", "audience": {"roles": ["staff"]}}, {"status": "draft", "audience": {"roles": ["staff"]}}, {"status": "published", "audience": {"roles": ["parent"]}}]
        self.assertEqual(v.audience_counts(rows), (3, 1, 1))

    def test_schema_drift_is_caught(self):
        bad = [{"_id": "x", "title": "T", "type": "festival", "startDate": "12/10/2026", "endDate": "2026-10-12T00:00:00.000Z"}]
        self.assertEqual({pth for pth, st, _ in v.check_expectations(bad, v.EXPECTATIONS["calendar_events"]) if st == "FAIL"}, {"[].type", "[].startDate"})
        ev = [{"_id": SECRET_ID, "title": "T", "status": "live", "visibility": "public"}]
        self.assertEqual({pth for pth, st, _ in v.check_expectations(ev, v.EXPECTATIONS["events_list"]) if st == "FAIL"}, {"[].status"})

    def test_values_are_never_printed_for_circulars_or_kb(self):
        rep = v.Report()
        buf = io.StringIO()
        with redirect_stdout(buf):
            rep.endpoint("teacher", "GET /school-calendar/circulars", 200, [{"_id": SECRET_ID, "title": SECRET_NAME, "body": "<p>" + SECRET_NAME + "</p>", "status": "published", "audience": {"roles": ["staff"], "scope": "school"}}], "circulars")
            rep.endpoint("teacher", "GET /kb/articles", 200, [{"module": "hr", "tabKey": "a", "title": SECRET_NAME, "body": SECRET_NAME}], "kb_list")
        for secret in (SECRET_ID, SECRET_NAME):
            self.assertNotIn(secret, buf.getvalue())

    def test_only_get_endpoints_are_called_for_7c(self):
        src = open(v.__file__).read()
        block = src[src.index("# Phase 7c (all GET"):src.index("    if class_teacher:\n        grade =")]
        block = "\n".join(l for l in block.splitlines() if not l.strip().startswith("#"))
        for bad in ('http("POST"', '"PATCH"', '"PUT"', '"DELETE"', "acknowledge", "compliance/safeguarding", "me/avatar", "delete-request"):
            self.assertNotIn(bad, block)
        for path in ("/school-calendar/circulars/x/acknowledge", "/compliance/safeguarding", "/auth/me/avatar", "/staff-portal/account/delete-request"):
            self.assertFalse(v.request_allowed("POST", path), path)
        self.assertTrue(v.request_allowed("GET", "/kb/search"))


if __name__ == "__main__":
    unittest.main()
