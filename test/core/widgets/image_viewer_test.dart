import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/app/components/external_link.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/widgets/detail_bottom_sheet.dart';
import 'package:eldermin_teacher_app/core/widgets/image_viewer.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class _Failing extends ImageProvider<_Failing> {
  _Failing(this.url);
  final String url;
  @override
  Future<_Failing> obtainKey(ImageConfiguration c) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_Failing key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future<ImageInfo>.error(Exception('boom')));
  @override
  bool operator ==(Object o) => o is _Failing && o.url == url;
  @override
  int get hashCode => url.hashCode;
}

class _Pending extends ImageProvider<_Pending> {
  _Pending(this.url);
  final String url;
  @override
  Future<_Pending> obtainKey(ImageConfiguration c) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_Pending key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  @override
  bool operator ==(Object o) => o is _Pending && o.url == url;
  @override
  int get hashCode => url.hashCode;
}

/// Image decoding is real async work: give it time, then let the route and frame settle.
Future<void> _settleImage(WidgetTester t) async {
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await t.pumpAndSettle();
}

Widget _app(Widget home) => GetMaterialApp(home: home);

Widget _sheet(List<DetailAttachment> a, {void Function(String)? open}) =>
    _app(Scaffold(body: SizedBox(height: 700, child: DetailBottomSheet(data: DetailSheetData(title: 'T', attachments: a), onOpenAttachment: open))));

