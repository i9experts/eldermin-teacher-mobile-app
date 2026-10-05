#!/usr/bin/env python3
"""Dev-only: writes the stub's Phase 5b response bodies to test/fixtures/phase5b/*.json so the Dart parser tests run
against the EXACT shapes the stub serves (which mirror the backend code, see the citations in stub_5b.py).
DUMMY data only. Run: TZ=UTC python3 tool/dev/dump_5b_fixtures.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import stub_server as s
import stub_5b as b

out = os.path.join(os.path.dirname(__file__), "..", "..", "test", "fixtures", "phase5b")
os.makedirs(out, exist_ok=True)
t = s.ACCOUNTS["teacher"]
b.reset()
_, mine = b.list_assignments(t, {"teacherId": [t["staffId"]]})
first = next(a for a in mine if a["title"].startswith("Chapter 3"))
_, subs = b.get_submissions(t, first["_id"])
ct, body = "multipart/form-data; boundary=x", b'--x\r\nContent-Disposition: form-data; name="file"; filename="w.pdf"\r\nContent-Type: application/pdf\r\n\r\nabc\r\n--x--\r\n'
_, up = b.upload_single(t, "homework-attachments", ct, body)
_, recs = b.list_records(t, {"limit": ["100"]})
_, tar = b.list_tarbiyah(t, {})
files = {
    "assignments.json": mine,
    "submissions.json": subs,
    "upload_single.json": up,
    "signed_url.json": b.signed_url("demo-school/homework-attachments/x.pdf", "http://127.0.0.1:3999")[1],
    "behaviour_records.json": recs,
    "tarbiyah.json": tar,
}
for name, data in files.items():
    with open(os.path.join(out, name), "w") as f:
        json.dump(data, f, indent=1)
print("wrote", len(files), "fixtures to", os.path.normpath(out))
