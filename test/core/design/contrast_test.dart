import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/models/calendar/calendar_models.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WCAG helpers', () {
    test('black on white is 21:1, same colour is 1:1', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(EmColors.primary, EmColors.primary), closeTo(1, 0.001));
    });
    test('ratio is symmetric', () {
      expect(contrastRatio(EmColors.ink, EmColors.surface), contrastRatio(EmColors.surface, EmColors.ink));
    });
    test('readableOn picks white on dark and ink on light', () {
      expect(readableOn(EmColors.primaryDark), Colors.white);
      expect(readableOn(EmColors.primary), Colors.white);
      expect(readableOn(EmColors.primaryLight), const Color(0xFF12263A));
      expect(readableOn(EmColors.accent), const Color(0xFF12263A));
      expect(readableOn(Colors.white), const Color(0xFF12263A));
      expect(readableOn(Colors.black), Colors.white);
    });
  });

  group('declared token pairs meet WCAG AA', () {
    for (final p in EmColors.contrastPairs) {
      test('${p.name} >= ${p.min}', () {
        final r = contrastRatio(p.foreground, p.background);
        expect(r, greaterThanOrEqualTo(p.min), reason: '${p.name} is ${r.toStringAsFixed(2)}:1');
      });
    }
    test('pair list has no duplicates', () {
      final names = EmColors.contrastPairs.map((p) => p.name).toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('TagStyle pairs are AA', () {
    final tags = {'info': TagStyle.info, 'amber': TagStyle.amber, 'green': TagStyle.green, 'red': TagStyle.red, 'neutral': TagStyle.neutral, 'leave': TagStyle.leave};
    tags.forEach((name, t) {
      test(name, () => expect(contrastRatio(t.fg, t.bg), greaterThanOrEqualTo(4.5)));
    });
  });

  group('every semantic colour has a container + on-colour', () {
    final sets = {
      'success': (EmColors.success, EmColors.onSuccess, EmColors.successContainer, EmColors.onSuccessContainer),
      'error': (EmColors.error, EmColors.onError, EmColors.errorContainer, EmColors.onErrorContainer),
      'warning': (EmColors.warning, EmColors.onWarning, EmColors.warningContainer, EmColors.onWarningContainer),
      'info': (EmColors.info, EmColors.onInfo, EmColors.infoContainer, EmColors.onInfoContainer),
      'statusLeave': (EmColors.statusLeave, EmColors.onStatusLeave, EmColors.statusLeaveContainer, EmColors.onStatusLeaveContainer),
    };
    sets.forEach((name, c) {
      test('$name: on-colour on solid and on-container on container are AA; container is a light tint', () {
        expect(contrastRatio(c.$2, c.$1), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c.$4, c.$3), greaterThanOrEqualTo(4.5));
        expect(relativeLuminance(c.$3), greaterThan(0.8), reason: 'container must be light');
      });
    });
  });

  group('accent is never a text colour in the theme', () {
    final theme = AppTheme.light;
    test('no text-theme style uses the accent', () {
      final t = theme.textTheme;
      for (final s in [t.displayLarge, t.headlineSmall, t.titleMedium, t.bodyLarge, t.bodyMedium, t.bodySmall, t.labelLarge, t.labelSmall]) {
        expect(s!.color, isNot(EmColors.accent));
      }
    });
    test('FAB glyph on accent is navy', () {
      expect(theme.floatingActionButtonTheme.backgroundColor, EmColors.accent);
      expect(theme.floatingActionButtonTheme.foregroundColor, EmColors.onAccent);
    });
  });

  group('AppTheme.light (entry point kept)', () {
    final theme = AppTheme.light;
    test('scaffold is the brand tint, not white', () {
      expect(theme.scaffoldBackgroundColor, EmColors.background);
      expect(theme.scaffoldBackgroundColor, isNot(Colors.white));
    });
    test('app bar is tinted, not navy', () {
      expect(theme.appBarTheme.backgroundColor, EmColors.background);
      expect(theme.appBarTheme.foregroundColor, EmColors.ink);
    });
    test('cards are white, radius 24', () {
      expect(theme.cardTheme.color, EmColors.surface);
      expect((theme.cardTheme.shape as RoundedRectangleBorder).borderRadius, BorderRadius.circular(24));
    });
    test('font family is the bundled one', () {
      expect(theme.textTheme.bodyMedium!.fontFamily, EmType.family);
      expect(EmType.family, 'PlusJakartaSans');
    });
    test('buttons are pill-shaped with >= 48dp height', () {
      final s = theme.elevatedButtonTheme.style!;
      expect(s.shape!.resolve({}), isA<StadiumBorder>());
      expect(s.minimumSize!.resolve({})!.height, greaterThanOrEqualTo(48));
    });
  });

  group('legacy AppColors alias the tokens', () {
    test('key aliases', () {
      expect(AppColors.primaryColor, EmColors.primaryDark);
      expect(AppColors.blue, EmColors.primary);
      expect(AppColors.muted, EmColors.textSecondary);
      expect(AppColors.faint, EmColors.textTertiary);
      expect(AppColors.line, EmColors.border);
      expect(AppColors.pale, EmColors.primaryContainer);
      expect(AppColors.redText, EmColors.error);
      expect(AppColors.amberText, EmColors.warning);
      expect(AppColors.amber, EmColors.accent);
      expect(AppColors.ink, EmColors.ink);
    });
    test('purple/pink family now aliases the semantic status tokens', () {
      expect(AppColors.purple, EmColors.statusLeave);
      expect(AppColors.purpleBg, EmColors.statusLeaveContainer);
      expect(AppColors.lightPurple, EmColors.statusLeaveContainer);
      expect(AppColors.categoryPurple, EmColors.statusLeave);
    });
    test('every text-bearing legacy colour used on white is AA', () {
      for (final c in [AppColors.primaryColor, AppColors.blue, AppColors.muted, AppColors.faint, AppColors.redText, AppColors.amberText, AppColors.greenText, AppColors.ink]) {
        expect(contrastRatio(c, Colors.white), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('calendar colours', () {
    test('every default event colour is AA text on white and on the scaffold tint', () {
      for (final t in CalendarEventType.values) {
        expect(contrastRatio(t.color, EmColors.surface), greaterThanOrEqualTo(4.5), reason: t.wire);
        expect(contrastRatio(t.color, EmColors.background), greaterThanOrEqualTo(4.5), reason: t.wire);
      }
    });
    test('default event colours are distinct', () {
      final v = CalendarEventType.values.map((t) => t.color.value).toSet();
      expect(v.length, CalendarEventType.values.length);
    });
    test('foreground helper: white on dark fills, ink on light fills', () {
      expect(calendarForegroundOn(const Color(0xFF123456)), Colors.white);
      expect(calendarForegroundOn(const Color(0xFFFFE08A)), const Color(0xFF12263A));
      expect(calendarForegroundOn(const Color(0xFF777777)), Colors.white);
    });
    test('server hex still overrides; onColor follows the override', () {
      Map<String, dynamic> row(String color) => {'_id': 'a', 'title': 'A', 'startDate': '2026-01-05', 'endDate': '2026-01-05', 'type': 'training', 'color': color};
      final dark = CalendarEntry.tryParse(row('#101010'))!;
      final light = CalendarEntry.tryParse(row('#F0F0A0'))!;
      expect(dark.color.value, 0xFF101010);
      expect(dark.onColor, Colors.white);
      expect(light.color.value, 0xFFF0F0A0);
      expect(light.onColor, const Color(0xFF12263A));
    });
    test('foreground helper is AA for every default event colour', () {
      for (final t in CalendarEventType.values) {
        expect(contrastRatio(calendarForegroundOn(t.color), t.color), greaterThanOrEqualTo(4.5), reason: t.wire);
      }
    });
  });
}
