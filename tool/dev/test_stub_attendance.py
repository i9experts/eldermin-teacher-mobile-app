#!/usr/bin/env python3
"""Tests for the stub's attendance emulation and for the app's timezone-agnostic date protocol (mirrors
lib/core/models/classroom/attendance_models.dart): write `date` as noon UTC, read with [(D-1) 12:00Z, D 12:00Z],
map a stored instant to its day as utc(instant + 12h). Run: python3 tool/dev/test_stub_attendance.py"""
import datetime
import os
import sys
import time
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s

CT = s.ACCOUNTS["classteacher"]


def wire(day):
    return f"{day.isoformat()}T12:00:00.000Z"


def window(first, last):
    f = (first - datetime.timedelta(days=1)).isoformat() + "T12:00:00.000Z"
    return f, last.isoformat() + "T12:00:00.000Z"


def day_key(date_str):
    epoch = s._js_parse_date(date_str) + 12 * 3600
    return time.strftime("%Y-%m-%d", time.gmtime(epoch))


class TzCase(unittest.TestCase):
    def setUp(self):
        self._old = os.environ.get("TZ")
        s.seed_attendance(0)

    def tearDown(self):
        if self._old is None:
            os.environ.pop("TZ", None)
        else:
            os.environ["TZ"] = self._old
        time.tzset()

    def use(self, tz):
        os.environ["TZ"] = tz
        time.tzset()
        s.seed_attendance(0)

    def roundtrip(self, day):
        roster = s._roster_5a()
        recs = [{"studentId": r["_id"], "studentName": "X", "grade": "Grade 5", "section": "A", "date": wire(day),
                 "status": "present"} for r in roster[:3]]
        status, _ = s.attendance_bulk(CT, {"records": recs}, "2026-27")
        self.assertEqual(status, 201)
        f, t = window(day, day)
        status, body = s.attendance_list_real(CT, {"grade": ["Grade 5"], "section": ["A"], "from": [f], "to": [t], "limit": ["1000"]})
        self.assertEqual(status, 200)
        mine = [r for r in body["data"] if r["studentId"] in {x["studentId"] for x in recs}]
        return mine


class TestAttendanceProtocol(TzCase):
    def test_roundtrip_in_supported_server_zones(self):
        today = datetime.date.today() + datetime.timedelta(days=0)
        for tz in ["UTC", "Asia/Karachi", "America/Los_Angeles", "America/New_York", "Asia/Kolkata", "Asia/Tokyo", "Pacific/Auckland", "Pacific/Kiritimati", "Pacific/Pago_Pago"]:
            self.use(tz)
            for day in [today, datetime.date(2026, 3, 1), datetime.date(2026, 12, 31)]:
                mine = self.roundtrip(day)
                self.assertEqual(len(mine), 3, f"{tz} {day}: records not found in the window")
                self.assertTrue(all(day_key(r["date"]) == day.isoformat() for r in mine), f"{tz} {day}: wrong day key")

    def test_neighbouring_days_do_not_leak(self):
        for tz in ["UTC", "Asia/Karachi", "America/Los_Angeles"]:
            self.use(tz)
            d = datetime.date(2026, 10, 5)
            self.roundtrip(d - datetime.timedelta(days=1))
            self.roundtrip(d + datetime.timedelta(days=1))
            f, t = window(d, d)
            status, body = s.attendance_list_real(CT, {"grade": ["Grade 5"], "section": ["A"], "from": [f], "to": [t], "limit": ["1000"]})
            self.assertFalse([r for r in body["data"] if day_key(r["date"]) != d.isoformat()], tz)

    def test_plain_date_only_write_lands_on_previous_day_west_of_utc(self):
        self.use("America/Los_Angeles")
        roster = s._roster_5a()
        s.attendance_bulk(CT, {"records": [{"studentId": roster[0]["_id"], "studentName": "X", "grade": "Grade 5", "section": "A",
                                            "date": "2026-10-05", "status": "present"}]}, None)
        key = [r for r in s.ATT.values() if r["studentId"] == roster[0]["_id"] and r["academicYear"] == "2025-26"]
        self.assertEqual(day_key(key[0]["date"]), "2026-10-04")  # why the app sends noon UTC instead

    def test_documented_limit_utc_minus_12(self):
        """Offsets of exactly -12h (no inhabited zone; Etc/GMT+12) are the one place the scheme breaks: the stored midnight
        lands on the window boundary and maps to the next day."""
        self.use("Etc/GMT+12")
        day = datetime.date(2026, 10, 5)
        mine = self.roundtrip(day)
        ok = len(mine) == 3 and all(day_key(r["date"]) == day.isoformat() for r in mine)
        self.assertFalse(ok)


