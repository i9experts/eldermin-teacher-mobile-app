import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/utils/ptm_agenda.dart';
import 'package:flutter_test/flutter_test.dart';

// Backend facts these rules rest on (eldermin-backend/src/modules/teaching/ptm.service.ts):
//  - getMeetings :91-104 returns any status for teacherId + scheduledDate in [from,to]
//  - getUpcomingForTeacher :178-183 returns requested|confirmed with scheduledDate >= now
// scheduledDate is "the picked day" stored as a Date; midnight UTC is ASSUMED (UNVERIFIED).

PtmMeeting m(String id, DateTime? date, {String start = '', String end = '', String status = 'confirmed', String name = ''}) =>
    PtmMeeting(id: id, studentName: name.isEmpty ? id : name, scheduledDate: date, startTime: start, endTime: end, status: status);

void main() {
  // Monday 5 Oct 2026 10:30 device-local.
  final now = DateTime(2026, 10, 5, 10, 30);
  final todayUtc = DateTime.utc(2026, 10, 5);

  List<String> ids(List<PtmMeeting> l) => l.map((e) => e.id).toList();

  test('splits into remaining today / earlier today / upcoming, each ordered', () {
    final a = buildPtmAgenda([
      m('later_tomorrow', DateTime.utc(2026, 10, 6), start: '09:00', end: '09:20'),
      m('done', todayUtc, start: '08:00', end: '08:20', status: 'completed'),
      m('pm', todayUtc, start: '15:00', end: '15:20'),
      m('over_by_time', todayUtc, start: '09:00', end: '09:20', status: 'confirmed'),
      m('soon', todayUtc, start: '11:00', end: '11:20', status: 'requested'),
      m('cancelled_future_time', todayUtc, start: '16:00', end: '16:20', status: 'cancelled'),
      m('noshow', todayUtc, start: '07:00', end: '07:20', status: 'no_show'),
      m('in_a_week', DateTime.utc(2026, 10, 12), start: '08:00'),
    ], now);
    expect(ids(a.remainingToday), ['soon', 'pm']);
    expect(ids(a.earlierToday), ['noshow', 'done', 'over_by_time', 'cancelled_future_time']);
    expect(ids(a.upcoming), ['later_tomorrow', 'in_a_week']);
    expect(a.isEmpty, isFalse);
  });

  test('a meeting still running (start passed, end not yet) is remaining; boundary: end == now is over', () {
    final a = buildPtmAgenda([
      m('running', todayUtc, start: '10:15', end: '10:45'),
      m('ends_now', todayUtc, start: '10:10', end: '10:30'),
    ], now);
    expect(ids(a.remainingToday), ['running']);
    expect(ids(a.earlierToday), ['ends_now']);
  });

  test('unreadable times fall back to status only', () {
    final a = buildPtmAgenda([
      m('no_times_open', todayUtc, status: 'requested'),
      m('no_times_done', todayUtc, status: 'completed'),
      m('junk_end', todayUtc, start: '09:00', end: 'soon', status: 'confirmed'),
    ], now);
    expect(ids(a.remainingToday), containsAll(['no_times_open', 'junk_end']));
    expect(ids(a.earlierToday), ['no_times_done']);
  });

  test('dedupe by _id across the two sources (first wins) and keeps distinct ids', () {
    final fromRange = m('same', todayUtc, start: '11:00', end: '11:20', name: 'range copy');
    final fromUpcoming = m('same', todayUtc, start: '11:00', end: '11:20', name: 'upcoming copy');
    final a = buildPtmAgenda([fromRange, fromUpcoming, m('other', todayUtc, start: '12:00', end: '12:20')], now);
    expect(a.remainingToday, hasLength(2));
    expect(a.remainingToday.first.studentName, 'range copy');
  });

  test('past days, undated rows and non-open future rows are dropped', () {
    final a = buildPtmAgenda([
      m('yesterday', DateTime.utc(2026, 10, 4), start: '09:00', end: '09:20', status: 'confirmed'),
      m('undated', null),
      m('future_cancelled', DateTime.utc(2026, 10, 7), status: 'cancelled'),
      m('future_completed', DateTime.utc(2026, 10, 7), status: 'completed'),
    ], now);
    expect(a.isEmpty, isTrue);
  });

  test('injectable clock: the same meeting moves from remaining to earlier as time passes', () {
    final meeting = m('x', todayUtc, start: '14:00', end: '14:20');
    expect(buildPtmAgenda([meeting], DateTime(2026, 10, 5, 13, 59)).remainingToday, hasLength(1));
    expect(buildPtmAgenda([meeting], DateTime(2026, 10, 5, 14, 20)).earlierToday, hasLength(1));
  });

  group('UTC-vs-local day edge', () {
    test('a meeting is "today" when its UTC date equals the local date', () {
      expect(isPtmToday(m('a', todayUtc), now), isTrue);
    });

    test('a meeting stored at LOCAL midnight is "today" by its local date even when its UTC date differs', () {
      final localMidnight = DateTime(2026, 10, 5); // local midnight; UTC date may be 4 Oct in zones ahead of UTC
      expect(isPtmToday(m('b', localMidnight.toUtc()), now), isTrue);
      final a = buildPtmAgenda([m('b', localMidnight.toUtc(), start: '15:00', end: '15:20')], now);
      expect(ids(a.remainingToday), ['b']);
    });

    test('midnight-UTC values (the documented form) of tomorrow/yesterday are never today, in any device zone', () {
      // Regression: in zones behind UTC, tomorrow 00:00Z has LOCAL date = today; only the UTC date may count.
      expect(isPtmToday(m('t', DateTime.utc(2026, 10, 6)), now), isFalse);
      expect(isPtmToday(m('y', DateTime.utc(2026, 10, 4)), now), isFalse);
    });

    test('a value with a time of day counts by its local date too', () {
      final noonLocalToday = DateTime(2026, 10, 5, 12);
      expect(isPtmToday(m('n', noonLocalToday.toUtc()), now), isTrue);
    });

    test('the query window covers both the UTC day and the local-day bounds', () {
      final w = ptmTodayWindow(now);
      final utcFrom = DateTime.utc(2026, 10, 5), utcTo = DateTime.utc(2026, 10, 5, 23, 59, 59, 999);
      final localFrom = DateTime(2026, 10, 5).toUtc(), localTo = DateTime(2026, 10, 5, 23, 59, 59, 999).toUtc();
      for (final t in [utcFrom, localFrom]) {
        expect(!w.from.isAfter(t), isTrue);
      }
      for (final t in [utcTo, localTo]) {
        expect(!w.to.isBefore(t), isTrue);
      }
      expect(w.from.isUtc && w.to.isUtc, isTrue);
    });
  });
}
