#!/usr/bin/env python3
"""Tests for the Phase 7c stub (calendar, circulars, events, safeguarding, avatar, knowledge base, delete request): the contract the Dart repositories rely on,
with backend behaviours copied from the files cited in stub_7c.py. Run: python3 tool/dev/test_stub_7c.py"""
import http.client
import json
import os
import re
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_7c as p

T = s.ACCOUNTS["teacher"]


class Calendar(unittest.TestCase):
    def test_window_overlap_filter_and_sort(self):
        today = p._today()
        frm = today.replace(day=1).isoformat() + "T00:00:00.000Z"
        to = (today.replace(day=1) + p.datetime.timedelta(days=27)).isoformat() + "T23:59:59.999Z"
        st, rows = p.list_calendar({"from": [frm], "to": [to]})
        self.assertEqual(st, 200)
        starts = [p._parse(r["startDate"]) for r in rows]
        self.assertEqual(starts, sorted(starts))  # SCS:160
        self.assertTrue(all(p._parse(r["startDate"]) <= p._parse(to) and p._parse(r["endDate"]) >= p._parse(frm) for r in rows))  # SCS:78

    def test_leak_is_present_on_purpose_and_has_every_source(self):
        today = p._today()
        st, rows = p.list_calendar({"from": [today.replace(day=1).isoformat()], "to": [(today + p.datetime.timedelta(days=45)).isoformat()]})
        fee = [r for r in rows if r["type"] == "fee_due"]
        self.assertTrue(fee)
        self.assertTrue(all(r["source"] == "finance" and r["description"].startswith("Total outstanding:") and r["_id"].startswith("fee-due-") for r in fee))  # SCS:91-103
        self.assertEqual({r["source"] for r in rows} & {"manual", "assessments", "academics", "finance"}, {"manual", "assessments", "academics", "finance"})
        # SCS:156: every manual row has a colour (its own or the type's) and a source
        for r in rows:
            self.assertTrue(re.fullmatch(r"#[0-9A-Fa-f]{6}", r["color"]))

    def test_all_day_rows_are_utc_midnight_and_one_is_timed(self):
        st, rows = p.list_calendar({"from": ["2000-01-01"], "to": ["2100-01-01"]})
        manual = [r for r in rows if r["source"] == "manual"]
        timed = [r for r in manual if r["allDay"] is False]
        self.assertEqual(len(timed), 1)
        for r in manual:
            if r["allDay"]:
                self.assertTrue(r["startDate"].endswith("T00:00:00.000Z"))
        self.assertGreater(len([r for r in manual if r["startDate"] != r["endDate"]]), 1)  # multi-day entries exist

    def test_badshape_mode(self):
        self.assertIsInstance(p.list_calendar({}, mode="badshape")[1], dict)


class Circulars(unittest.TestCase):
    def test_list_returns_every_status_and_audience_like_the_real_endpoint(self):
        st, rows = p.list_circulars(T, {})
        self.assertEqual(st, 200)
        self.assertEqual({r["status"] for r in rows}, {"published", "draft", "scheduled"})  # SCS:190-195 filters only schoolSlug
        self.assertTrue(any(r["audience"]["roles"] == ["parent"] for r in rows))
        created = [r["createdAt"] for r in rows]
        self.assertEqual(created, sorted(created, reverse=True))  # SCS:194

    def test_status_filter_and_limit(self):
        self.assertEqual({r["status"] for r in p.list_circulars(T, {"status": ["published"]})[1]}, {"published"})
        self.assertEqual(len(p.list_circulars(T, {"limit": ["2"]})[1]), 2)

    def test_acknowledge_is_idempotent_and_404s(self):
        p.reset()
        cid = p.list_circulars(T, {})[1][0]["_id"]
        st1, a1 = p.acknowledge(T, cid)
        st2, a2 = p.acknowledge(T, cid)
        self.assertEqual((st1, st2), (201, 201))
        self.assertEqual(a1["circularId"], cid)
        self.assertEqual(a1["userId"], T["id"])
        self.assertEqual(len(p._state["acked"][T["id"]]), 1)
        self.assertEqual(p.acknowledge(T, "64c000000000000000000fff"), (404, "Circular not found"))  # SCS:285

    def test_individual_circular_names_my_staff_id(self):
        rows = p.list_circulars(T, {})[1]
        mine = [r for r in rows if r["audience"]["scope"] == "individual" and T["staffId"] in r["audience"]["individualStaffIds"]]
        self.assertEqual(len(mine), 1)