class TestStubSemantics(TzCase):
    def test_date_param_is_ignored_like_the_dto_strips_it(self):
        status, body = s.attendance_list_real(CT, {"grade": ["Grade 5"], "section": ["A"], "date": ["2020-01-01"], "limit": ["5"]})
        self.assertEqual(status, 200)
        self.assertEqual(len(body["data"]), 5)  # latest records of any date: the web's `date=` bug

    def test_exact_grade_match_and_class_teacher_scope(self):
        status, _ = s.attendance_list_real(CT, {"grade": ["Grade 6"]})
        self.assertEqual(status, 403)
        status, body = s.attendance_list_real(CT, {"grade": ["5"], "section": ["a"], "limit": ["1000"]})
        self.assertEqual(status, 200)  # normalised comparison for the scope check, forced to the claim's strings
        self.assertTrue(all(r["grade"] == "Grade 5" for r in body["data"]))

    def test_bulk_validation_and_scope(self):
        roster = s._roster_5a()
        base = {"studentId": roster[0]["_id"], "studentName": "X", "grade": "Grade 5", "section": "A", "date": "2026-10-05", "status": "present"}
        self.assertEqual(s.attendance_bulk(CT, {"records": [dict(base, status="holiday")]}, None)[0], 400)
        self.assertEqual(s.attendance_bulk(CT, {"records": [dict(base, studentId="nope")]}, None)[0], 400)
        self.assertEqual(s.attendance_bulk(CT, {"records": [dict(base, date="2026-13-45")]}, None)[0], 400)
        self.assertEqual(s.attendance_bulk(CT, {"records": [dict(base, grade="Grade 6")]}, None)[0], 403)
        self.assertEqual(s.attendance_bulk(CT, {}, None)[0], 400)
        st, resp = s.attendance_bulk(CT, {"records": [base]}, None)
        self.assertEqual(st, 201)
        self.assertIn("nUpserted", resp)  # shape UNVERIFIED (U5): the app does not read it

    def test_academic_year_comes_from_the_header_else_the_literal_default(self):
        roster = s._roster_5a()
        rec = {"studentId": roster[1]["_id"], "studentName": "X", "grade": "Grade 5", "section": "A", "date": "2026-10-06T12:00:00.000Z", "status": "late"}
        s.attendance_bulk(CT, {"records": [rec]}, "2026-27")
        self.assertEqual(s.ATT[(roster[1]["_id"], s._local_midnight(s._js_parse_date(rec["date"])))]["academicYear"], "2026-27")
        s.attendance_bulk(CT, {"records": [dict(rec, status="absent")]}, None)
        self.assertEqual(s.ATT[(roster[1]["_id"], s._local_midnight(s._js_parse_date(rec["date"])))]["academicYear"], "2025-26")

    def test_students_list_carries_fee_and_guardian_contact_fields_on_purpose(self):
        st, body = s.students_list({"grade": ["Grade 5"], "limit": ["5"]}, CT)
        self.assertEqual(st, 200)
        row = body["data"][0]
        self.assertIn("monthlyTuitionFee", row)
        self.assertIn("phone", row["guardians"][0])
        self.assertEqual(s.students_list({"limit": ["1001"]}, CT)[0], 400)

    def test_360_has_a_fees_block_and_the_fixed_shape(self):
        sid = s._roster_5a()[0]["_id"]
        st, body = s.student_360(sid)
        self.assertEqual(st, 200)
        self.assertEqual(set(body), {"student", "attendance", "fees", "behaviour", "assessments"})
        self.assertEqual(s.student_360("64f000000000000000000fff")[0], 404)


if __name__ == "__main__":
    unittest.main()
