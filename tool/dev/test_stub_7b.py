#!/usr/bin/env python3
"""Tests for the Phase 7b stub (PTM, substitutions, My Leave): the contract the Dart repositories rely on, with backend behaviours copied from
ptm.service.ts / substitution.service.ts / hr.service.ts (citations in stub_7b.py). Run: python3 tool/dev/test_stub_7b.py"""
import http.client
import json
import os
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_7b as p

T = s.ACCOUNTS["teacher"]
CT = s.ACCOUNTS["classteacher"]


def mine(a):
    return p.list_meetings(a, {"teacherId": [a["staffId"]]})[1]


class Ptm(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def test_list_filters_sorts_desc_and_never_leaks_guardian_phone_or_email(self):
        rows = mine(T)
        self.assertEqual(len(rows), 8)
        self.assertTrue(all(m["teacherId"] == T["staffId"] for m in rows))
        dates = [m["scheduledDate"] for m in rows]
        self.assertEqual(dates, sorted(dates, reverse=True))  # PS:136
        blob = json.dumps(rows).lower()
        for k in ("guardianphone", "guardianemail", "@example.test", "0300-"):
            self.assertNotIn(k, blob)  # the teacher projection (TP:59-70)
        self.assertTrue(all(m["guardianName"] for m in rows))  # PTM guardianName stays
        self.assertEqual({m["status"] for m in p.list_meetings(T, {"teacherId": [T["staffId"]], "status": ["cancelled"]})[1]}, {"cancelled"})
        self.assertEqual(len(p.list_meetings(T, {"teacherId": ["bad"]})), 2)
        self.assertEqual(p.list_meetings(T, {"teacherId": ["bad"]})[0], 500)

    def test_list_window_from_to(self):
        today = p._today()
        frm = p._midnight(today)
        ahead = p.list_meetings(T, {"teacherId": [T["staffId"]], "from": [frm]})[1]
        past = p.list_meetings(T, {"teacherId": [T["staffId"]], "to": [p._iso(p._parse_date(frm) - p.datetime.timedelta(milliseconds=1))]})[1]
        self.assertEqual(len(ahead) + len(past), 8)
        self.assertTrue(all(m["scheduledDate"] >= frm for m in ahead))

    def test_get_by_id_has_no_ownership_check_and_errors(self):
        other = next(m for m in p._state["ptm"].values() if m["teacherId"] == s.OTHER_STAFF)
        st, m = p.get_meeting(T, other["_id"])
        self.assertEqual(st, 200)  # PS:139-145: any meeting of the tenant
        self.assertEqual(p.get_meeting(T, "x"), (400, "Invalid meeting id"))
        self.assertEqual(p.get_meeting(T, p._oid(0xdead)), (404, "Meeting not found"))

    def test_student_history_lists_every_teachers_meetings(self):
        other = next(m for m in p._state["ptm"].values() if m["teacherId"] == s.OTHER_STAFF)
        st, rows = p.student_history(T, other["studentId"])
        self.assertEqual(st, 200)
        self.assertIn(other["_id"], [m["_id"] for m in rows])
        self.assertGreaterEqual(len({m["teacherId"] for m in rows}), 2)
        self.assertEqual(p.student_history(T, "bad"), (400, "Invalid student id"))

    def _create(self, **kw):
        st5 = next(x for x in s.STUDENTS if x["currentGrade"] == "Grade 5" and x["currentSection"] == "A" and x["status"] == "active")
        body = {"studentId": st5["_id"], "teacherId": T["staffId"], "scheduledDate": "2026-12-01", "startTime": "10:00", "endTime": "10:30",
                "academicYear": st5["currentAcademicYear"], "discussionPoints": ["Progress"]}
        body.update(kw)
        return p.create_meeting(T, body), body

    def test_create_requested_with_guardian_name_only_and_midnight_utc(self):
        (st, m), body = self._create()
        self.assertEqual(st, 201)
        self.assertEqual((m["status"], m["teacherId"], m["scheduledDate"]), ("requested", T["staffId"], "2026-12-01T00:00:00.000Z"))
        self.assertTrue(m["guardianName"])
        self.assertNotIn("guardianPhone", m)
        self.assertNotIn("guardianEmail", m)
        self.assertEqual(p._state["last_create"]["academicYear"], body["academicYear"])

    def test_create_rules(self):
        self.assertEqual(self._create(teacherId=s.OTHER_STAFF)[0], (403, "You can only create meetings for yourself"))
        (st, m), _ = self._create(teacherId=T["teacherProfileId"])
        self.assertEqual((st, m["teacherId"]), (201, T["staffId"]))  # TeacherProfile id normalised to the Staff id (TI:67-70)
        (st, m), _ = self._create(teacherId="")
        self.assertEqual((st, m["teacherId"]), (201, T["staffId"]))  # absent -> mine
        self.assertEqual(self._create(studentId=p._oid(0xbeef))[0], (404, "Student not found"))
        self.assertEqual(self._create(academicYear="")[0][0], 500)  # PSC:52 required (status UNVERIFIED)
        self.assertEqual(self._create(scheduledDate="not a date")[0][0], 500)

    def test_confirm_only_from_requested_and_no_ownership_check(self):
        req = next(m for m in mine(T) if m["status"] == "requested")
        self.assertEqual(p.confirm_meeting(T, req["_id"])[1]["status"], "confirmed")
        self.assertEqual(p.confirm_meeting(T, req["_id"]), (404, "Meeting not found or not in a requested state"))  # PS:161
        other = next(m for m in p._state["ptm"].values() if m["teacherId"] == s.OTHER_STAFF)
        other["status"] = "requested"
        self.assertEqual(p.confirm_meeting(T, other["_id"])[0], 200)  # someone else's meeting confirmed by me: the server allows it (backlog)

    def test_reschedule_ownership_status_and_resets_to_requested_and_clears_missing_times(self):
        conf = next(m for m in mine(T) if m["status"] == "confirmed")
        st, m = p.reschedule_meeting(T, conf["_id"], {"scheduledDate": "2026-12-05", "startTime": "09:00", "endTime": "09:20"})
        self.assertEqual((st, m["status"], m["scheduledDate"], m["startTime"]), (200, "requested", "2026-12-05T00:00:00.000Z", "09:00"))
        st, m = p.reschedule_meeting(T, conf["_id"], {"scheduledDate": "2026-12-06"})
        self.assertEqual((m["startTime"], m["endTime"]), (None, None))  # PS:171 omitted -> cleared
        done = next(m for m in mine(T) if m["status"] == "completed")
        self.assertEqual(p.reschedule_meeting(T, done["_id"], {"scheduledDate": "2026-12-05"}), (404, "Meeting not found or already completed/cancelled"))
        other = next(m for m in p._state["ptm"].values() if m["teacherId"] == s.OTHER_STAFF)
        self.assertEqual(p.reschedule_meeting(T, other["_id"], {"scheduledDate": "2026-12-05"}), (403, "You can only modify your own meetings"))
        self.assertEqual(p.reschedule_meeting(T, p._oid(0xdead), {"scheduledDate": "2026-12-05"}), (404, "Meeting not found"))

    def test_outcome_status_from_attendance_replaces_items_and_refuses_cancelled(self):
        conf = next(m for m in mine(T) if m["status"] == "confirmed")
        st, m = p.record_outcome(T, conf["_id"], {"parentAttended": True, "meetingNotes": "Good", "actionItems": [{"description": "Read", "assignedTo": "Parent", "dueDate": "2026-12-20"}]})
        self.assertEqual((st, m["status"], m["parentAttended"], m["meetingNotes"]), (200, "completed", True, "Good"))
        self.assertEqual((m["actionItems"][0]["status"], m["actionItems"][0]["dueDate"]), ("pending", "2026-12-20T00:00:00.000Z"))
        st, m = p.record_outcome(T, conf["_id"], {"parentAttended": False})
        self.assertEqual((m["status"], m["meetingNotes"]), ("no_show", ""))
        canc = next(m for m in mine(T) if m["status"] == "cancelled")
        self.assertEqual(p.record_outcome(T, canc["_id"], {"parentAttended": True}), (400, "Cannot record an outcome for a cancelled meeting"))
        other = next(m for m in p._state["ptm"].values() if m["teacherId"] == s.OTHER_STAFF)
        self.assertEqual(p.record_outcome(T, other["_id"], {"parentAttended": True})[0], 403)

    def test_action_item_toggle_and_cancel_have_no_ownership_or_status_checks(self):
        done = next(m for m in mine(T) if m["status"] == "completed" and m["actionItems"])
        aid = done["actionItems"][0]["_id"]
        self.assertEqual(p.set_action_item(T, done["_id"], aid, {"status": "done"})[1]["actionItems"][0]["status"], "done")
        self.assertEqual(p.set_action_item(T, done["_id"], p._oid(0xdead), {"status": "done"}), (404, "Action item not found"))
        self.assertEqual(p.set_action_item(T, done["_id"], aid, {"status": "maybe"})[0], 500)
        st, m = p.cancel_meeting(T, done["_id"], {"reason": "x"})
        self.assertEqual((st, m["status"], m["cancelledReason"], m["cancelledBy"]), (200, "cancelled", "x", T["name"]))  # a COMPLETED meeting cancelled (PS:211-221)
        other = next(m for m in p._state["ptm"].values() if m["teacherId"] == s.OTHER_STAFF)
        self.assertEqual(p.cancel_meeting(T, other["_id"], {"reason": "x"})[0], 200)

    def test_error_modes(self):
        req = next(m for m in mine(T) if m["status"] == "requested")
        self.assertEqual(p.confirm_meeting(T, req["_id"], mode="notrequested"), (404, "Meeting not found or not in a requested state"))
        self.assertEqual(p._state["ptm"][req["_id"]]["status"], "confirmed")  # flipped, as if confirmed elsewhere
        req = next(m for m in mine(T) if m["status"] == "requested")
        self.assertEqual(p.get_meeting(T, req["_id"], mode="notfound"), (404, "Meeting not found"))
        self.assertEqual(p.reschedule_meeting(T, req["_id"], {"scheduledDate": "2026-12-05"}, mode="notmine")[0], 403)
        self.assertEqual(p.record_outcome(T, req["_id"], {"parentAttended": True}, mode="cancelled")[0], 400)
        self.assertEqual(p._state["ptm"][req["_id"]]["status"], "cancelled")


class Fixtures(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def test_teacher_id_matches_original_or_substitute_sorted_date_desc_period_asc(self):
        st, rows = p.list_fixtures(T, {"teacherId": [T["staffId"]]})
        self.assertEqual(st, 200)
        self.assertTrue(all(T["staffId"] in (r["originalTeacherId"], r["substituteTeacherId"]) for r in rows))
        self.assertEqual({"original", "substitute"}, {("original" if r["originalTeacherId"] == T["staffId"] else "substitute") for r in rows})
        keys = [(r["date"], -r["periodNo"]) for r in rows]
        self.assertEqual(keys, sorted(keys, reverse=True))  # date DESC, periodNo ASC (SS:244)
        self.assertEqual({r["status"] for r in p.list_fixtures(T, {"teacherId": [T["staffId"]], "status": ["open"]})[1]}, {"open"})

    def test_complete_only_from_assigned_and_no_ownership_check(self):
        mine_ = next(r for r in p.list_fixtures(T, {"teacherId": [T["staffId"]]})[1] if r["substituteTeacherId"] == T["staffId"] and r["status"] == "assigned")
        self.assertEqual(p.complete_fixture(T, mine_["_id"])[1]["status"], "completed")
        self.assertEqual(p.complete_fixture(T, mine_["_id"]), (404, "Fixture not found or not in an assigned state"))
        theirs = next(x for x in p._state["fx"].values() if x["substituteTeacherId"] not in (T["staffId"], None) and x["status"] == "assigned")
        self.assertEqual(p.complete_fixture(T, theirs["_id"])[0], 200)  # not the caller's fixture: the server completes it anyway (UI-only gating)
        self.assertEqual(p.complete_fixture(T, "bad")[0], 500)
        open_ = next(x for x in p._state["fx"].values() if x["status"] == "open")
        self.assertEqual(p.complete_fixture(T, open_["_id"])[0], 404)


class Leave(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def test_balance_shape_and_no_policy(self):
        st, b = p.leave_balance(T)
        self.assertEqual(st, 200)
        self.assertEqual(b["annual"], {"entitled": 21, "used": 4, "remaining": 17})
        self.assertTrue(b["hasPolicy"])
        self.assertEqual(set(b) - {"staffId", "staffName", "employeeId", "department", "hasPolicy"}, {"annual", "sick", "casual", "maternity", "paternity", "hajj"})
        st, b = p.leave_balance(CT)
        self.assertFalse(b["hasPolicy"])
        self.assertEqual(b["annual"], {"entitled": 0, "used": 0, "remaining": 0})
        self.assertEqual(p.leave_balance(T, mode="nostaff")[0], 404)

    def test_history_is_mine_newest_first_and_carries_the_populated_approver_email(self):
        st, rows = p.leave_history(T)
        self.assertEqual((st, len(rows)), (200, 4))
        self.assertTrue(all(r["staffId"] == T["staffId"] for r in rows))
        created = [r["createdAt"] for r in rows]
        self.assertEqual(created, sorted(created, reverse=True))
        self.assertIn("email", rows[-1]["approvedBy"])  # HS:684 populates 'profile email': the app must never read it
        self.assertEqual({r["status"] for r in rows}, {"approved", "rejected", "pending"})

    def test_apply_counts_calendar_days_ignores_identity_fields_and_has_no_range_check(self):
        st, l = p.apply_leave(T, {"leaveType": "sick", "fromDate": "2026-11-02", "toDate": "2026-11-04", "reason": "Fever and rest", "isHalfDay": False, "staffId": "someone-else", "status": "approved"})
        self.assertEqual((st, l["status"], l["totalDays"], l["staffId"]), (201, "pending", 3, T["staffId"]))  # LS:44-52, LD:46-48
        self.assertEqual(l["fromDate"], "2026-11-02T00:00:00.000Z")
        self.assertTrue(l["leaveNo"].startswith("LV-"))
        st, l = p.apply_leave(T, {"leaveType": "casual", "fromDate": "2026-11-10", "toDate": "2026-11-05", "reason": "reversed range"})
        self.assertEqual((st, l["totalDays"]), (201, -4))  # the server never checks to >= from: the UI must
        self.assertEqual(p.leave_history(T)[1][0]["_id"], l["_id"])
        self.assertEqual(p.apply_leave(T, {"leaveType": "bogus", "fromDate": "2026-11-02", "toDate": "2026-11-04", "reason": "x"})[0], 400)
        self.assertEqual(p.apply_leave(T, {"leaveType": "sick", "fromDate": "2026-11-02", "toDate": "2026-11-04"})[0], 400)
        self.assertEqual(p.apply_leave(T, {}, mode="invalid")[0], 400)
        st, l = p.apply_leave(T, {"leaveType": "annual", "fromDate": "2026-11-02", "toDate": "2026-11-02", "reason": "Half day dentist", "isHalfDay": True, "halfDaySession": "morning"})
        self.assertEqual((l["isHalfDay"], l["halfDaySession"], l["totalDays"]), (True, "morning", 1))  # a half day still counts 1 (LD:46-48; UNVERIFIED policy)

    def test_decide_dev_control(self):
        pend = next(r for r in p.leave_history(T)[1] if r["status"] == "pending")
        st, l = p.decide_leave(pend["_id"], "approved", "ok")
        self.assertEqual((l["status"], l["approverNote"]), ("approved", "ok"))


class Http(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv = ThreadingHTTPServer(("127.0.0.1", 0), s.Handler)
        cls.port = cls.srv.server_address[1]
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        cls.srv.server_close()

    def setUp(self):
        self.call("POST", "/__stub/reset-state")

    def call(self, method, path, body=None, token="stub.teacher.dummy"):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=15)
        h = {"Authorization": f"Bearer {token}"}
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
        b = "/api/v1/teaching/ptm"
        sid = T["staffId"]
        st, rows = self.call("GET", f"{b}?teacherId={sid}")
        self.assertEqual((st, len(rows)), (200, 8))
        st, up = self.call("GET", f"{b}/upcoming/mine?teacherId={sid}")
        self.assertEqual(st, 200)
        mid = rows[0]["_id"]
        self.assertEqual(self.call("GET", f"{b}/{mid}")[0], 200)
        self.assertEqual(self.call("GET", f"{b}/student/{rows[0]['studentId']}/history")[0], 200)
        st, err = self.call("GET", f"{b}/zzz")
        self.assertEqual((st, set(err)), (400, {"statusCode", "message", "timestamp", "path"}))  # FLT:43-48
        st5 = next(x for x in s.STUDENTS if x["currentGrade"] == "Grade 5" and x["currentSection"] == "A" and x["status"] == "active")
        st, m = self.call("POST", b, {"studentId": st5["_id"], "teacherId": sid, "scheduledDate": "2026-12-01", "startTime": "10:00", "endTime": "10:30", "academicYear": st5["currentAcademicYear"]})
        self.assertEqual((st, m["status"]), (201, "requested"))  # POST -> 201
        st, m = self.call("PATCH", f"{b}/{m['_id']}/confirm")
        self.assertEqual((st, m["status"]), (200, "confirmed"))  # PATCH -> 200
        st, err = self.call("PATCH", f"{b}/{m['_id']}/confirm")
        self.assertEqual((st, err["message"]), (404, "Meeting not found or not in a requested state"))
        self.assertEqual(self.call("PATCH", f"{b}/{m['_id']}/cancel", {"reason": "r"})[1]["status"], "cancelled")
        st, fx = self.call("GET", f"/api/v1/teaching/fixtures?teacherId={sid}")
        self.assertEqual((st, len(fx)), (200, 6))
        fid = next(f for f in fx if f["status"] == "assigned" and f["substituteTeacherId"] == sid)["_id"]
        self.assertEqual(self.call("PATCH", f"/api/v1/teaching/fixtures/{fid}/complete")[1]["status"], "completed")
        st, bal = self.call("GET", "/api/v1/hr/leave/self/balance")
        self.assertEqual((st, bal["hasPolicy"]), (200, True))
        self.assertEqual(len(self.call("GET", "/api/v1/hr/leave/self/history")[1]), 4)
        st, l = self.call("POST", "/api/v1/hr/leave/self", {"leaveType": "casual", "fromDate": "2026-11-02", "toDate": "2026-11-03", "reason": "Family matter at home"})
        self.assertEqual((st, l["totalDays"]), (201, 2))
        self.assertEqual(self.call("GET", f"{b}?teacherId={sid}", token="stub.expired.dummy")[0], 401)

    def test_modes_and_dev_controls(self):
        b = "/api/v1/teaching/ptm"
        sid = T["staffId"]
        for feat, path in (("ptmlist", f"{b}?teacherId={sid}"), ("fixtures", f"/api/v1/teaching/fixtures?teacherId={sid}"), ("leavebalance", "/api/v1/hr/leave/self/balance"), ("leavehistory", "/api/v1/hr/leave/self/history")):
            self.call("POST", f"/__stub/mode?feature={feat}&value=403")
            self.assertEqual(self.call("GET", path)[0], 403, feat)
            self.call("POST", f"/__stub/mode?feature={feat}&value=404")
            st, err = self.call("GET", path)
            self.assertEqual(st, 404)
            self.assertTrue(err["message"].startswith("Cannot "), feat)  # 'not deployed'
            self.call("POST", f"/__stub/mode?feature={feat}&value=empty")
            if feat != "leavebalance":
                self.assertEqual(self.call("GET", path)[1], [])
            self.call("POST", f"/__stub/mode?feature={feat}&value=ok")
        self.call("POST", "/__stub/mode?feature=ptmcreate&value=notmine")
        st, err = self.call("POST", b, {"studentId": "x"})
        self.assertEqual((st, err["message"]), (403, "You can only create meetings for yourself"))
        self.call("POST", "/__stub/mode?feature=fxcomplete&value=notassigned")
        fx = self.call("GET", f"/api/v1/teaching/fixtures?teacherId={sid}")[1]
        st, err = self.call("PATCH", f"/api/v1/teaching/fixtures/{fx[0]['_id']}/complete")
        self.assertEqual((st, err["message"]), (404, "Fixture not found or not in an assigned state"))
        pend = next(x for x in self.call("GET", "/api/v1/hr/leave/self/history")[1] if x["status"] == "pending")
        self.call("POST", f"/__stub/leave-decide?id={pend['_id']}&status=rejected&note=Exam%20week")
        self.assertEqual(next(x for x in self.call("GET", "/api/v1/hr/leave/self/history")[1] if x["_id"] == pend["_id"])["status"], "rejected")
        self.assertIn("phase7b", self.call("GET", "/__stub/state")[1])
        # the Home agenda reads the same data set
        up = self.call("GET", f"{b}/upcoming/mine?teacherId={sid}")[1]
        self.assertTrue(all(m["status"] in ("requested", "confirmed") for m in up))


if __name__ == "__main__":
    unittest.main()
