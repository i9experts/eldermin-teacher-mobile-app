#!/usr/bin/env python3
"""Tests for the Phase 6b stub (assessments, marks entry, report remarks, quiz grading, curriculum, library): the contract the Dart
repositories rely on, including the server's integrity GAPS (no total check, no verified lock) that the app must compensate for.
Run: python3 tool/dev/test_stub_6b.py"""
import http.client
import json
import os
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_6b as p

T = s.ACCOUNTS["teacher"]


def asm(title_prefix):
    return next(a for a in p._state["assessments"].values() if a["title"].startswith(title_prefix))


def roster_5a():
    return p._roster("5", "a")


def row(st, **kw):
    d = {"studentId": st["_id"], "studentName": f"{st['firstName']} {st['lastName']}", "rollNumber": st["currentRollNumber"], "section": "A",
         "obtainedMarks": 10, "isAbsent": False, "isExempt": False, "remarks": ""}
    d.update(kw)
    return d


class Assessments(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def test_list_is_paginated_filtered_and_unscoped_to_teacher(self):
        st, r = p.list_assessments(T, {"limit": ["100"]})
        self.assertEqual((st, r["meta"]["total"]), (200, 10))
        self.assertEqual(p.list_assessments(T, {"limit": ["3"], "page": ["2"]})[1]["data"].__len__(), 3)
        self.assertEqual(p.list_assessments(T, {"limit": ["0"]})[0], 400)
        grades = {a["grade"] for a in r["data"]}
        self.assertIn("Grade 7", grades)  # the server does NOT scope to the teacher: the app must
        self.assertEqual([a["grade"] for a in p.list_assessments(T, {"grade": ["Grade 6"]})[1]["data"]], ["Grade 6"])
        dates = [a["startDate"] for a in r["data"]]
        self.assertEqual(dates, sorted(dates, reverse=True))

    def test_all_sections_assessment_has_no_section_key(self):
        self.assertNotIn("section", asm("Mid-Term"))

    def test_one_404_and_invalid_id_500(self):
        self.assertEqual(p.get_assessment(T, p._state["assessments"] and asm("Unit Test 1")["_id"])[0], 200)
        self.assertEqual(p.get_assessment(T, "64f" + "0" * 21)[0], 404)
        self.assertEqual(p.get_assessment(T, "nope")[0], 500)

    def test_real_payload_carries_fields_the_app_never_parses(self):
        a = asm("Unit Test 1")
        for k in ("gradingScale", "createdBy", "schoolSlug", "campusId"):
            self.assertIn(k, a)


class Marks(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()
        self.a1 = asm("Unit Test 1")
        self.ros = roster_5a()

    def test_list_filters_and_string_roll_sort(self):
        st, r = p.list_marks(T, {"assessmentId": [self.a1["_id"]], "subject": ["Mathematics"], "limit": ["200"]})
        self.assertEqual(st, 200)
        self.assertEqual(r["meta"]["total"], 13)
        rolls = [m["rollNumber"] for m in r["data"]]
        self.assertEqual(rolls, sorted(rolls))  # STRING order: '10' before '2'
        self.assertEqual(p.list_marks(T, {"assessmentId": ["x"]})[0], 400)
        absent = [m for m in r["data"] if m["isAbsent"]]
        self.assertEqual(len(absent), 1)
        self.assertNotIn("percentage", absent[0])

    def test_partly_verified_and_fully_verified_sheets(self):
        mid = asm("Mid-Term")
        rows = p.list_marks(T, {"assessmentId": [mid["_id"]], "limit": ["200"]})[1]["data"]
        self.assertEqual(sum(1 for m in rows if m["verified"]), 10)
        self.assertEqual(len(rows), 12)
        t1 = asm("Term 1 Result")
        self.assertTrue(all(m["verified"] for m in p.list_marks(T, {"assessmentId": [t1["_id"]], "limit": ["200"]})[1]["data"]))
        allv = p.list_marks(T, {"assessmentId": [mid["_id"]], "limit": ["200"]}, mode="allverified")[1]["data"]
        self.assertTrue(all(m["verified"] for m in allv))

    def test_bulk_body_validation_messages(self):
        body = {"assessmentId": self.a1["_id"], "subject": "Mathematics", "grade": "Grade 5", "marks": [row(self.ros[0], obtainedMarks=-1)]}
        self.assertEqual(p.bulk_marks(T, body), (400, "marks.0.obtainedMarks must not be less than 0"))
        body["marks"] = [row(self.ros[0], obtainedMarks="12")]
        self.assertEqual(p.bulk_marks(T, body)[0], 400)
        body["marks"] = [row(self.ros[0], studentId="zz")]
        self.assertEqual(p.bulk_marks(T, body), (400, "marks.0.studentId must be a mongodb id"))
        body["marks"] = [row(self.ros[0], rollNumber=None)]
        self.assertEqual(p.bulk_marks(T, body)[1], "marks.0.rollNumber must be a string")
        self.assertEqual(p.bulk_marks(T, {**body, "subject": "Art", "marks": [row(self.ros[0])]}), (400, "Subject Art not in assessment"))
        self.assertEqual(p.bulk_marks(T, {**body, "assessmentId": "64f" + "0" * 21, "marks": []}), (404, "Assessment not found"))

    def test_bulk_null_marks_are_accepted_for_absent_and_exempt(self):
        body = {"assessmentId": self.a1["_id"], "subject": "Mathematics", "grade": "Grade 5",
                "marks": [row(self.ros[0], obtainedMarks=None, isAbsent=True), row(self.ros[1], obtainedMarks=None, isExempt=True)]}
        st, r = p.bulk_marks(T, body, academic_year_header="2026-27")
        self.assertEqual((st, r["message"]), (201, "Marks entered for 2 students"))
        m0 = p._state["marks"][(self.a1["_id"], self.ros[0]["_id"], "Mathematics")]
        self.assertTrue(m0["isAbsent"] and m0["obtainedMarks"] is None and m0["result"] == "absent")
        self.assertEqual(p.state_summary()["lastBulkAcademicYearHeader"], "2026-27")

    def test_server_gaps_marks_above_total_and_verified_rows_are_accepted(self):
        mid = asm("Mid-Term")
        verified = next(r for r in p._state["marks"].values() if r["assessmentId"] == mid["_id"] and r["verified"])
        st_row = p.S.STUDENTS_BY_ID[verified["studentId"]]
        body = {"assessmentId": mid["_id"], "subject": "Mathematics", "grade": "Grade 5", "marks": [row(st_row, obtainedMarks=250)]}
        self.assertEqual(p.bulk_marks(T, body)[0], 201)  # 250 > 100 total: NOT rejected by the server (AS:1239-1299)
        after = p._state["marks"][(mid["_id"], st_row["_id"], "Mathematics")]
        self.assertEqual(after["obtainedMarks"], 250)
        self.assertTrue(after["verified"])  # still 'verified' with the NEW value: the lock is not enforced
        self.assertTrue(p.state_summary()["lastBulk"]["sawOverTotal"])

    def test_bulk_partial_failure_writes_first_half_then_500(self):
        body = {"assessmentId": self.a1["_id"], "subject": "Mathematics", "grade": "Grade 5",
                "marks": [row(self.ros[i], obtainedMarks=7 + i) for i in range(20, 26)]}
        self.assertEqual(p.bulk_marks(T, body, mode="partial500")[0], 500)
        got = [p._state["marks"].get((self.a1["_id"], self.ros[i]["_id"], "Mathematics")) for i in range(20, 26)]
        self.assertEqual([g is not None for g in got], [True, True, True, False, False, False])

    def test_bulk_computes_result(self):
        body = {"assessmentId": self.a1["_id"], "subject": "Mathematics", "grade": "Grade 5",
                "marks": [row(self.ros[20], obtainedMarks=19), row(self.ros[21], obtainedMarks=45)]}
        p.bulk_marks(T, body)
        fail = p._state["marks"][(self.a1["_id"], self.ros[20]["_id"], "Mathematics")]
        ok = p._state["marks"][(self.a1["_id"], self.ros[21]["_id"], "Mathematics")]
        self.assertEqual((fail["result"], ok["result"], ok["grade_result"], ok["percentage"]), ("fail", "pass", "A+", 90.0))


class ReportCards(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def test_list_by_assessment_ordered_by_position_and_paginated(self):
        mid = asm("Mid-Term")
        st, r = p.list_report_cards(T, {"assessmentId": [mid["_id"]], "limit": ["5"]})
        self.assertEqual((st, r["meta"]["total"], r["meta"]["pages"]), (200, 15, 3))
        self.assertEqual([c["classPosition"] for c in r["data"]], [1, 2, 3, 4, 5])
        sections = {c["section"] for c in p.list_report_cards(T, {"limit": ["50"]})[1]["data"]}
        self.assertEqual({x.upper() for x in sections}, {"A", "B"})  # other sections are in the payload: the app scopes

    def test_remarks_whitelist_unknown_id_is_200_empty_and_invalid_500(self):
        c = next(iter(p._state["cards"].values()))
        st, d = p.update_remarks(T, c["_id"], {"classTeacherRemarks": "Nice work", "evil": 1})
        self.assertEqual((st, d["classTeacherRemarks"]), (200, "Nice work"))
        self.assertEqual(p.state_summary()["lastRemarks"]["keys"], ["classTeacherRemarks"])
        self.assertEqual(p.update_remarks(T, "64f" + "0" * 21, {"classTeacherRemarks": "x"}), (200, None))
        self.assertEqual(p.update_remarks(T, "bad", {})[0], 500)
        self.assertEqual(p.update_remarks(T, c["_id"], {"classTeacherRemarks": 5})[0], 400)

    def test_published_cards_can_still_be_edited_by_the_server(self):
        c = next(iter(p._state["cards"].values()))
        c["published"] = True
        self.assertEqual(p.update_remarks(T, c["_id"], {"principalRemarks": "teacher wrote this"})[0], 200)


class Quiz(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def pending(self):
        return p.list_attempts(T, {})[1]

    def test_list_only_submitted_oldest_first_unscoped(self):
        rows = self.pending()
        self.assertEqual(len(rows), 4)
        self.assertTrue(all(r["status"] == "submitted" for r in rows))
        self.assertEqual({(r["section"], r["subject"]) for r in rows}, {("A", "Mathematics"), ("B", "Mathematics"), ("A", "English")})
        self.assertEqual(p.list_attempts(T, {"assessmentId": ["bad"]})[0], 500)
        self.assertEqual(len(p.list_attempts(T, {"subject": ["English"]})[1]), 1)

    def test_detail_hydrates_questions_with_the_answer_key(self):
        att = self.pending()[0]
        st, d = p.get_attempt(T, att["_id"])
        self.assertEqual(st, 200)
        q = d["answers"][0]["question"]
        self.assertTrue(any(o["isCorrect"] for o in q["options"]))
        self.assertEqual([a["question"]["marks"] for a in d["answers"]], [2, 4, 4])
        self.assertEqual(p.get_attempt(T, att["_id"], mode="nopaper")[0], 404)
        self.assertEqual(p.get_attempt(T, "64f" + "0" * 21)[1], "Quiz attempt not found")

    def test_partial_then_final_grade_upserts_mark_entry_and_overwrites(self):
        att = next(a for a in self.pending() if a["section"] == "A" and a["subject"] == "Mathematics" and a["answers"][1]["marksAwarded"] is None)
        qs = [a["questionId"] for a in att["answers"]]
        st, d = p.grade_attempt(T, att["_id"], {"grades": [{"questionId": qs[1], "marksAwarded": 3}]})
        self.assertEqual((st, d["status"], d["obtainedMarks"]), (200, "submitted", None))  # still pending: no mark entry yet
        key = (att["assessmentId"], att["studentId"], "Mathematics")
        self.assertNotIn(key, p._state["marks"])
        st, d = p.grade_attempt(T, att["_id"], {"grades": [{"questionId": qs[2], "marksAwarded": 99}]})  # NO bounds check (server)
        self.assertEqual((d["status"], d["obtainedMarks"], d["gradedBy"]), ("graded", 2 + 3 + 99, "Tess Teacher"))
        self.assertEqual(p._state["marks"][key]["enteredBy"], "Online Quiz (auto)")

    def test_grading_ignores_auto_graded_answers_and_validates_shape(self):
        att = self.pending()[0]
        qs = [a["questionId"] for a in att["answers"]]
        p.grade_attempt(T, att["_id"], {"grades": [{"questionId": qs[0], "marksAwarded": 0}]})
        self.assertEqual(p._state["attempts"][att["_id"]]["answers"][0]["marksAwarded"], 2)  # auto mcq untouched
        self.assertEqual(p.grade_attempt(T, att["_id"], {"grades": [{"questionId": qs[1], "marksAwarded": "3"}]})[0], 400)
        self.assertEqual(p.grade_attempt(T, att["_id"], {})[1], "grades must be an array")
        self.assertEqual(p.grade_attempt(T, "64f" + "0" * 21, {"grades": []})[0], 404)

    def test_regrade_of_a_graded_attempt_is_accepted(self):
        graded = next(a for a in p._state["attempts"].values() if a["status"] == "graded")
        qs = [a["questionId"] for a in graded["answers"]]
        st, d = p.grade_attempt(T, graded["_id"], {"grades": [{"questionId": qs[1], "marksAwarded": 0}]})
        self.assertEqual((st, d["status"]), (200, "graded"))


class Reference(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def test_curriculum_list_filters_and_includes_drafts(self):
        rows = p.list_curricula(T, {})[1]
        self.assertEqual({r["status"] for r in rows}, {"active", "draft", "archived"})
        self.assertEqual({r["status"] for r in p.list_curricula(T, {"status": ["active"]})[1]}, {"active"})
        self.assertEqual(p.list_curricula(T, {"subjectId": ["bad"]})[0], 500)
        one = p.get_curriculum(T, rows[0]["_id"])[1]
        self.assertIn("slos", one)
        self.assertEqual(p.get_curriculum(T, "64f" + "0" * 21)[1], "Curriculum not found")

    def test_books_search_available_and_pagination(self):
        r = p.list_books(T, {"limit": ["10"], "page": ["2"]})[1]
        self.assertEqual((r["meta"]["total"], r["meta"]["pages"], len(r["data"])), (22, 3, 10))  # deaccessioned hidden
        titles = [b["title"] for b in p.list_books(T, {"limit": ["50"]})[1]["data"]]
        self.assertEqual(titles, sorted(titles))
        self.assertNotIn("Deaccessioned Old Atlas", titles)
        av = p.list_books(T, {"available": ["true"], "limit": ["50"]})[1]["data"]
        self.assertTrue(all(b["availableCopies"] > 0 for b in av))
        hits = p.list_books(T, {"search": ["fractions"]})[1]["data"]
        self.assertEqual(len(hits), 2)
        self.assertEqual(p.list_books(T, {"search": ["fract"]})[1]["meta"]["total"], 0)  # $text = whole words, not substrings
        self.assertEqual({b["category"] for b in p.list_books(T, {"category": ["islamic"]})[1]["data"]}, {"islamic"})

    def test_books_carry_fields_the_app_never_parses(self):
        b = p.list_books(T, {})[1]["data"][0]
        for k in ("purchasePrice", "tenantId", "copies", "issuedCopies"):
            self.assertIn(k, b)


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
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=15)
        h = {"Authorization": f"Bearer {token}"}
        h.update(headers or {})
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            h["Content-Type"] = "application/json"
        c.request(method, path, body=data, headers=h)
        r = c.getresponse()
        raw = r.read()
        c.close()
        try:
            return r.status, json.loads(raw) if raw else None
        except ValueError:
            return r.status, raw

    def test_routes_and_error_shape(self):
        st, r = self.call("GET", "/api/v1/assessments?limit=100")
        self.assertEqual((st, r["meta"]["total"]), (200, 10))
        aid = r["data"][0]["_id"]
        self.assertEqual(self.call("GET", f"/api/v1/assessments/{aid}")[0], 200)
        self.assertEqual(self.call("GET", "/api/v1/assessments/marks/list?limit=5")[1]["meta"]["limit"], 5)  # not swallowed by :id
        st, err = self.call("GET", "/api/v1/assessments/marks/list?assessmentId=zz")
        self.assertEqual(st, 400)
        self.assertEqual(set(err), {"statusCode", "message", "timestamp", "path"})
        self.assertEqual(self.call("GET", "/api/v1/assessments/quiz-attempts")[0], 200)
        self.assertEqual(self.call("GET", "/api/v1/academics/curriculum?status=active")[0], 200)
        self.assertEqual(self.call("GET", "/api/v1/academics/library/books?limit=3")[1]["meta"]["limit"], 3)

    def test_modes_403_empty_and_principal(self):
        self.call("POST", "/__stub/mode?feature=assessments&value=403")
        st, err = self.call("GET", "/api/v1/assessments")
        self.assertEqual((st, err["message"]), (403, "Forbidden resource"))
        self.call("POST", "/__stub/mode?feature=assessments&value=empty")
        self.assertEqual(self.call("GET", "/api/v1/assessments")[1]["data"], [])
        self.assertEqual(self.call("GET", "/api/v1/assessments", token="stub.principal.dummy")[0], 403)

    def test_bulk_over_http_header_and_state(self):
        p.seed()
        a1 = asm("Unit Test 1")
        st0 = roster_5a()[25]
        body = {"assessmentId": a1["_id"], "subject": "Mathematics", "grade": "Grade 5", "marks": [row(st0, obtainedMarks=33)]}
        st, r = self.call("POST", "/api/v1/assessments/marks/bulk", body, headers={"x-academic-year": "2026-27"})
        self.assertEqual((st, r["subject"]), (201, "Mathematics"))
        st, state = self.call("GET", "/__stub/state")
        self.assertEqual(state["phase6b"]["lastBulkAcademicYearHeader"], "2026-27")
        self.call("POST", "/__stub/mode?feature=marksbulk&value=400")
        st, err = self.call("POST", "/api/v1/assessments/marks/bulk", body)
        self.assertEqual(st, 400)

    def test_bigclass_roster_paginates_in_200_row_pages(self):
        q = "grade=Grade%205&section=A&status=active"
        self.assertEqual(self.call("GET", f"/api/v1/students?{q}&limit=200")[1]["meta"]["total"], 28)  # exact-string filter: the two "5"/"a" students are not matched (app re-scopes)
        self.call("POST", "/__stub/mode?feature=bigclass&value=on")
        st, r = self.call("GET", f"/api/v1/students?{q}&limit=200&page=1")
        self.assertEqual((r["meta"]["total"], r["meta"]["pages"], len(r["data"])), (227, 2, 200))
        self.assertEqual(len(self.call("GET", f"/api/v1/students?{q}&limit=200&page=2")[1]["data"]), 27)

    def test_remarks_route_and_empty_200(self):
        st, r = self.call("GET", "/api/v1/assessments/report-cards?limit=1")
        cid = r["data"][0]["_id"]
        st, d = self.call("PATCH", f"/api/v1/assessments/report-cards/{cid}/remarks", {"classTeacherRemarks": "Great"})
        self.assertEqual((st, d["classTeacherRemarks"]), (200, "Great"))
        st, d = self.call("PATCH", "/api/v1/assessments/report-cards/64f000000000000000000000/remarks", {"classTeacherRemarks": "x"})
        self.assertEqual((st, d), (200, None))


if __name__ == "__main__":
    unittest.main()