class Events(unittest.TestCase):
    def test_list_includes_drafts_private_and_unlisted(self):
        rows = p.list_events()[1]
        self.assertEqual({r["status"] for r in rows}, {"published", "draft", "completed", "cancelled"})
        self.assertEqual({r["visibility"] for r in rows}, {"public", "internal", "private", "unlisted"})

    def test_detail_leaks_ticket_types_and_promo_codes_on_purpose(self):
        eid = p.list_events()[1][0]["_id"]
        st, e = p.get_event(eid)
        self.assertEqual(st, 200)
        self.assertTrue(e["ticketTypes"] and e["promoCodes"] and "price" in e["ticketTypes"][0])  # ES:157-161
        self.assertEqual(p.get_event("nope"), (404, "Event not found"))  # ES:156


class Safeguarding(unittest.TestCase):
    def setUp(self):
        p.reset()

    def test_required_fields_and_enums(self):
        self.assertEqual(p.create_safeguarding(T, {})[0], 400)
        st, msg = p.create_safeguarding(T, {"title": "t", "description": "d", "type": "weird"})
        self.assertEqual(st, 400)
        self.assertIn("is not a valid enum value for path `type`", msg)

    def test_mass_assignment_is_simulated_and_keys_recorded(self):
        st, case = p.create_safeguarding(T, {"title": "t", "description": "d", "type": "bullying", "status": "closed", "assignedTo": "x", "reportedBy": "someone"})
        self.assertEqual(st, 201)
        self.assertEqual((case["status"], case["assignedTo"], case["reportedBy"]), ("open", "x", "someone"))  # `status` is overwritten only because the stub sets it; assignedTo / reportedBy are spread
        self.assertEqual(p._state["last_safeguarding"]["keys"], sorted(["title", "description", "type", "status", "assignedTo", "reportedBy"]))
        self.assertRegex(case["caseNumber"], r"^SC-\d{4}-\d{3}$")

    def test_created_case_carries_the_reference_the_app_may_show(self):
        st, case = p.create_safeguarding(T, {"title": "t", "description": "d", "type": "other", "reportedDate": "2026-10-01"})
        self.assertEqual(case["reportedDate"], "2026-10-01T00:00:00.000Z")
        self.assertEqual(case["severity"], "medium")  # schema default CSC:77


class Avatar(unittest.TestCase):
    def mp(self, field="avatar", name="me.png", data=b"\x89PNG-bytes"):
        b = "----t"
        body = (f"--{b}\r\nContent-Disposition: form-data; name=\"{field}\"; filename=\"{name}\"\r\nContent-Type: image/png\r\n\r\n").encode() + data + f"\r\n--{b}--\r\n".encode()
        return f"multipart/form-data; boundary={b}", body

    def setUp(self):
        p.reset()

    def test_field_name_and_url(self):
        ct, body = self.mp()
        st, r = p.upload_avatar(T, ct, body, "http://h:1")
        self.assertEqual(st, 201)
        self.assertTrue(r["avatarUrl"].startswith("http://h:1/__stub/avatar-"))
        self.assertEqual(p._state["last_avatar"]["fields"], ["avatar"])
        self.assertEqual(s.user_view(T)["avatarUrl"], r["avatarUrl"])  # persists for /auth/me and /staff-portal/me
        self.assertEqual(s.staff_me(T)["user"]["avatarUrl"], r["avatarUrl"])

    def test_wrong_field_is_no_file(self):
        ct, body = self.mp(field="file")
        self.assertEqual(p.upload_avatar(T, ct, body, "http://h")[0:2], (400, "No file provided"))

    def test_too_large(self):
        ct, body = self.mp(data=b"x" * (p.MAX_FILE + 10))
        self.assertEqual(p.upload_avatar(T, ct, body, "http://h"), (400, "File too large. Max 10MB allowed."))

    def test_png_is_valid(self):
        self.assertTrue(p.AVATAR_PNG.startswith(b"\x89PNG\r\n\x1a\n"))


