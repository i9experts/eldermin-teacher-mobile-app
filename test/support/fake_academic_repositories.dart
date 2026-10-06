import 'dart:convert';
import 'dart:io';
import 'package:eldermin_teacher_app/core/models/academic/lesson_plan_models.dart';
import 'package:eldermin_teacher_app/core/models/academic/syllabus_models.dart';
import 'package:eldermin_teacher_app/core/models/json_helpers.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/lesson_plan_repository.dart';
import 'package:eldermin_teacher_app/core/services/lesson_plan_source_picker.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart' show PickedAttachment;
import 'package:eldermin_teacher_app/core/services/syllabus_repository.dart';

dynamic fx6(String n) => jsonDecode(File('test/fixtures/phase6a/$n.json').readAsStringSync());

const myStaff6 = '64a0000000000000000000a1';
const myProfile6 = '64a0000000000000000000b1';

LessonPlanRecord plan(String id,
        {String topic = 'Fractions',
        String status = 'draft',
        String teacherId = myStaff6,
        String subject = 'Mathematics',
        String grade = 'Grade 5',
        String section = 'A',
        String day = '2026-10-07',
        String? reason,
        String? notes,
        List<String> objectives = const ['Add fractions'],
        List<String> resources = const [],
        String homework = '',
        String method = '',
        int? mins = 40}) =>
    LessonPlanRecord.fromJson({
      '_id': id,
      'teacherId': teacherId,
      'topic': topic,
      'subject': subject,
      'gradeLevel': grade,
      'sectionName': section,
      'planDate': '${day}T00:00:00.000Z',
      'status': status,
      if (reason != null) 'rejectionReason': reason,
      if (notes != null) 'approverNotes': notes,
      'learningObjectives': objectives,
      'resources': resources,
      'homework': homework,
      'teachingMethodology': method,
      if (mins != null) 'durationMins': mins,
    });

class FakeLessonPlanRepository extends LessonPlanRepository {
  Future<List<LessonPlanRecord>> Function(List<String> ids) mine = (_) async => [];
  Future<LessonPlanRecord> Function(Map<String, Object?> body) onCreate =
      (b) async => LessonPlanRecord.fromJson({'_id': 'new1', 'teacherId': b['teacherId'], 'topic': b['topic'], 'status': b['status'], 'planDate': '${b['planDate']}T00:00:00.000Z', 'subject': b['subject'], 'gradeLevel': b['gradeLevel'], 'sectionName': b['sectionName']});
  Future<LessonPlanRecord> Function(String id, Map<String, Object?> patch) onUpdate = (id, p) async => LessonPlanRecord.fromJson({'_id': id, ...p});
  Future<LessonPlanDraft> Function(String? path, String? name, String? link) onParse = (p, n, l) async => LessonPlanDraft.fromJson(Map<String, dynamic>.from(fx6('parse_upload') as Map));

  final calls = <String>[];
  final created = <Map<String, Object?>>[];
  final patches = <({String id, Map<String, Object?> patch})>[];
  final parses = <({String? path, String? name, String? link})>[];

  @override
  Future<List<LessonPlanRecord>> fetchMine(Iterable<String> teacherIds) {
    final ids = teacherIds.toList();
    calls.add('mine:${ids.join(',')}');
    return mine(ids);
  }

  @override
  Future<LessonPlanRecord> create(Map<String, Object?> body) {
    calls.add('create');
    created.add(body);
    return onCreate(body);
  }

  @override
  Future<LessonPlanRecord> update(String id, Map<String, Object?> patch) {
    calls.add('update:$id');
    patches.add((id: id, patch: patch));
    return onUpdate(id, patch);
  }

  @override
  Future<LessonPlanDraft> parseUpload({String? path, String? fileName, String? sourceUrl, void Function(int sent, int total)? onProgress}) {
    calls.add('parse');
    parses.add((path: path, name: fileName, link: sourceUrl));
    onProgress?.call(5, 10);
    onProgress?.call(10, 10);
    return onParse(path, fileName, sourceUrl);
  }
}

class FakeSourcePicker implements LessonPlanSourcePicker {
  PickedAttachment? next;
  bool throws = false;
  @override
  Future<PickedAttachment?> pick() async {
    if (throws) throw Exception('picker');
    return next;
  }
}

List<Syllabus> allSyllabi() => (fx6('syllabi_all') as List).map((e) => Syllabus.fromJson(Map<String, dynamic>.from(e as Map))).toList();

class FakeSyllabusRepository extends SyllabusRepository {
  /// What `list(query)` answers (default: the stub's whole campus filtered like the server does for teacherId / gradeLevel).
  Future<List<Syllabus>> Function(Map<String, String> q)? onList;
  Future<Syllabus> Function(String id)? onOne;
  Future<Syllabus> Function(String id, int u, int t, int? s, bool covered)? onMark;
  Future<List<PlannerEntry>> Function(List<String> ids)? onPlanner;

  final queries = <Map<String, String>>[];
  final marks = <({String id, int u, int t, int? s, bool covered, String? by})>[];
  final plannerCalls = <List<String>>[];

  @override
  Future<List<Syllabus>> list(Map<String, String> query) {
    queries.add(query);
    if (onList != null) return onList!(query);
    return Future.value([
      for (final s in allSyllabi())
        if ((query['teacherId'] == null || s.teacherId == query['teacherId']) && (query['gradeLevel'] == null || s.gradeLevel == query['gradeLevel'])) s,
    ]);
  }

  @override
  Future<Syllabus> one(String id) => onOne != null ? onOne!(id) : Future.error(ApiException('Syllabus not found', statusCode: 404));

  /// Applies the mark to the stored copy and answers it (a faithful server for the happy path).
  final store = <String, Syllabus>{};

  Syllabus _stored(String id) => store[id] ?? allSyllabi().firstWhere((s) => s.id == id);

  @override
  Future<Syllabus> markTopic(String id, {required int unitNo, required int topicNo, required bool covered, String? coveredBy}) async {
    marks.add((id: id, u: unitNo, t: topicNo, s: null, covered: covered, by: coveredBy));
    if (onMark != null) return onMark!(id, unitNo, topicNo, null, covered);
    return store[id] = _stored(id).withTopicCovered(unitNo, topicNo, covered);
  }

  @override
  Future<Syllabus> markSubTopic(String id, {required int unitNo, required int topicNo, required int subTopicNo, required bool covered, String? coveredBy}) async {
    marks.add((id: id, u: unitNo, t: topicNo, s: subTopicNo, covered: covered, by: coveredBy));
    if (onMark != null) return onMark!(id, unitNo, topicNo, subTopicNo, covered);
    return store[id] = _stored(id).withSubTopicCovered(unitNo, topicNo, subTopicNo, covered);
  }

  @override
  Future<List<PlannerEntry>> weeklyPlanner(Iterable<String> teacherIds) {
    plannerCalls.add(teacherIds.toList());
    if (onPlanner != null) return onPlanner!(teacherIds.toList());
    return Future.value([for (final e in fx6('weekly_planner') as List) PlannerEntry.fromJson(asJsonMap(e))]);
  }
}