void main() {
  late List<Uri> launched;
  late ImageProvider Function(String) oldProvider;
  late Future<bool> Function(Uri) oldLauncher;
  var requested = <String>[];

  setUp(() {
    launched = [];
    requested = [];
    oldProvider = ImageViewer.providerFor;
    oldLauncher = ExternalLinks.launcher;
    ExternalLinks.launcher = (u) async {
      launched.add(u);
      return true;
    };
    ImageViewer.providerFor = (u) {
      requested.add(u);
      return MemoryImage(_png);
    };
  });
  tearDown(() {
    ImageViewer.providerFor = oldProvider;
    ExternalLinks.launcher = oldLauncher;
  });

  Future<void> openViewer(WidgetTester t, {String url = 'https://signed.example/a.jpg', Future<String?> Function()? refresh, String title = 'Our painting'}) async {
    await t.pumpWidget(_sheet([DetailAttachment(title, url, isImage: true, refreshUrl: refresh)]));
    await t.tap(find.byKey(ValueKey('detail_attachment_$url')));
    await _settleImage(t);
  }

  testWidgets('tapping an image attachment opens the in-app viewer, shows the image and never launches a browser', (t) async {
    await openViewer(t);
    expect(find.byKey(const Key('image_viewer')), findsOneWidget);
    final img = t.widget<Image>(find.byType(Image));
    expect(img.image, isA<MemoryImage>());
    expect(requested, contains('https://signed.example/a.jpg'));
    expect(find.bySemanticsLabel('Our painting'), findsOneWidget);
    expect(find.text('Open this link?'), findsNothing);
    expect(launched, isEmpty);
  });

  testWidgets('a non-image attachment keeps confirm-before-open and the external launcher', (t) async {
    await t.pumpWidget(_sheet(const [DetailAttachment('Form.pdf', 'https://files.example/f.pdf')]));
    await t.tap(find.byKey(const ValueKey('detail_attachment_https://files.example/f.pdf')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('image_viewer')), findsNothing);
    expect(find.text('Open this link?'), findsOneWidget);
    expect(launched, isEmpty);
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(launched.single.toString(), 'https://files.example/f.pdf');
  });

  testWidgets('an image attachment ignores onOpenAttachment; a non-image still uses it', (t) async {
    final opened = <String>[];
    await t.pumpWidget(_sheet(const [DetailAttachment('P', 'https://x/p.jpg', isImage: true), DetailAttachment('D', 'https://x/d.pdf')], open: opened.add));
    await t.tap(find.byKey(const ValueKey('detail_attachment_https://x/d.pdf')));
    await t.pump();
    expect(opened, ['https://x/d.pdf']);
    await t.tap(find.byKey(const ValueKey('detail_attachment_https://x/p.jpg')));
    await t.pumpAndSettle();
    expect(opened, ['https://x/d.pdf']);
    expect(find.byKey(const Key('image_viewer')), findsOneWidget);
  });

  testWidgets('pinch-zoom container: InteractiveViewer with 1x..5x scale', (t) async {
    await openViewer(t);
    final iv = t.widget<InteractiveViewer>(find.byKey(const Key('image_viewer_zoom')));
    expect(iv.minScale, 1);
    expect(iv.maxScale, 5);
  });

  testWidgets('close button pops the viewer', (t) async {
    await openViewer(t);
    expect(find.bySemanticsLabel('Close photo'), findsOneWidget);
    await t.tap(find.byKey(const Key('image_viewer_close')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('image_viewer')), findsNothing);
    expect(find.byType(DetailBottomSheet), findsOneWidget);
  });

  testWidgets('system back closes the viewer', (t) async {
    await openViewer(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('image_viewer')), findsNothing);
  });

  testWidgets('swipe down at 1x closes the viewer', (t) async {
    await openViewer(t);
    await t.fling(find.byKey(const Key('image_viewer_zoom')), const Offset(0, 400), 2000);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('image_viewer')), findsNothing);
  });

  testWidgets('loading state shows while the image loads', (t) async {
    ImageViewer.providerFor = _Pending.new;
    await t.pumpWidget(_sheet(const [DetailAttachment('P', 'https://x/p.jpg', isImage: true)]));
    await t.tap(find.byKey(const ValueKey('detail_attachment_https://x/p.jpg')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('image_viewer')), findsOneWidget);
    expect(find.byType(EmLoading), findsOneWidget);
    expect(find.byKey(const Key('image_viewer_error')), findsNothing);
  });

  group('error state', () {
    Future<void> openFailing(WidgetTester t, {Future<String?> Function()? refresh}) async {
      ImageViewer.providerFor = (u) {
        requested.add(u);
        return _Failing(u);
      };
      await t.pumpWidget(_sheet([DetailAttachment('P', 'https://x/old.jpg', isImage: true, refreshUrl: refresh)]));
      await t.tap(find.byKey(const ValueKey('detail_attachment_https://x/old.jpg')));
      await t.pumpAndSettle();
    }

    testWidgets('shows the message, Try again and Close', (t) async {
      await openFailing(t);
      expect(find.byKey(const Key('image_viewer_error')), findsOneWidget);
      expect(find.text('Photo could not be loaded'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Try again without refreshUrl re-requests the same link', (t) async {
      await openFailing(t);
      final before = requested.length;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(requested.length, greaterThan(before));
      expect(requested.last, 'https://x/old.jpg');
      expect(find.byKey(const Key('image_viewer_error')), findsOneWidget);
    });

    testWidgets('Try again calls refreshUrl first and loads the fresh link', (t) async {
      var calls = 0;
      await openFailing(t, refresh: () async {
        calls++;
        return 'https://x/new.jpg';
      });
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(requested.last, 'https://x/new.jpg');
    });

    testWidgets('a fresh link that loads replaces the error with the image', (t) async {
      ImageViewer.providerFor = (u) => u.contains('new') ? MemoryImage(_png) as ImageProvider : _Failing(u);
      await t.pumpWidget(_sheet([DetailAttachment('P', 'https://x/old.jpg', isImage: true, refreshUrl: () async => 'https://x/new.jpg')]));
      await t.tap(find.byKey(const ValueKey('detail_attachment_https://x/old.jpg')));
      await t.pumpAndSettle();
      await t.tap(find.text('Try again'));
      await _settleImage(t);
      expect(find.byKey(const Key('image_viewer_error')), findsNothing);
      expect(t.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    });

    testWidgets('Try again survives a throwing refreshUrl (keeps the old link)', (t) async {
      await openFailing(t, refresh: () async => throw Exception('offline'));
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(requested.last, 'https://x/old.jpg');
      expect(find.byKey(const Key('image_viewer_error')), findsOneWidget);
    });

    testWidgets('Close pops the viewer', (t) async {
      await openFailing(t);
      await t.tap(find.byKey(const Key('image_viewer_error_close')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('image_viewer')), findsNothing);
    });
  });

  test('the viewer source uses no disk, cache-package, gallery or logging APIs', () {
    final src = File('lib/core/widgets/image_viewer.dart').readAsStringSync().split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');
    for (final banned in [r'dart:io', r'path_provider', r'cached_network_image', r'flutter_cache_manager', r'gallery', r'\bFile\(', r'\bprint\(', r'debugPrint', r'\blog\(', r'writeAs', r'url_launcher', r'ExternalLinks']) {
      expect(RegExp(banned).hasMatch(src), isFalse, reason: 'image_viewer.dart must not use $banned');
    }
  });
}