class Kb(unittest.TestCase):
    def test_list_sorted_and_filtered(self):
        rows = p.kb_list({})[1]
        self.assertEqual([r["order"] for r in rows], sorted(r["order"] for r in rows))
        self.assertEqual({r["module"] for r in p.kb_list({"module": ["hr"]})[1]}, {"hr"})

    def test_search_matches_title_tagline_body_steps_and_blank_is_empty(self):
        self.assertEqual(p.kb_search({"q": ["  "]}), (200, []))
        self.assertTrue(p.kb_search({"q": ["DASHBOARD"]})[1])  # case-insensitive (KU)
        self.assertTrue(p.kb_search({"q": ["spreadsheet"]})[1])  # inside a step
        mods = [(r["module"], r["order"]) for r in p.kb_search({"q": ["the"]})[1]]
        self.assertEqual(mods, sorted(mods))

    def test_one_and_404(self):
        self.assertEqual(p.kb_one("hr", "employees")[0], 200)
        self.assertEqual(p.kb_one("hr", "zzz"), (404, "No KB article found for hr/zzz"))  # KS:55

    def test_adversarial_article_exists(self):
        body = p.kb_one("general", "adversarial")[1]["body"]
        self.assertIn("<script>", body)
        self.assertIn("javascript:", body)


