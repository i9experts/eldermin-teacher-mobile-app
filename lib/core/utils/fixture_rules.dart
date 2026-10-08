import '../models/home/teaching.dart';
import '../models/json_helpers.dart';

/// Which side of a substitution I am on.
enum FixtureTab { covering, covered }

bool _same(String? a, String? b) => a != null && a.isNotEmpty && b != null && b.isNotEmpty && a == b;

/// I am the SUBSTITUTE (I cover someone else's period).
bool iAmSubstitute(Substitution s, String? myStaffId) => _same(s.substituteTeacherId, myStaffId);

/// I am the ORIGINAL teacher (someone covers my period).
bool iAmOriginal(Substitution s, String? myStaffId) => _same(s.originalTeacherId, myStaffId);

/// 'Mark complete' is offered ONLY to the substitute of an `assigned` fixture. The server does not check who calls
/// (`substitution.service.ts:223-230`: any teaching writer can complete any assigned fixture), so this is UI-only gating.
bool canMarkComplete(Substitution s, String? myStaffId) => s.status == 'assigned' && iAmSubstitute(s, myStaffId);

/// Rows of the 'Covering for others' tab (I am the substitute) and of the 'My periods covered' tab (I am the original and not also the
/// substitute).
List<Substitution> rowsFor(FixtureTab tab, Iterable<Substitution> all, String? myStaffId) => [
      for (final s in all)
        if (tab == FixtureTab.covering ? iAmSubstitute(s, myStaffId) : (iAmOriginal(s, myStaffId) && !iAmSubstitute(s, myStaffId))) s
    ];

/// The calendar day of a fixture (`date` is stored from the writer's date string = UTC midnight; UNVERIFIED for writers that send a time).
DateTime? fixtureDay(Substitution s) => storedCalendarDay(s.date);

class FixtureDay {
  final DateTime day;
  final bool upcoming; // today or later
  final List<Substitution> rows;
  const FixtureDay(this.day, this.upcoming, this.rows);
}

/// Rows grouped by calendar day: today and later first (soonest first), then earlier days (most recent first); inside a day by period number.
/// Rows without a readable date are never given an invented day: they come back separately in `undated`.
({List<FixtureDay> days, List<Substitution> undated}) groupFixtures(Iterable<Substitution> rows, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final byDay = <DateTime, List<Substitution>>{};
  final undated = <Substitution>[];
  for (final s in rows) {
    final d = fixtureDay(s);
    if (d == null) {
      undated.add(s);
    } else {
      byDay.putIfAbsent(d, () => []).add(s);
    }
  }
  int byPeriod(Substitution a, Substitution b) => (a.periodNo ?? 1 << 20).compareTo(b.periodNo ?? 1 << 20);
  final days = byDay.keys.toList();
  final future = days.where((d) => !d.isBefore(today)).toList()..sort();
  final past = days.where((d) => d.isBefore(today)).toList()..sort((a, b) => b.compareTo(a));
  return (
    days: [
      for (final d in future) FixtureDay(d, true, byDay[d]!..sort(byPeriod)),
      for (final d in past) FixtureDay(d, false, byDay[d]!..sort(byPeriod)),
    ],
    undated: undated,
  );
}

/// The start of the window the list loads from: 14 days before today (UTC day), no upper bound (future cover is what matters).
DateTime fixturesFrom(DateTime now) => DateTime.utc(now.year, now.month, now.day).subtract(const Duration(days: 14));
