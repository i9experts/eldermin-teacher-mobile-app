import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// D10 guard: all visual styling under `lib/` outside `lib/core/design/` comes from the design tokens. Fails on
///   * `Color(0x…)`, `Color.fromARGB/fromRGBO`, `Colors.<anything>` except `Colors.transparent`
///   * `fontSize:` with a number literal
///   * `EdgeInsets…` / `BorderRadius…` / `Radius.circular(` calls with a number literal other than 0
///   * the removed legacy helpers (`AppColors`, `AppRadius`, `AppSpacing`, `AppTextStyles`, `AppFontSize`, `AppDimen`) and `withOpacity(`
/// Comments are ignored. The design kit itself (`lib/core/design/`) defines the tokens and is exempt.
///
/// Justified exceptions live in [_allow]: path -> rule -> reason. An entry that is no longer needed fails the test too, so the list cannot rot.
const _allow = <String, Map<String, String>>{
  'lib/core/models/calendar/calendar_models.dart': {
    'color-literal': 'parses the server-supplied hex colour of a calendar entry (dynamic data, not a design colour); it is only ever used as a dot, text stays ink',
  },
};

final _number = RegExp(r'(?<![A-Za-z_.\d])(?:[1-9]\d*(?:\.\d+)?|0\.\d*[1-9]\d*)');

String _stripComments(String s) => s.split('\n').map((l) {
      final i = l.indexOf('//');
      return i < 0 ? l : l.substring(0, i);
    }).join('\n');

/// Source of the balanced call starting at the `(` that ends [m].
String _args(String src, RegExpMatch m) {
  var depth = 0;
  for (var j = m.end - 1; j < src.length; j++) {
    if (src[j] == '(') depth++;
    if (src[j] == ')') {
      depth--;
      if (depth == 0) return src.substring(m.end - 1, j + 1);
    }
  }
  return src.substring(m.end - 1);
}

int _line(String src, int offset) => '\n'.allMatches(src.substring(0, offset)).length + 1;

Map<String, List<String>> _scan(String path, String raw) {
  final src = _stripComments(raw);
  final out = <String, List<String>>{};
  void hit(String rule, int offset) => (out[rule] ??= []).add('$path:${_line(src, offset)}');
  for (final m in RegExp(r'\bColor\(\s*0x|\bColor\.from(?:ARGB|RGBO)\(').allMatches(src)) {
    hit('color-literal', m.start);
  }
  for (final m in RegExp(r'\bColors\.(?!transparent\b)\w+').allMatches(src)) {
    hit('colors-material', m.start);
  }
  for (final m in RegExp(r'fontSize:\s*\d').allMatches(src)) {
    hit('font-size-literal', m.start);
  }
  for (final m in RegExp(r'\bEdgeInsets(?:Directional)?\.\w+\(').allMatches(src)) {
    if (_number.hasMatch(_args(src, m))) hit('inset-literal', m.start);
  }
  for (final m in RegExp(r'\b(?:BorderRadius(?:Directional)?\.\w+|Radius\.circular)\(').allMatches(src)) {
    if (_number.hasMatch(_args(src, m))) hit('radius-literal', m.start);
  }
  for (final m in RegExp(r'\b(?:AppColors|AppRadius|AppSpacing|AppTextStyles|AppFontSize|AppDimen)\b|\.withOpacity\(').allMatches(src)) {
    hit('legacy-helper', m.start);
  }
  return out;
}

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.startsWith('lib/core/design/'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('no colour / font-size / inset / radius literals and no legacy helpers outside lib/core/design/', () {
    final offenders = <String>[];
    for (final f in files) {
      final allowed = _allow[f.path] ?? const {};
      _scan(f.path, f.readAsStringSync()).forEach((rule, where) {
        if (!allowed.containsKey(rule)) offenders.addAll(where.map((w) => '$rule  $w'));
      });
    }
    expect(offenders, isEmpty, reason: 'use the tokens in lib/core/design (EmColors, EmType, EmSpacing, EmRadius), or add a justified entry to _allow:\n${offenders.join('\n')}');
  });

  test('every allowlist entry is still needed and has a reason', () {
    for (final e in _allow.entries) {
      final f = File(e.key);
      expect(f.existsSync(), isTrue, reason: '${e.key} no longer exists: remove it from _allow');
      final found = _scan(e.key, f.readAsStringSync());
      for (final r in e.value.entries) {
        expect(r.value.trim(), isNotEmpty, reason: '${e.key} $r needs a reason');
        expect(found.containsKey(r.key), isTrue, reason: '${e.key} no longer breaks "${r.key}": remove the entry');
      }
    }
  });

  test('the guard itself catches what it should (self-check on a sample)', () {
    const bad = '''
      Container(color: Color(0xFF123456), child: Text('x', style: TextStyle(fontSize: 14, color: Colors.red)))
      Padding(padding: EdgeInsets.all(8), child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12))))
      final c = AppColors.ink.withOpacity(0.5);
    ''';
    final r = _scan('sample.dart', bad);
    expect(r.keys, containsAll(['color-literal', 'colors-material', 'font-size-literal', 'inset-literal', 'radius-literal', 'legacy-helper']));
    const good = '''
      Padding(padding: EdgeInsets.all(EmSpacing.s8), child: Text('x', style: EmType.body.copyWith(color: EmColors.ink)))
      Container(color: Colors.transparent, margin: EdgeInsets.zero, child: SizedBox(width: 12), decoration: BoxDecoration(borderRadius: EmRadius.mdAll))
      // fontSize: 14 in a comment, Colors.red too
    ''';
    expect(_scan('sample.dart', good), isEmpty);
  });
}
