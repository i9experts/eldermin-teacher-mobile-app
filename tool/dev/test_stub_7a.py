#!/usr/bin/env python3
"""Tests for the Phase 7a stub (messages with guardians, notifications inbox, student-leave review): the contract the Dart repositories
rely on, with the backend behaviours copied from staff-portal.service.ts (citations in stub_7a.py).
Run: python3 tool/dev/test_stub_7a.py"""
import http.client
import json
import os
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_7a as p

T = s.ACCOUNTS["teacher"]
CT = s.ACCOUNTS["classteacher"]


class Threads(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def test_list_filters_status_only_for_open_or_closed_and_counts_returned_rows(self):
        st, all_ = p.list_threads(T, {})
        self.assertEqual((st, len(all_["items"]), all_["unreadCount"]), (200, 4, 3))  # closed unread row IS in the server count
        st, op = p.list_threads(T, {"status": ["open"]})
        self.assertEqual([t["status"] for t in op["items"]], ["open"] * 3)
        self.assertEqual(op["unreadCount"], 2)
        self.assertEqual(len(p.list_threads(T, {"status": ["bogus"]})[1]["items"]), 4)  # SPS:220: any other value = no filter
        dates = [t["lastMessageAt"] for t in all_["items"]]
        self.assertEqual(dates, sorted(dates, reverse=True))

    def test_threads_belong_to_the_staff_member(self):
        mine = {t["_id"] for t in p.list_threads(T, {})[1]["items"]}
        theirs = {t["_id"] for t in p.list_threads(CT, {})[1]["items"]}
        self.assertFalse(mine & theirs)
        self.assertEqual(p.thread_messages(T, next(iter(theirs)))[0], 404)  # someone else's thread is 'Thread not found' (SPS:229)
        self.assertEqual(p.thread_messages(T, "nope")[0], 404)

    def test_messages_oldest_first_and_thread_included(self):
        tid = p.list_threads(T, {})[1]["items"][0]["_id"]
        st, r = p.thread_messages(T, tid)
        self.assertEqual(st, 200)
        dates = [m["createdAt"] for m in r["messages"]]
        self.assertEqual(dates, sorted(dates))
        self.assertEqual(r["thread"]["_id"], tid)
        self.assertTrue(all(m["senderRole"] in ("guardian", "staff") for m in r["messages"]))
        self.assertNotIn("phone", json.dumps(r).lower())

    def test_messages_newest_500_and_after_cursor(self):
        tid = p.list_threads(T, {})[1]["items"][0]["_id"]
        full = p.thread_messages(T, tid)[1]["messages"]
        self.assertGreaterEqual(len(full), 2)
        # force a long thread: the NEWEST 500 come back, oldest -> newest (SPS:249-250)
        base = p._now() - p.datetime.timedelta(days=2)
        p._state["messages"][tid] = [dict(full[0], _id=p._oid(0xC000 + i), createdAt=p._iso(base + p.datetime.timedelta(seconds=i))) for i in range(520)]
        got = p.thread_messages(T, tid)[1]["messages"]
        self.assertEqual(len(got), 500)
        self.assertEqual(got[-1]["_id"], p._oid(0xC000 + 519))
        self.assertEqual(got[0]["_id"], p._oid(0xC000 + 20))
        # after: strictly newer, oldest first (SPS:244-247)
        cut = p._iso(base + p.datetime.timedelta(seconds=517))
        self.assertEqual([m["_id"] for m in p.thread_messages(T, tid, after=cut)[1]["messages"]], [p._oid(0xC000 + 518), p._oid(0xC000 + 519)])
        # an unparseable after is ignored (SPS:244)
        self.assertEqual(len(p.thread_messages(T, tid, after="not-a-date")[1]["messages"]), 500)
        # the older-deployment mode ignores it
        self.assertEqual(len(p.thread_messages(T, tid, mode="ignoreafter", after=cut)[1]["messages"]), 500)

    def test_unread_count_counts_all_matching_threads(self):
        r = p.list_threads(T, {})[1]
        self.assertEqual(r["unreadCount"], sum(1 for t in r["items"] if t["staffHasUnread"]))

    def test_get_messages_does_not_clear_unread_but_read_does(self):
        t = next(x for x in p.list_threads(T, {})[1]["items"] if x["staffHasUnread"] and x["status"] == "open")
        p.thread_messages(T, t["_id"])
        self.assertTrue(p._state["threads"][t["_id"]]["staffHasUnread"])  # SPS:233-237 never clears it
        self.assertEqual(p.mark_thread_read(T, t["_id"]), (200, {"ok": True}))
        self.assertFalse(p._state["threads"][t["_id"]]["staffHasUnread"])

    def test_send_validates_trims_updates_thread_and_closed_is_409(self):
        tid = p.list_threads(T, {"status": ["open"]})[1]["items"][0]["_id"]
        self.assertEqual(p.send_message(T, tid, {})[1], "body must be a string")
        self.assertEqual(p.send_message(T, tid, {"body": ""})[1], "body must be longer than or equal to 1 characters")
        self.assertEqual(p.send_message(T, tid, {"body": "x" * 4001})[1], "body must be shorter than or equal to 4000 characters")
        self.assertEqual(p.send_message(T, tid, {"body": "   "}), (400, "Message body is required."))  # passes the DTO, fails SPS:244
        st, m = p.send_message(T, tid, {"body": "  Hello there  "})
        self.assertEqual((st, m["body"], m["senderRole"], m["senderName"]), (201, "Hello there", "staff", "Tess Teacher"))
        th = p._state["threads"][tid]
        self.assertEqual((th["lastMessagePreview"], th["guardianHasUnread"], th["staffHasUnread"]), ("Hello there", True, False))
        self.assertEqual(p.thread_messages(T, tid)[1]["messages"][-1]["_id"], m["_id"])
        long_ = "y" * 200
        p.send_message(T, tid, {"body": long_})
        self.assertEqual(len(th["lastMessagePreview"]), 140)  # SPS:247
        self.assertEqual(p.close_thread(T, tid)[1]["status"], "closed")
        self.assertEqual(p.send_message(T, tid, {"body": "again"}), (409, "This conversation is closed."))

    def test_create_thread_checks_class_guardian_and_validation(self):
        st5a = next(x for x in s.STUDENTS if x["currentGrade"] == "Grade 5" and x["currentSection"] == "A" and x["currentRollNumber"] == "2")
        g = p.list_guardians(T, st5a["_id"])[1]
        self.assertEqual({k for k in g[0]}, {"userId", "name"})  # names only
        body = {"studentId": st5a["_id"], "guardianUserId": g[0]["userId"], "subject": "  Homework  ", "firstMessage": " Hi "}
        st, t = p.create_thread(T, body)
        self.assertEqual((st, t["subject"], t["status"], t["guardianHasUnread"], t["staffHasUnread"], t["guardianName"]), (201, "Homework", "open", True, False, g[0]["name"]))
        self.assertEqual(p.thread_messages(T, t["_id"])[1]["messages"][0]["body"], "Hi")
        self.assertEqual(p.create_thread(T, dict(body, guardianUserId="64e" + "0" * 21)), (403, "That person is not a registered guardian of this student."))
        other = next(x for x in s.STUDENTS if x["currentGrade"] == "Grade 5" and x["currentSection"] == "B")
        self.assertEqual(p.create_thread(T, dict(body, studentId=other["_id"])), (403, "You do not teach this student."))
        self.assertEqual(p.create_thread(T, dict(body, subject=""))[1], "subject must be longer than or equal to 1 characters")
        self.assertEqual(p.create_thread(T, dict(body, subject="s" * 201))[1], "subject must be shorter than or equal to 200 characters")
        self.assertEqual(p.create_thread(T, dict(body, studentId="x"))[1], "studentId must be a mongodb id")
        self.assertEqual(p.create_thread(T, dict(body, firstMessage="m" * 4001))[0], 400)

    def test_guardians_scope_and_empty(self):
        other = next(x for x in s.STUDENTS if x["currentGrade"] == "Grade 5" and x["currentSection"] == "B")
        self.assertEqual(p.list_guardians(T, other["_id"]), (403, "You do not teach this student."))
        self.assertEqual(p.list_guardians(T, "zz")[0], 404)
        noguard = next(x for x in s.STUDENTS if x["currentGrade"] == "Grade 5" and x["currentSection"] == "A" and x["currentRollNumber"] == "6")
        self.assertEqual(p.list_guardians(T, noguard["_id"]), (200, []))

    def test_guardian_reply_marks_unread(self):
        tid = next(x for x in p.list_threads(T, {})[1]["items"] if not x["staffHasUnread"] and x["status"] == "open")["_id"]
        self.assertEqual(p.guardian_reply(tid, "Hello back")[0], 200)
        self.assertTrue(p._state["threads"][tid]["staffHasUnread"])
        self.assertEqual(p.thread_messages(T, tid)[1]["messages"][-1]["senderRole"], "guardian")


class Notifications(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def test_first_page_unread_count_and_cursor(self):
        st, r = p.list_notifications(T, {"limit": ["10"]})
        self.assertEqual((st, len(r["items"]), r["unreadCount"]), (200, 10, 3))
        self.assertEqual(r["nextCursor"], r["items"][-1]["createdAt"])
        dates = [n["createdAt"] for n in r["items"]]
        self.assertEqual(dates, sorted(dates, reverse=True))

    def test_paging_with_before_covers_everything_exactly_once(self):
        seen, cursor = [], None
        for _ in range(20):
            q = {"limit": ["12"]}
            if cursor:
                q["before"] = [cursor]
            st, r = p.list_notifications(T, q)
            seen += [n["_id"] for n in r["items"]]
            cursor = r["nextCursor"]
            if not cursor:
                break
        self.assertEqual(len(seen), len(set(seen)))
        self.assertEqual(len(seen), len(p._state["notifs"][T["id"]]))

    def test_limit_clamp_and_unread_filter_and_bad_before(self):
        self.assertEqual(len(p.list_notifications(T, {"limit": ["0"]})[1]["items"]), 30)  # '0' is falsy in JS: default 30 (SPS:174)
        self.assertEqual(len(p.list_notifications(T, {"limit": ["-5"]})[1]["items"]), 1)
        self.assertEqual(len(p.list_notifications(T, {"limit": ["500"]})[1]["items"]), min(100, len(p._state["notifs"][T["id"]])))
        self.assertEqual(len(p.list_notifications(T, {"unread": ["true"]})[1]["items"]), 3)
        self.assertEqual(len(p.list_notifications(T, {"unread": ["yes"]})[1]["items"]), 30)  # only 'true' filters
        self.assertEqual(len(p.list_notifications(T, {"before": ["garbage"]})[1]["items"]), 30)  # unparseable date ignored (SPS:178-179)

    def test_read_one_all_and_counts(self):
        first = p.list_notifications(T, {"unread": ["true"]})[1]["items"][0]
        self.assertTrue(p.read_notification(T, first["_id"])[1]["isRead"])
        self.assertEqual(p.unread_count(T)[1], {"unreadCount": 2})
        self.assertEqual(p.read_notification(T, "64e" + "f" * 21), (404, "Notification not found"))
        self.assertEqual(p.read_all(T), (200, {"updated": 2}))
        self.assertEqual(p.read_all(T), (200, {"updated": 0}))
        self.assertEqual(p.unread_count(T)[1], {"unreadCount": 0})

    def test_notifications_are_per_user_and_cover_types_and_emitter_semantics(self):
        mine = p.list_notifications(T, {"limit": ["100"]})[1]["items"]
        theirs = p.list_notifications(CT, {"limit": ["100"]})[1]["items"]
        self.assertFalse({n["_id"] for n in mine} & {n["_id"] for n in theirs})
        types = {n["type"] for n in mine}
        self.assertTrue({"message", "ptm", "substitution", "lesson_plan", "homework", "leave_status", "other"} <= types)
        self.assertIn("zzz_future", types)  # unknown type: the app must not crash
        msg = next(n for n in theirs if n["type"] == "message")
        self.assertIn(msg["relatedEntityId"], p._state["threads"])  # message -> THREAD id (SPS:254-255)
        new_leave = next(n for n in theirs if n["type"] == "leave_status")
        self.assertEqual(new_leave["title"], "New leave request")  # PPS:825: student leave id to the class teacher
        self.assertIn(new_leave["relatedEntityId"], p._state["leaves"])
        own = next(n for n in mine if n["type"] == "leave_status")
        self.assertNotEqual(own["title"], "New leave request")  # HR:1335: the teacher's own staff leave
        self.assertTrue(any("relatedEntityId" not in n for n in mine))  # optional field absent


class Leaves(unittest.TestCase):
    def setUp(self):
        p.reset()
        p.seed()

    def test_only_class_teachers_and_filters(self):
        self.assertEqual(p.list_leaves(T, {}), (403, "Only class teachers can review student leave requests."))
        st, r = p.list_leaves(CT, {"status": ["pending"]})
        self.assertEqual((st, len(r["items"])), (200, 3))
        self.assertEqual(len(p.list_leaves(CT, {"status": ["approved"]})[1]["items"]), 2)
        self.assertEqual(len(p.list_leaves(CT, {"status": ["rejected"]})[1]["items"]), 1)
        self.assertEqual(len(p.list_leaves(CT, {})[1]["items"]), 6)
        self.assertEqual(len(p.list_leaves(CT, {"status": ["whatever"]})[1]["items"]), 6)
        self.assertEqual(len(p.list_leaves(CT, {"limit": ["2"]})[1]["items"]), 2)
        row = p.list_leaves(CT, {})[1]["items"][0]
        for k in ("studentId", "studentName", "fromDate", "toDate", "reason", "leaveType", "requestedByName", "status"):
            self.assertIn(k, row)
        self.assertNotIn("phone", json.dumps(row).lower())

    def test_review_approve_reject_remarks_and_conflict(self):
        pend = p.list_leaves(CT, {"status": ["pending"]})[1]["items"]
        a, b = pend[0]["_id"], pend[1]["_id"]
        self.assertEqual(p.review_leave(CT, a, {"status": "maybe"})[1], "status must be one of the following values: approved, rejected")
        self.assertEqual(p.review_leave(CT, a, {"status": "approved", "remarks": "r" * 1001})[1], "remarks must be shorter than or equal to 1000 characters")
        st, l = p.review_leave(CT, a, {"status": "approved", "remarks": "  ok  "})
        self.assertEqual((st, l["status"], l["approverName"], l["approverNote"]), (200, "approved", "Clara Classteacher", "ok"))
        self.assertIn("approvedAt", l)
        self.assertEqual(p.review_leave(CT, a, {"status": "rejected"}), (409, "This request was already approved."))
        st, l2 = p.review_leave(CT, b, {"status": "rejected"})
        self.assertNotIn("approverNote", l2)
        self.assertEqual(p.review_leave(CT, "64e" + "0" * 21, {"status": "approved"}), (404, "Leave request not found"))
        self.assertEqual(p.review_leave(T, a, {"status": "approved"})[0], 403)
        self.assertEqual(len(p.list_leaves(CT, {"status": ["pending"]})[1]["items"]), 1)

    def test_modes_decided_and_notmyclass(self):
        pend = p.list_leaves(CT, {"status": ["pending"]})[1]["items"][0]["_id"]
        self.assertEqual(p.review_leave(CT, pend, {"status": "approved"}, mode="notmyclass"), (403, "This student is not in your class."))
        self.assertEqual(p.review_leave(CT, pend, {"status": "rejected"}, mode="decided"), (409, "This request was already approved."))
        self.assertEqual(p._state["leaves"][pend]["approverName"], "Clara Classteacher")


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

    def test_routes_status_codes_and_error_shape(self):
        b = "/api/v1/staff-portal"
        st, r = self.call("GET", f"{b}/threads?status=open")
        self.assertEqual((st, len(r["items"])), (200, 3))
        tid = r["items"][0]["_id"]
        self.assertEqual(self.call("GET", f"{b}/threads/{tid}/messages")[0], 200)
        st, m = self.call("POST", f"{b}/threads/{tid}/messages", {"body": "hi"})
        self.assertEqual((st, m["body"]), (201, "hi"))  # 201 (SPC:60)
        self.assertEqual(self.call("POST", f"{b}/threads/{tid}/read")[0], 200)  # 200 (SPC:66)
        self.assertEqual(self.call("PATCH", f"{b}/threads/{tid}/close")[1]["status"], "closed")
        st, err = self.call("POST", f"{b}/threads/{tid}/messages", {"body": "again"})
        self.assertEqual(st, 409)
        self.assertEqual(set(err), {"statusCode", "message", "timestamp", "path"})  # FLT:43-48
        self.assertEqual(self.call("GET", f"{b}/notifications?limit=5")[1]["unreadCount"], 3)
        self.assertEqual(self.call("GET", f"{b}/notifications/unread-count")[1], {"unreadCount": 3})
        self.assertEqual(self.call("POST", f"{b}/notifications/read-all")[1], {"updated": 3})  # 200 (SPC:41)
        self.assertEqual(self.call("GET", f"{b}/student-leaves")[0], 403)
        st, lv = self.call("GET", f"{b}/student-leaves?status=pending", token="stub.classteacher.dummy")
        self.assertEqual((st, len(lv["items"])), (200, 3))
        self.assertEqual(self.call("PATCH", f"{b}/student-leaves/{lv['items'][0]['_id']}", {"status": "approved"}, token="stub.classteacher.dummy")[0], 200)
        self.assertEqual(self.call("GET", f"{b}/threads", token="stub.expired.dummy")[0], 401)
        self.assertEqual(self.call("GET", f"{b}/threads", token="stub.principal.dummy")[0], 403)

    def test_modes_and_dev_controls(self):
        b = "/api/v1/staff-portal"
        self.call("POST", "/__stub/mode?feature=threads&value=403")
        self.assertEqual(self.call("GET", f"{b}/threads")[0], 403)
        self.call("POST", "/__stub/mode?feature=threads&value=404")
        st, err = self.call("GET", f"{b}/threads")
        self.assertEqual(st, 404)
        self.assertTrue(err["message"].startswith("Cannot "))  # how the app tells 'not deployed' from 'thread not found'
        self.call("POST", "/__stub/mode?feature=threads&value=empty")
        self.assertEqual(self.call("GET", f"{b}/threads")[1], {"items": [], "unreadCount": 0})
        self.call("POST", "/__stub/mode?feature=threads&value=ok")
        tid = self.call("GET", f"{b}/threads?status=open")[1]["items"][0]["_id"]
        self.call("POST", "/__stub/mode?feature=threadsend&value=closed")
        st, err = self.call("POST", f"{b}/threads/{tid}/messages", {"body": "x"})
        self.assertEqual((st, err["message"]), (409, "This conversation is closed."))
        self.call("POST", "/__stub/mode?feature=notifs&value=empty")
        self.assertEqual(self.call("GET", f"{b}/notifications")[1], {"items": [], "nextCursor": None, "unreadCount": 0})
        self.call("POST", "/__stub/mode?feature=guardians&value=notteach")
        st5 = next(x for x in s.STUDENTS if x["currentGrade"] == "Grade 5" and x["currentSection"] == "A")
        st, err = self.call("GET", f"{b}/students/{st5['_id']}/guardians")
        self.assertEqual((st, err["message"]), (403, "You do not teach this student."))
        self.call("POST", "/__stub/mode?feature=threads&value=ok")
        self.call("POST", "/__stub/guardian-reply?thread=" + tid + "&body=Hello")
        self.assertTrue(self.call("GET", f"{b}/threads/{tid}/messages")[1]["thread"]["staffHasUnread"])
        st, r = self.call("POST", "/__stub/notify?account=teacher&title=Hi&type=message&entity=" + tid)
        self.assertEqual(self.call("GET", f"{b}/notifications/unread-count")[1], {"unreadCount": 4})
        self.assertIn("phase7a", self.call("GET", "/__stub/state")[1])


if __name__ == "__main__":
    unittest.main()
