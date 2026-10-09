// Shared helpers of the Phase 7 part 2 LOCAL end-to-end verification (integration_test/p7c_local_test.dart) against the LOCAL backend
// (isolated DB eldermin_teacher_verify, NOT staging, NOT the stub, no shim). Same anti-loop rules as p7a_local_common.dart (capped waits,
// 240 s step budget, `leaveScreen` taps Discard never Cancel, shell watchdog in tool/dev/capture_p7c.sh). Not a test itself.
import 'dart:io';
import 'dart:typed_data';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'package:eldermin_teacher_app/core/services/avatar_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p7a_local_common.dart' hide pshot;

export 'p7a_local_common.dart' hide pshot;

// ignore_for_file: avoid_print

var _p7cShot = p7ShotStart - 1;

/// Screenshot marker `p7c_NN_<name>` (the capture script turns it into a simulator screenshot).
Future<void> pshot(WidgetTester t, String name, {int ms = 1500}) async {
  await t.pump(Duration(milliseconds: ms));
  _p7cShot++;
  print('SHOT:p7c_${_p7cShot.toString().padLeft(2, '0')}_$name');
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1400)));
  await t.pump(const Duration(milliseconds: 100));
}

void expectEq(String what, Object? actual, Object? expected) {
  result(what, actual);
  if ('$actual' != '$expected') throw TestFailure('$what: expected $expected, got $actual');
}

void expectTrue(String what, bool cond) {
  result(what, cond);
  if (!cond) throw TestFailure('$what: expected true');
}

bool hasText(String s) => find.textContaining(s).evaluate().isNotEmpty;

/// A generated real file on the simulator.
Future<String> tempFile(String name, int bytes, {int fill = 37}) async {
  final dir = await Directory.systemTemp.createTemp('p7c_pick');
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(Uint8List(bytes)..fillRange(0, bytes, fill));
  return f.path;
}

/// Fake photo picker (the system picker cannot be driven): returns the file set in [next]; the real multipart upload then runs against the real backend.
class FakeAvatarPicker implements AvatarPicker {
  PickedAvatar? next;
  @override
  Future<PickedAvatar?> pick(AvatarSource source) async => next;
}

class FakeAttachmentPicker implements AttachmentPicker {
  List<PickedAttachment> next = [];
  @override
  Future<List<PickedAttachment>> pickDocuments() async => next;
  @override
  Future<List<PickedAttachment>> pickPhotos() async => next;
}

/// A valid 64x64 PNG (zlib + crc32) so the upload is a real image.
Uint8List smallPng() {
  const n = 64;
  final raw = BytesBuilder();
  for (var y = 0; y < n; y++) {
    raw.addByte(0);
    for (var x = 0; x < n; x++) {
      raw.add([37 + x, 110 + y, 170 - x]);
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

  List<int> u32(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    return [...u32(data.length), ...body, ...u32(crc(body))];
  }

  return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...chunk('IHDR', [...u32(n), ...u32(n), 8, 2, 0, 0, 0]), ...chunk('IDAT', ZLibCodec().encode(raw.toBytes())), ...chunk('IEND', const [])]);
}
