import 'dart:convert';
import 'package:eldermin_teacher_app/core/models/calendar/calendar_models.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/models/help/kb_models.dart';
import 'package:eldermin_teacher_app/core/models/safeguarding/safeguarding_models.dart';
import 'package:eldermin_teacher_app/core/services/account_repository.dart';
import 'package:eldermin_teacher_app/core/utils/avatar_rules.dart';
import 'package:eldermin_teacher_app/core/utils/safe_text.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_phase7c_repositories.dart';

void main() {
  group('calendar entries: whitelist', () {
    test('a fee row is dropped, whatever shape it has, and its description is never read', () {
      expect(CalendarEntry.tryParse(feeRow()), isNull);
      expect(CalendarEntry.tryParse({...calRow('x', 'Sneaky', type: 'fee_due')}), isNull);
      expect(CalendarEntry.tryParse({...calRow('y', 'Sneaky', source: 'finance')}), isNull);
      expect(CalendarEntry.tryParse({...calRow('fee-due-2026-10-12', 'Sneaky')}), isNull);
      final list = parseCalendarEntries([calRow('a', 'Holiday', type: 'holiday'), feeRow(), calRow('b', 'Exam', type: 'exam', source: 'assessments')]);
      expect(list.map((e) => e.id), ['a', 'b']);
      expect(jsonEncode(list.map((e) => [e.title, e.description]).toList()), isNot(contains('outstanding')));
    });

    test('the model has no field that could carry money: only the whitelisted keys are read (extra keys are ignored)', () {
      final e = CalendarEntry.tryParse({...calRow('a', 'Holiday', type: 'holiday'), 'totalAmount': 5, 'balanceDue': 9, 'feeTotal': 7, 'amount': 3})!;
      expect(e.toString(), isNot(contains('9')));
      // a model built only from whitelisted keys equals one built from the same row without the extras
      final clean = CalendarEntry.tryParse(calRow('a', 'Holiday', type: 'holiday'))!;
      expect((e.id, e.title, e.description, e.type, e.start, e.end, e.allDay), (clean.id, clean.title, clean.description, clean.type, clean.start, clean.end, clean.allDay));
    });

    test('type -> colour per CALENDAR_EVENT_COLORS; an own #RRGGBB colour wins; a bad colour falls back; unknown type = other', () {
      expect(CalendarEventType.holiday.color.value, 0xFFE24B4A);
      expect(CalendarEventType.exam.color.value, 0xFF7F77DD);
      expect(CalendarEventType.academicTerm.color.value, 0xFF008300);
      expect(CalendarEntry.tryParse(calRow('a', 'A', type: 'training', color: '#123456'))!.color.value, 0xFF123456);
      expect(CalendarEntry.tryParse(calRow('a', 'A', type: 'training', color: 'red'))!.color.value, CalendarEventType.training.color.value);
      expect(CalendarEntry.tryParse(calRow('a', 'A', type: 'zzz'))!.type, CalendarEventType.other);
    });

    test('rows without id / title / start date are skipped; end before start is clamped; allDay defaults to true', () {
      expect(CalendarEntry.tryParse({'title': 'x', 'startDate': '2026-10-12T00:00:00.000Z'}), isNull);
      expect(CalendarEntry.tryParse({'_id': 'a', 'startDate': '2026-10-12T00:00:00.000Z'}), isNull);
      expect(CalendarEntry.tryParse({'_id': 'a', 'title': 'x'}), isNull);
      expect(CalendarEntry.tryParse({'_id': 'a', 'title': 'x', 'startDate': 'garbage'}), isNull);
      final e = CalendarEntry.tryParse({'_id': 'a', 'title': 'x', 'startDate': '2026-10-12T00:00:00.000Z', 'endDate': '2026-10-01T00:00:00.000Z'})!;
      expect((e.end, e.allDay), (e.start, true));
    });
  });

  group('calendar days are timezone safe (the suite is also run under UTC, Pacific/Auckland, America/Los_Angeles, Asia/Karachi)', () {
    test('an all-day entry stored at UTC midnight shows on that calendar day in ANY zone', () {
      final e = CalendarEntry.tryParse(calRow('a', 'Holiday', start: '2026-10-12T00:00:00.000Z'))!;
      expect(e.firstDay, DateTime(2026, 10, 12));
      expect(e.lastDay, DateTime(2026, 10, 12));
      expect(e.coversDay(DateTime(2026, 10, 12)), isTrue);
      expect(e.coversDay(DateTime(2026, 10, 11)), isFalse);
      expect(e.coversDay(DateTime(2026, 10, 13)), isFalse);
      expect(e.timeLabel(), 'All day');
    });

    test('a plain YYYY-MM-DD string is UTC midnight too (never local midnight)', () {
      expect(parseWireInstant('2026-10-12'), DateTime.utc(2026, 10, 12));
      final e = CalendarEntry.tryParse({...calRow('a', 'A'), 'startDate': '2026-10-12', 'endDate': '2026-10-14'})!;
      expect((e.firstDay, e.lastDay), (DateTime(2026, 10, 12), DateTime(2026, 10, 14)));
    });

    test('multi-day all-day span covers each day inclusive; the day after the last is free', () {
      final e = CalendarEntry.tryParse(calRow('a', 'Break', type: 'holiday', start: '2026-10-12T00:00:00.000Z', end: '2026-10-14T00:00:00.000Z'))!;
      expect(e.isMultiDay, isTrue);
      for (final d in [12, 13, 14]) {
        expect(e.coversDay(DateTime(2026, 10, d)), isTrue);
      }
      expect(e.coversDay(DateTime(2026, 10, 15)), isFalse);
    });

    test('month and year boundaries: 31 Oct and 1 Nov, 31 Dec and 1 Jan', () {
      final a = CalendarEntry.tryParse(calRow('a', 'A', start: '2026-10-31T00:00:00.000Z', end: '2026-11-01T00:00:00.000Z'))!;
      expect((a.firstDay, a.lastDay), (DateTime(2026, 10, 31), DateTime(2026, 11, 1)));
      final b = CalendarEntry.tryParse(calRow('b', 'B', start: '2026-12-31T00:00:00.000Z', end: '2027-01-01T00:00:00.000Z'))!;
      expect((b.firstDay, b.lastDay), (DateTime(2026, 12, 31), DateTime(2027, 1, 1)));
    });

    test('a timed entry is a real instant: it lands on the device-local day of that instant', () {
      final e = CalendarEntry.tryParse(calRow('a', 'Training', allDay: false, start: '2026-10-12T22:30:00.000Z', end: '2026-10-12T23:30:00.000Z'))!;
      final l = DateTime.utc(2026, 10, 12, 22, 30).toLocal();
      expect(e.firstDay, DateTime(l.year, l.month, l.day));
      expect(e.timeLabel(), matches(RegExp(r'^\d\d:\d\d - \d\d:\d\d$')));
    });

    test('a timed entry that ends exactly at local midnight does not spill into the next day', () {
      final start = DateTime(2026, 10, 12, 22).toUtc();
      final end = DateTime(2026, 10, 13).toUtc();
      final e = CalendarEntry.tryParse(calRow('a', 'Late', allDay: false, start: start.toIso8601String(), end: end.toIso8601String()))!;
      expect(e.lastDay, DateTime(2026, 10, 12));
    });
  });

  group('circulars', () {
    test('HTML body is flattened to plain text; scripts, images and javascript: links never survive; https links are collected', () {
      final c = Circular.tryParse(circRow('c', 'T', body: '<p>Hi <b>there</b></p><script>alert(1)</script><img src="https://x.test/p.png" onerror="alert(2)"><a href="javascript:alert(3)">bad</a> <a href="https://example.test/ok">ok</a>'))!;
      expect(c.bodyText, 'Hi there\nbad ok');
      expect(c.bodyText, isNot(contains('alert')));
      expect(c.bodyText, isNot(contains('<')));
      expect(c.bodyLinks, ['https://example.test/ok']);
    });

    test('attachments: only http(s) URLs are kept', () {
      final c = Circular.tryParse(circRow('c', 'T', attachments: ['https://f.test/a.pdf', 'file:///etc/passwd', 'javascript:alert(1)', 'notaurl']))!;
      expect(c.attachmentUrls, ['https://f.test/a.pdf']);
    });

    test('teacher visibility: published only, addressed to staff, narrowed by scope', () {
      bool vis(Map<String, Object?> r) => Circular.tryParse(r)!.isForStaff(myCampusId: 'c1', myStaffId: 's1', myUserId: 'u1');
      expect(vis(circRow('a', 'A')), isTrue);
      expect(vis(circRow('a', 'A', status: 'draft')), isFalse);
      expect(vis(circRow('a', 'A', status: 'scheduled')), isFalse);
      expect(vis(circRow('a', 'A', roles: ['parent'])), isFalse);
      expect(vis(circRow('a', 'A', roles: ['parent', 'staff'])), isTrue);
      expect(vis(circRow('a', 'A', scope: 'campus', campus: 'c9')), isFalse);
      expect(vis(circRow('a', 'A', scope: 'campus', campus: 'c1')), isTrue);
      expect(vis(circRow('a', 'A', scope: 'grade')), isTrue);
      expect(vis(circRow('a', 'A', scope: 'individual', staffIds: ['other'])), isFalse);
      expect(vis(circRow('a', 'A', scope: 'individual', staffIds: ['s1'])), isTrue);
      expect(vis(circRow('a', 'A', scope: 'individual')), isFalse);
    });

    test('model keeps no recipient count, creator or student ids', () {
      final c = Circular.tryParse(circRow('c', 'T'))!;
      expect(c.audienceStaffIds, isEmpty);
      expect(c.toString(), isNot(contains('64d0000000000000000000aa')));
    });

    test('urgent / ack flags and category labels', () {
      final c = Circular.tryParse(circRow('c', 'T', urgent: true, ack: true, category: 'emergency'))!;
      expect((c.urgent, c.requiresAcknowledgment, c.categoryLabel), (true, true, 'Emergency'));
      expect(Circular.tryParse(circRow('c', 'T', category: 'zzz'))!.categoryLabel, 'Other');
    });
  });

  group('school events: whitelist and listing rule', () {
    test('detail keys ticketTypes / promoCodes / sponsors are ignored', () {
      final e = SchoolEvent.tryParse({...eventRow('e1', 'Annual Day'), 'ticketTypes': [{'name': 'VIP', 'price': 9999}], 'promoCodes': [{'code': 'SECRET'}]})!;
      expect(e.toString(), isNot(contains('SECRET')));
      expect((e.title, e.sessions.length, e.venueName), ('Annual Day', 1, 'Main Hall'));
    });

    test('listed for staff: published / cancelled / completed AND public / internal only', () {
      bool ok(String status, String vis) => SchoolEvent.tryParse(eventRow('e', 'E', status: status, visibility: vis))!.isListedForStaff;
      expect(ok('published', 'public'), isTrue);
      expect(ok('published', 'internal'), isTrue);
      expect(ok('cancelled', 'public'), isTrue);
      expect(ok('completed', 'public'), isTrue);
      expect(ok('draft', 'public'), isFalse);
      expect(ok('published', 'private'), isFalse);
      expect(ok('published', 'unlisted'), isFalse);
      expect(ok('published', 'zzz'), isFalse);
      expect(ok('zzz', 'public'), isFalse);
    });

    test('sessions are sorted and an end before the start is clamped; no sessions = no dates', () {
      final e = SchoolEvent.tryParse(eventRow('e', 'E', sessions: [session('B', '2026-10-21T09:00:00.000Z', '2026-10-21T08:00:00.000Z'), session('A', '2026-10-20T09:00:00.000Z', '2026-10-20T10:00:00.000Z')]))!;
      expect(e.sessions.map((s) => s.label), ['A', 'B']);
      expect(e.sessions.last.end, e.sessions.last.start);
      final none = SchoolEvent.tryParse(eventRow('e', 'E', sessions: []))!;
      expect((none.firstStart, none.lastEnd), (null, null));
    });

    test('description HTML is flattened and capacity is not exposed', () {
      final e = SchoolEvent.tryParse(eventRow('e', 'E', description: '<p>Hello</p><script>x()</script>'))!;
      expect(e.descriptionText, 'Hello');
      expect(e.sessions.first.toString(), isNot(contains('200')));
    });
  });

  group('safe text', () {
    test('htmlToPlainText: lists, breaks, entities; dangerous containers removed with their content', () {
      expect(htmlToPlainText('<ul><li>One</li><li>Two &amp; three</li></ul>'), '• One\n• Two & three');
      expect(htmlToPlainText('a<br>b<br/>c'), 'a\nb\nc');
      expect(htmlToPlainText('x<script>evil()</script>y<style>p{}</style>z<iframe src="u">t</iframe>'), 'xyz');
      expect(htmlToPlainText('&lt;b&gt; &#65; &#x42; &nbsp;done'), '<b> A B done');
      expect(htmlToPlainText('<img src=x onerror=alert(1)'), isNot(contains('onerror')));
      expect(htmlToPlainText('<!-- hidden -->shown'), 'shown');
    });

    test('safeExternalUri only allows http(s) with a host', () {
      expect(safeExternalUri('https://a.test/x'), isNotNull);
      expect(safeExternalUri('http://a.test'), isNotNull);
      for (final bad in ['javascript:alert(1)', 'file:///etc/passwd', 'intent://x', 'mailto:a@b.c', 'tel:123', '//a.test', '/relative', 'data:text/html,hi', '', null, 'https://']) {
        expect(safeExternalUri(bad), isNull, reason: '$bad');
      }
    });

    test('parseRichText: markdown-lite blocks, links kept only when safe, images never fetched', () {
      final blocks = parseRichText('# Title\n\nSome **bold** text with [a link](https://ok.test/x) and [bad](javascript:alert(1)).\n\n- one\n- two\n\n1. first\n2. second\n\n![tracker](https://t.test/p.png)');
      expect(blocks.map((b) => b.kind), [TextBlockKind.heading, TextBlockKind.paragraph, TextBlockKind.bullet, TextBlockKind.bullet, TextBlockKind.numbered, TextBlockKind.numbered, TextBlockKind.paragraph]);
      final p = blocks[1];
      expect(p.plain, 'Some bold text with a link and bad.');
      expect(p.runs.where((r) => r.link != null).map((r) => r.link), ['https://ok.test/x']);
      expect(blocks.last.plain, 'tracker');
      expect(blocks[4].number, 1);
    });

    test('parseRichText flattens HTML first', () {
      final blocks = parseRichText('<h1>Head</h1><p>Text <a href="https://ok.test">x</a></p><script>bad()</script>');
      expect(blocks.map((b) => b.plain).join('|'), isNot(contains('bad()')));
      expect(blocks.map((b) => b.plain).join('|'), isNot(contains('<')));
    });
  });

  group('safeguarding: the request is an allow-list', () {
    final student = StudentSummary.fromJson({'_id': '64d000000000000000000501', 'firstName': 'Zara', 'lastName': 'Malik', 'currentGrade': 'Grade 5', 'currentSection': 'A'});
    SafeguardingReport full({StudentSummary? s}) => SafeguardingReport(title: ' Short ', description: ' Seen in the corridor ', type: ConcernType.bullying, severity: ConcernSeverity.high, day: DateTime(2026, 10, 9), actionsTaken: ' Spoke to her ', student: s);

    test('with a student: exactly the allow-listed keys, nothing server-owned', () {
      final body = full(s: student).toRequestBody();
      expect(body.keys.toSet(), kSafeguardingRequestKeys);
      expect(body['title'], 'Short');
      expect(body['description'], 'Seen in the corridor');
      expect(body['reportedDate'], '2026-10-09');
      expect(body['studentId'], '64d000000000000000000501');
      expect(body['studentName'], 'Zara Malik');
      expect(body['studentGrade'], 'Grade 5 - A');
    });

    test('without a student and without immediate action: no student keys, no actionsTaken', () {
      final body = SafeguardingReport(title: 't', description: 'd', type: ConcernType.other, day: DateTime(2026, 10, 9)).toRequestBody();
      expect(body.keys.toSet(), {'title', 'description', 'type', 'severity', 'reportedDate'});
      expect(body['severity'], 'medium');
    });

    test('the allow-list never contains a server-owned field', () {
      const forbidden = {'status', 'assignedTo', 'assignedToId', 'reportedBy', 'reportedById', 'schoolSlug', 'campusId', 'caseNumber', 'confidential', 'parentNotified', 'parentNotifiedDate', 'policeInvolved', 'socialServicesInvolved', 'externalReferral', 'externalAgency', 'resolutionDate', 'resolutionNotes', 'progressNotes', 'attachments', '_id', 'createdAt', 'updatedAt'};
      expect(kSafeguardingRequestKeys.intersection(forbidden), isEmpty);
      expect(kSafeguardingRequestKeys, {'title', 'description', 'type', 'severity', 'reportedDate', 'actionsTaken', 'studentId', 'studentName', 'studentGrade'});
    });

    test('enum wires match the schema', () {
      expect(ConcernType.values.map((t) => t.wire), ['physical', 'emotional', 'sexual', 'neglect', 'bullying', 'cyberbullying', 'radicalisation', 'other']);
      expect(ConcernSeverity.values.map((t) => t.wire), ['low', 'medium', 'high', 'critical']);
    });

    test('receipt reads ONLY the case number and tolerates any body', () {
      expect(SafeguardingReceipt.fromResponse({'caseNumber': 'SC-2026-123', 'description': 'secret', 'status': 'open'}).reference, 'SC-2026-123');
      expect(SafeguardingReceipt.fromResponse({'status': 'open'}).reference, isNull);
      expect(SafeguardingReceipt.fromResponse('weird').reference, isNull);
      expect(SafeguardingReceipt.fromResponse(null).reference, isNull);
    });
  });

  group('knowledge base models', () {
    test('parse, order, module labels; rows without module / tabKey / title are skipped', () {
      final rows = parseKbArticles([
        {'module': 'hr', 'tabKey': 'a', 'title': 'A', 'tagline': 't', 'body': 'b', 'steps': ['s1', 's2'], 'order': 2},
        {'module': 'hr', 'title': 'no tab'},
        {'tabKey': 'x', 'title': 'no module', 'module': null},
      ]);
      expect(rows.length, 1);
      expect(rows.first.steps, ['s1', 's2']);
      expect((rows.first.order, rows.first.key), (2, 'hr/a'));
      expect(kbModuleLabel('hr'), 'Staff & HR');
      expect(kbModuleLabel('school_life'), 'School Life');
    });
  });

  group('avatar rules and delete result', () {
    test('type and size guards', () {
      expect(avatarProblem(fileName: 'me.JPG', size: 100), isNull);
      expect(avatarProblem(fileName: 'me.jpeg', size: 100), isNull);
      expect(avatarProblem(fileName: 'me.png', size: 100), isNull);
      expect(avatarProblem(fileName: 'me.webp', size: 100), isNull);
      expect(avatarProblem(fileName: 'me.gif', size: 100), contains('JPG, PNG or WebP'));
      expect(avatarProblem(fileName: 'me.heic', size: 100), isNotNull);
      expect(avatarProblem(fileName: 'me.pdf', size: 100), isNotNull);
      expect(avatarProblem(fileName: 'me.jpg', size: 0), isNotNull);
      expect(avatarProblem(fileName: 'me.jpg', size: kAvatarMaxBytes), isNull);
      expect(avatarProblem(fileName: 'me.jpg', size: kAvatarMaxBytes + 1), contains('10 MB'));
    });

    test('delete request result: new vs already requested', () {
      final a = DeletionRequestResult.fromJson({'requestId': 'r', 'status': 'pending', 'message': 'Sent'});
      expect((a.alreadyRequested, a.message, a.status), (false, 'Sent', 'pending'));
      final b = DeletionRequestResult.fromJson({'requestId': 'r', 'status': 'pending', 'alreadyRequested': true});
      expect((b.alreadyRequested, b.message), (true, null));
    });
  });
}
