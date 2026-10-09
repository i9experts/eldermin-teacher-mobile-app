// Helpers of the Phase 7c walkthroughs (calendar, events, safeguarding, profile, help, delete account) against the LOCAL STUB (tool/dev/stub_server.py +
// stub_7c.py, DUMMY data). Re-exports the 7a helpers (same anti-loop rules: capped waits, 240 s step budget, `leaveScreen` taps Discard never Cancel,
// shell watchdog in tool/dev/capture_7c.sh). PRIVACY: the safeguarding walkthrough types DUMMY text only.
import 'dart:io';
import 'dart:typed_data';
import 'package:eldermin_teacher_app/core/services/avatar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'phase7a_common.dart';

export 'phase7a_common.dart';

// ignore_for_file: avoid_print

/// More tab -> the entry with [title] -> waits for [until].
Future<void> openFromMore(WidgetTester t, String title, Finder until) async {
  await t.tap(navLabel('More'));
  await settle(t, 1000);
  final entry = find.text(title);
  await t.scrollUntilVisible(entry, 250,
      scrollable: find.byType(Scrollable).last, maxScrolls: 14);
  await settle(t, 400);
  await t.tap(entry);
  await waitFor(t, until);
  await settle(t, 1200);
}

Future<void> pullToRefresh(WidgetTester t) async {
  await t.drag(find.byType(ListView).first, const Offset(0, 500));
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(seconds: 2));
}

Future<void> mode(WidgetTester t, String feature, String value) =>
    stub(t, '/__stub/mode?feature=$feature&value=$value');

/// A fake photo picker: returns a generated 96x96 PNG (a real file on the simulator) so the REAL multipart upload runs against the stub.
class WalkthroughPicker implements AvatarPicker {
  AvatarPickDenied? deny;
  String? _path;

  Future<String> _png() async {
    final p = _path;
    if (p != null) return p;
    final bytes = _pngBytes();
    final dir = await Directory.systemTemp.createTemp('walkthrough_avatar');
    final f = File('${dir.path}/me.png');
    await f.writeAsBytes(bytes);
    return _path = f.path;
  }

  @override
  Future<PickedAvatar?> pick(AvatarSource source) async {
    final d = deny;
    if (d != null) throw AvatarPickDenied(source);
    final path = await _png();
    return PickedAvatar(
        path: path, name: 'me.png', size: await File(path).length());
  }
}

/// A valid 96x96 gradient PNG built in Dart (zlib + crc32), so the real multipart upload carries a real image.
Uint8List _pngBytes() {
  const n = 96;
  final raw = BytesBuilder();
  for (var y = 0; y < n; y++) {
    raw.addByte(0);
    for (var x = 0; x < n; x++) {
      raw.add([37 + x, 110 + y ~/ 2, 170 - x ~/ 2]);
    }
  }
  final table = List<int>.generate(256, (i) {
    var c = i;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });
  int crc(List<int> d) {
    var c = 0xFFFFFFFF;
    for (final b in d) {
      c = table[(c ^ b) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }

  List<int> u32(int v) =>
      [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    return [...u32(data.length), ...body, ...u32(crc(body))];
  }

  return Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    ...chunk('IHDR', [...u32(n), ...u32(n), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', ZLibCodec().encode(raw.toBytes())),
    ...chunk('IEND', const []),
  ]);
}
