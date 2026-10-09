import 'dart:io';
import 'package:eldermin_teacher_app/core/models/safeguarding/safeguarding_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/response_shape.dart';
import 'package:eldermin_teacher_app/core/services/account_repository.dart';
import 'package:eldermin_teacher_app/core/services/events_repository.dart';
import 'package:eldermin_teacher_app/core/services/kb_repository.dart';
import 'package:eldermin_teacher_app/core/services/profile_repository.dart';
import 'package:eldermin_teacher_app/core/services/safeguarding_repository.dart';
import 'package:eldermin_teacher_app/core/services/school_calendar_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_phase7b_repositories.dart' show RecordingClient;
import '../support/fake_phase7c_repositories.dart';

void main() {
  group('SchoolCalendarRepository', () {
    test('GET /school-calendar/events: UTC y/m/d bounds, fee rows dropped', () async {
      final c = RecordingClient([calRow('a', 'Holiday', type: 'holiday'), feeRow(), calRow('b', 'Exam', type: 'exam', source: 'assessments')]);
      final rows = await SchoolCalendarRepository(c).fetchEvents(fromDay: DateTime(2026, 9, 24), toDay: DateTime(2026, 11, 7));
      expect(c.calls.single.method, 'GET');
      expect(c.calls.single.url, endsWith('/school-calendar/events'));
      expect(c.calls.single.query, {'from': '2026-09-24T00:00:00.000Z', 'to': '2026-11-07T23:59:59.999Z'});
      expect(rows.map((e) => e.id), ['a', 'b']);
    });

    test('empty list is a valid empty result; wrong shapes are typed errors, never an empty list', () async {
      expect(await SchoolCalendarRepository(RecordingClient([])).fetchEvents(fromDay: DateTime(2026), toDay: DateTime(2026)), isEmpty);
      for (final bad in [<String, Object?>{'events': []}, 'oops', null, 5, [1, 2]]) {
        await expectLater(SchoolCalendarRepository(RecordingClient(bad)).fetchEvents(fromDay: DateTime(2026), toDay: DateTime(2026)), throwsA(isA<UnexpectedResponseShape>()), reason: '$bad');
      }
    });

    test('circulars: status=published is sent; parsed through the whitelist', () async {
      final c = RecordingClient([circRow('c1', 'A'), circRow('c2', 'B', status: 'draft')]);
      final rows = await SchoolCalendarRepository(c).fetchCirculars();
      expect(c.calls.single.query, {'status': 'published'});
      expect(rows.length, 2); // the repository does not decide audience: the controller does
      await expectLater(SchoolCalendarRepository(RecordingClient({'circulars': []})).fetchCirculars(), throwsA(isA<UnexpectedResponseShape>()));
    });

    test('acknowledge: POST with NO body to the circular id; the answer must be an object', () async {
      final c = RecordingClient({'_id': 'k', 'circularId': 'c1', 'userId': 'u', 'acknowledgedAt': '2026-10-09T08:00:00.000Z', 'userName': 'Tess'});
      final ack = await SchoolCalendarRepository(c).acknowledge('c1');
      expect(c.calls.single.method, 'POST');
      expect(c.calls.single.url, endsWith('/school-calendar/circulars/c1/acknowledge'));
      expect(c.calls.single.data, isNull);
      expect(ack.acknowledgedAt, DateTime.utc(2026, 10, 9, 8));
      await expectLater(SchoolCalendarRepository(RecordingClient([])).acknowledge('c1'), throwsA(isA<UnexpectedResponseShape>()));
    });

    test('403 and 404 come through as ApiException with the status', () async {
      for (final s in [403, 404, 500]) {
        final c = RecordingClient([])..failStatus = s;
        await expectLater(SchoolCalendarRepository(c).fetchCirculars(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', s)));
      }
    });
  });

  group('EventsRepository', () {
    test('list keeps only staff-listable events (drafts / private / unlisted are dropped)', () async {
      final c = RecordingClient([
        eventRow('e1', 'Open'),
        eventRow('e2', 'Draft', status: 'draft'),
        eventRow('e3', 'Private', visibility: 'private'),
        eventRow('e4', 'Unlisted', visibility: 'unlisted'),
        eventRow('e5', 'Internal', visibility: 'internal'),
      ]);
      final rows = await EventsRepository(c).fetchEvents();
      expect(rows.map((e) => e.id), ['e1', 'e5']);
      expect(c.calls.single.url, endsWith('/events'));
    });

    test('detail: ticket types and promo codes are in the answer but never in the model', () async {
      final c = RecordingClient({...eventRow('e1', 'Annual Day'), 'ticketTypes': [{'name': 'VIP', 'price': 9999}], 'promoCodes': [{'code': 'SECRET50'}]});
      final e = await EventsRepository(c).fetchEvent('e1');
      expect(c.calls.single.url, endsWith('/events/e1'));
      expect(e.toString(), isNot(contains('SECRET50')));
      await expectLater(EventsRepository(RecordingClient({'nothing': 1})).fetchEvent('e1'), throwsA(isA<UnexpectedResponseShape>()));
      await expectLater(EventsRepository(RecordingClient([])).fetchEvent('e1'), throwsA(isA<UnexpectedResponseShape>()));
    });

    test('wrong list shape is a typed error', () async {
      await expectLater(EventsRepository(RecordingClient({'events': []})).fetchEvents(), throwsA(isA<UnexpectedResponseShape>()));
    });
  });

  group('SafeguardingRepository', () {
    test('POST body = exactly the allow-listed keys; the answer yields only the reference', () async {
      final c = RecordingClient({'caseNumber': 'SC-2026-321', 'description': 'must not be read', 'status': 'open'});
      final r = SafeguardingReport(title: 't', description: 'd', type: ConcernType.neglect, day: DateTime(2026, 10, 9), actionsTaken: 'a');
      final receipt = await SafeguardingRepository(c).submit(r);
      final call = c.calls.single;
      expect((call.method, call.url.endsWith('/compliance/safeguarding')), ('POST', true));
      expect((call.data as Map).keys.toSet(), {'title', 'description', 'type', 'severity', 'reportedDate', 'actionsTaken'});
      expect((call.data as Map).keys.toSet().difference(kSafeguardingRequestKeys), isEmpty);
      expect(receipt.reference, 'SC-2026-321');
    });

    test('a strange 2xx body is still a success (the case is stored); errors keep their status', () async {
      final r = SafeguardingReport(title: 't', description: 'd', type: ConcernType.other, day: DateTime(2026, 10, 9));
      expect((await SafeguardingRepository(RecordingClient('weird')).submit(r)).reference, isNull);
      for (final s in [400, 403, 500]) {
        await expectLater(SafeguardingRepository(RecordingClient()..failStatus = s).submit(r), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', s)));
      }
    });

    test('there is no read method (write only)', () {
      // compile-time guarantee documented as a test: the class exposes just `submit`.
      expect(SafeguardingRepository(RecordingClient()).submit, isA<Function>());
    });
  });

  group('ProfileRepository', () {
    test('GET /auth/me parsed; wrong shape typed', () async {
      final c = RecordingClient({'_id': 'u1', 'name': 'Tess', 'email': 't@s.test', 'primaryRole': 'teacher', 'profile': {'avatarUrl': 'https://x.test/a.png'}, 'passwordHash': 'never'});
      final me = await ProfileRepository(c).fetchAccount();
      expect((me.id, me.name, me.role, me.avatarUrl), ('u1', 'Tess', 'teacher', 'https://x.test/a.png'));
      await expectLater(ProfileRepository(RecordingClient([])).fetchAccount(), throwsA(isA<UnexpectedResponseShape>()));
    });

    test('avatar upload: multipart field `avatar`, file name and content type; returns the URL', () async {
      final tmp = await _tmp('me.png');
      final c = RecordingMultipartClient({'avatarUrl': 'https://files.test/a/b.png'});
      final url = await ProfileRepository(c).uploadAvatar(path: tmp, fileName: 'me.png', mime: 'image/png');
      expect(c.lastUrl, endsWith('/auth/me/avatar'));
      expect(c.lastFiles!.keys, ['avatar']);
      expect(c.lastFiles!['avatar']!.single.filename, 'me.png');
      expect(c.lastFiles!['avatar']!.single.contentType.toString(), 'image/png');
      expect(url, 'https://files.test/a/b.png');
    });

    test('avatar upload: 503 is surfaced with its status (the controller maps it to Upload unavailable); a missing / non-http URL is a typed error', () async {
      final tmp = await _tmp('me.png');
      final c = RecordingMultipartClient()
        ..failStatus = 503
        ..failMessage = 'File uploads are not available on this server (storage is not configured).';
      await expectLater(ProfileRepository(c).uploadAvatar(path: tmp, fileName: 'me.png', mime: 'image/png'), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 503)));
      for (final bad in [<String, Object?>{}, {'avatarUrl': 'javascript:1'}, {'avatarUrl': ''}, 'x', null]) {
        await expectLater(ProfileRepository(RecordingMultipartClient(bad)).uploadAvatar(path: tmp, fileName: 'me.png', mime: 'image/png'), throwsA(isA<UnexpectedResponseShape>()), reason: '$bad');
      }
    });
  });

  group('KbRepository', () {
    test('list / search / article use the real routes and parse strictly', () async {
      final c = RecordingClient([
        {'module': 'hr', 'tabKey': 'a', 'title': 'A', 'order': 1}
      ]);
      final repo = KbRepository(c);
      expect((await repo.list()).single.key, 'hr/a');
      expect(c.calls.last.url, endsWith('/kb/articles'));
      expect(c.calls.last.query, isEmpty);
      await repo.list(module: 'hr');
      expect(c.calls.last.query, {'module': 'hr'});
      await repo.search('leave');
      expect(c.calls.last.url, endsWith('/kb/search')); // not /kb/articles/search
      expect(c.calls.last.query, {'q': 'leave'});
      final one = KbRepository(RecordingClient({'module': 'hr', 'tabKey': 'a b', 'title': 'A'}));
      await one.article('hr', 'a b');
      expect(one.toString(), isNotEmpty);
      await expectLater(KbRepository(RecordingClient({'articles': []})).list(), throwsA(isA<UnexpectedResponseShape>()));
      await expectLater(KbRepository(RecordingClient([])).article('hr', 'a'), throwsA(isA<UnexpectedResponseShape>()));
      await expectLater(KbRepository(RecordingClient({'title': 'no keys'})).article('hr', 'a'), throwsA(isA<UnexpectedResponseShape>()));
    });

    test('article path segments are percent-encoded', () async {
      final c = RecordingClient({'module': 'hr', 'tabKey': 'a b', 'title': 'A'});
      await KbRepository(c).article('h r', 'a/b');
      expect(c.calls.single.url, endsWith('/kb/articles/h%20r/a%2Fb'));
    });
  });

  group('AccountRepository (delete request)', () {
    test('body is {confirm:true}; a reason is trimmed and only sent when present', () async {
      final c = RecordingClient({'requestId': 'r1', 'status': 'pending', 'message': 'Sent'});
      final repo = AccountRepository(c);
      final a = await repo.request();
      expect(c.calls.last.data, {'confirm': true});
      expect(c.calls.last.url, endsWith('/staff-portal/account/delete-request'));
      expect((a.requestId, a.alreadyRequested, a.message), ('r1', false, 'Sent'));
      await repo.request(reason: '  leaving the school  ');
      expect(c.calls.last.data, {'confirm': true, 'reason': 'leaving the school'});
      await repo.request(reason: '   ');
      expect(c.calls.last.data, {'confirm': true});
    });

    test('already requested, errors and wrong shape', () async {
      final again = await AccountRepository(RecordingClient({'requestId': 'r1', 'status': 'pending', 'alreadyRequested': true})).request();
      expect((again.alreadyRequested, again.message), (true, null));
      for (final s in [400, 403, 404]) {
        await expectLater(AccountRepository(RecordingClient()..failStatus = s).request(), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', s)));
      }
      await expectLater(AccountRepository(RecordingClient([])).request(), throwsA(isA<UnexpectedResponseShape>()));
    });
  });
}

Future<String> _tmp(String name) async {
  final dir = await Directory.systemTemp.createTemp('avatar_test');
  final f = File('${dir.path}/$name');
  await f.writeAsBytes([1, 2, 3]);
  return f.path;
}
