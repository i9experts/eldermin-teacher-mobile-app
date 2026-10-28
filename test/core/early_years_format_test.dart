import 'package:eldermin_teacher_app/core/utils/early_years_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 5);

  group('ageLabel', () {
    test('years and months, singular and plural', () {
      expect(ageLabel(DateTime(2022, 3, 1), now), '4 years 7 months');
      expect(ageLabel(DateTime(2024, 9, 5), now), '2 years 1 month');
      expect(ageLabel(DateTime(2025, 10, 5), now), '1 year');
      expect(ageLabel(DateTime(2023, 10, 5), now), '3 years');
    });

    test('under a year: months, then weeks', () {
      expect(ageLabel(DateTime(2026, 1, 5), now), '9 months');
      expect(ageLabel(DateTime(2026, 9, 5), now), '1 month');
      expect(ageLabel(DateTime(2026, 9, 20), now), '2 weeks');
      expect(ageLabel(DateTime(2026, 10, 1), now), 'Newborn'); // 4 days old
    });

    test('the day of the month counts: the month is not complete until the birthday day', () {
      expect(ageLabel(DateTime(2022, 3, 20), now), '4 years 6 months');
    });

    test('no date, or one in the future, is no label', () {
      expect(ageLabel(null, now), isNull);
      expect(ageLabel(DateTime(2027, 1, 1), now), isNull);
    });
  });

  test('observationTypeLabel: known, unknown and empty', () {
    expect(observationTypeLabel('learning_story'), 'Learning story');
    expect(observationTypeLabel('planned'), 'Planned activity');
    expect(observationTypeLabel('free_play_moment'), 'Free play moment');
    expect(observationTypeLabel(''), 'Observation');
  });

  test('levelFraction: position among the levels, case-insensitive; unknown level is null', () {
    const levels = ['Not Observed', 'Emerging', 'Developing', 'Consistent', 'Independent', 'Mastered'];
    expect(levelFraction('Not Observed', levels), closeTo(1 / 6, 1e-9));
    expect(levelFraction(' developing ', levels), 0.5);
    expect(levelFraction('Mastered', levels), 1.0);
    expect(levelFraction('Something else', levels), isNull);
    expect(levelFraction('Emerging', const []), isNull);
  });
}
