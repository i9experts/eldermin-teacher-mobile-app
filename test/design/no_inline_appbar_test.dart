import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// D5 guard: every screen uses `EmAppBar`; a raw Material `AppBar(` (or `SliverAppBar(`) anywhere under lib/ outside the design kit itself
/// is a regression. Comments are ignored.
void main() {
  test('no inline AppBar( remains outside EmAppBar', () {
    final raw = RegExp(r'(?<![A-Za-z])(Sliver)?AppBar\(');
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('core/design/widgets/em_app_bar.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (raw.hasMatch(code)) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'use EmAppBar (lib/core/design/widgets/em_app_bar.dart)');
  });

  test('CustomAppBarTwo stays deleted', () {
    expect(File('lib/app/components/custom_app_bar_two.dart').existsSync(), isFalse);
  });
}