class Delete(unittest.TestCase):
    def setUp(self):
        p.reset()

    def test_flow(self):
        self.assertEqual(p.delete_request(T, {"confirm": False}), (400, "Please confirm the request."))  # SPS:411
        self.assertEqual(p.delete_request(T, {})[0], 400)
        self.assertEqual(p.delete_request(T, {"confirm": True, "reason": "x" * 1001})[0], 400)  # DTO:31
        st, r = p.delete_request(T, {"confirm": True, "reason": "leaving"})
        self.assertEqual((st, r["status"]), (201, "pending"))
        self.assertIn("retained until they process it", r["message"])
        self.assertNotIn("alreadyRequested", r)
        st, again = p.delete_request(T, {"confirm": True})
        self.assertEqual((st, again["status"], again["alreadyRequested"], again["requestId"]), (201, "pending", True, r["requestId"]))
        self.assertNotIn("message", again)  # SPS:416

    def test_only_teacher_modelled(self):
        self.assertEqual(p.delete_request(s.ACCOUNTS["principal"], {"confirm": True})[0], 403)


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

    def call(self, method, path, body=None, token="stub.teacher.dummy", raw=None, ctype=None):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=15)
        h = {"Authorization": f"Bearer {token}"}
        data = raw
        if body is not None:
            data = json.dumps(body).encode()
            h["Content-Type"] = "application/json"
        if ctype:
            h["Content-Type"] = ctype
        c.request(method, path, body=data, headers=h)
        r = c.getresponse()
        out = r.read()
        c.close()
        try:
            return r.status, json.loads(out) if out else None
        except ValueError:
            return r.status, out

    def mode(self, feature, value):
        self.call("POST", f"/__stub/mode?feature={feature}&value={value}")

    def test_routes_and_error_shape(self):
        api = "/api/v1"
        self.assertEqual(self.call("GET", f"{api}/school-calendar/events")[0], 200)
        st, rows = self.call("GET", f"{api}/school-calendar/circulars?status=published")
        self.assertEqual((st, {r["status"] for r in rows}), (200, {"published"}))
        cid = rows[0]["_id"]
        self.assertEqual(self.call("POST", f"{api}/school-calendar/circulars/{cid}/acknowledge")[0], 201)
        st, evs = self.call("GET", f"{api}/events")
        self.assertEqual(st, 200)
        self.assertEqual(self.call("GET", f"{api}/events/{evs[0]['_id']}")[0], 200)
        st, e = self.call("GET", f"{api}/events/nope")
        self.assertEqual((st, e["statusCode"], e["message"]), (404, 404, "Event not found"))
        self.assertEqual(set(e), {"statusCode", "message", "timestamp", "path"})  # FLT
        self.assertEqual(self.call("GET", f"{api}/kb/articles")[0], 200)
        self.assertEqual(self.call("GET", f"{api}/kb/search?q=leave")[0], 200)
        self.assertEqual(self.call("GET", f"{api}/kb/articles/hr/employees")[0], 200)
        self.assertEqual(self.call("GET", f"{api}/kb/articles/hr/none")[0], 404)
        self.assertEqual(self.call("GET", f"{api}/events", token="bad")[0], 401)

    def test_safeguarding_and_modes(self):
        api = "/api/v1/compliance/safeguarding"
        st, r = self.call("POST", api, {"title": "t", "description": "d", "type": "bullying", "severity": "low", "reportedDate": "2026-10-01"})
        self.assertEqual(st, 201)
        state = self.call("GET", "/__stub/state")[1]["phase7c"]
        self.assertEqual(state["lastSafeguardingKeys"], ["description", "reportedDate", "severity", "title", "type"])
        self.mode("safeguarding", "403")
        st, e = self.call("POST", api, {"title": "t"})
        self.assertEqual((st, e["message"]), (403, "Forbidden resource"))
        self.mode("safeguarding", "500")
        self.assertEqual(self.call("POST", api, {"title": "t"})[0], 500)

    def test_avatar_http_503_and_upload(self):
        b = "----x"
        body = (f"--{b}\r\nContent-Disposition: form-data; name=\"avatar\"; filename=\"a.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n").encode() + b"JPEGDATA" + f"\r\n--{b}--\r\n".encode()
        ct = f"multipart/form-data; boundary={b}"
        st, r = self.call("POST", "/api/v1/auth/me/avatar", raw=body, ctype=ct)
        self.assertEqual(st, 201)
        url = r["avatarUrl"]
        path = "/" + url.split("/", 3)[3]
        st, png = self.call("GET", path, token="")
        self.assertEqual((st, png[:4]), (200, b"\x89PNG"))
        self.assertEqual(self.call("GET", "/api/v1/auth/me")[1]["avatarUrl"], url)
        self.mode("avatar", "503")
        st, e = self.call("POST", "/api/v1/auth/me/avatar", raw=body, ctype=ct)
        self.assertEqual((st, e["message"]), (503, "File uploads are not available on this server (storage is not configured)."))

    def test_delete_request_http(self):
        api = "/api/v1/staff-portal/account/delete-request"
        self.assertEqual(self.call("POST", api, {"confirm": False})[0], 400)
        st, r = self.call("POST", api, {"confirm": True})
        self.assertEqual((st, r["status"]), (201, "pending"))
        self.assertTrue(self.call("POST", api, {"confirm": True})[1]["alreadyRequested"])

    def test_modes_empty_404_and_badshape(self):
        for feature, path in (("calendar", "school-calendar/events"), ("circulars", "school-calendar/circulars"), ("events", "events"), ("kb", "kb/articles")):
            self.mode(feature, "empty")
            self.assertEqual(self.call("GET", f"/api/v1/{path}"), (200, []))
            self.mode(feature, "404")
            self.assertEqual(self.call("GET", f"/api/v1/{path}")[0], 404)
            self.mode(feature, "badshape")
            st, body = self.call("GET", f"/api/v1/{path}")
            self.assertEqual((st, type(body)), (200, dict))
            self.mode(feature, "ok")

    def test_reset_clears_avatar_and_deletion(self):
        self.call("POST", "/api/v1/staff-portal/account/delete-request", {"confirm": True})
        self.call("POST", "/__stub/reset-state")
        st, r = self.call("POST", "/api/v1/staff-portal/account/delete-request", {"confirm": True})
        self.assertNotIn("alreadyRequested", r)


if __name__ == "__main__":
    unittest.main()
