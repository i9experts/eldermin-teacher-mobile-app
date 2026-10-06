import '../json_helpers.dart';

/// Syllabus models, whitelisted from the real payloads (paths relative to eldermin-backend/src/, branch feat/staff-portal):
///  * Syllabus / Unit / Topic / SubTopic / Lesson : syllabus/schemas/syllabus.schema.ts:19-183
///  * list / one / mark / planner                 : syllabus/syllabus.controller.ts:34-37,106-114,139-149; syllabus.service.ts
/// Never parsed: tenantId, institutionId, campusId, createdBy*, approvedBy/At, assessmentBreakdown, publisherName, edition,
/// publishedToStudents/At/By (coordinator workflow), learning objectives / slo references (design side).

/// Covered / total at the granularity the SERVER uses (`computeRollup`, syllabus.service.ts:55-79): a topic WITH sub-topics counts
/// its sub-topics, a topic without counts itself.
class SyllabusProgress {
  final int total;
  final int covered;
  const SyllabusProgress(this.total, this.covered);

  /// `Math.round(covered / total * 100)`, 0 when nothing to track (service :74).
  int get percent => total > 0 ? (covered / total * 100).round() : 0;
  double get fraction => total > 0 ? covered / total : 0;
  bool get isComplete => total > 0 && covered == total;
  SyllabusProgress operator +(SyllabusProgress o) => SyllabusProgress(total + o.total, covered + o.covered);
}

class SyllabusSubTopic {
  final int no;
  final String name;

  /// 1-based week of the term it is planned for (syllabus.schema.ts:27); null = not scheduled.
  final int? plannedWeek;
  final bool isCovered;
  final DateTime? coveredDate;
  final String coveredBy;

  const SyllabusSubTopic({required this.no, this.name = '', this.plannedWeek, this.isCovered = false, this.coveredDate, this.coveredBy = ''});

  factory SyllabusSubTopic.fromJson(Map<String, dynamic> j) => SyllabusSubTopic(
        no: readInt(j['subTopicNo']) ?? 0,
        name: readText(j['subTopicName']),
        plannedWeek: readInt(j['plannedWeek']),
        isCovered: readBool(j['isCovered']),
        coveredDate: readDate(j['coveredDate']),
        coveredBy: readText(j['coveredBy']),
      );

  SyllabusSubTopic withCovered(bool v) => SyllabusSubTopic(no: no, name: name, plannedWeek: plannedWeek, isCovered: v, coveredDate: v ? coveredDate : null, coveredBy: coveredBy);
}

/// One piece of LMS content on a topic (syllabus.schema.ts:43-64). READ-ONLY in the app.
class SyllabusLesson {
  final int no;
  final String title;
  final String description;

  /// video | document | reading | link (schema :47)
  final String type;
  final String url;
  final String fileUrl;
  final String fileName;
  final DateTime? dueDate;

  const SyllabusLesson({required this.no, this.title = '', this.description = '', this.type = '', this.url = '', this.fileUrl = '', this.fileName = '', this.dueDate});

  factory SyllabusLesson.fromJson(Map<String, dynamic> j) => SyllabusLesson(
        no: readInt(j['lessonNo']) ?? 0,
        title: readText(j['title']),
        description: readText(j['description']),
        type: readText(j['type']),
        url: readText(j['url']),
        fileUrl: readText(j['fileUrl']),
        fileName: readText(j['fileName']),
        dueDate: readDate(j['dueDate']),
      );

  /// The link to open: `url` (video / reading / link) or `fileUrl` (uploaded document).
  String get link => url.isNotEmpty ? url : fileUrl;
}

class SyllabusTopic {
  final int no;
  final String name;
  final String description;
  final int estimatedLessons;
  final List<SyllabusSubTopic> subTopics;
  final List<SyllabusLesson> lessons;
  final bool isCovered;
  final DateTime? coveredDate;
  final String coveredBy;

  const SyllabusTopic({
    required this.no,
    this.name = '',
    this.description = '',
    this.estimatedLessons = 1,
    this.subTopics = const [],
    this.lessons = const [],
    this.isCovered = false,
    this.coveredDate,
    this.coveredBy = '',
  });

  factory SyllabusTopic.fromJson(Map<String, dynamic> j) => SyllabusTopic(
        no: readInt(j['topicNo']) ?? 0,
        name: readText(j['topicName']),
        description: readText(j['description']),
        estimatedLessons: readInt(j['estimatedLessons']) ?? 1,
        subTopics: asJsonMapList(j['subTopics']).map(SyllabusSubTopic.fromJson).toList(),
        lessons: asJsonMapList(j['lessons']).map(SyllabusLesson.fromJson).toList(),
        isCovered: readBool(j['isCovered']),
        coveredDate: readDate(j['coveredDate']),
        coveredBy: readText(j['coveredBy']),
      );

  bool get hasSubTopics => subTopics.isNotEmpty;

  SyllabusProgress get progress => hasSubTopics
      ? SyllabusProgress(subTopics.length, subTopics.where((s) => s.isCovered).length)
      : SyllabusProgress(1, isCovered ? 1 : 0);

  /// A topic with sub-topics is covered when ALL of them are (service :281-286); a plain topic by its own flag.
  bool get covered => hasSubTopics ? subTopics.every((s) => s.isCovered) : isCovered;

  SyllabusTopic _copy({bool? isCovered, List<SyllabusSubTopic>? subs}) => SyllabusTopic(
        no: no,
        name: name,
        description: description,
        estimatedLessons: estimatedLessons,
        subTopics: subs ?? subTopics,
        lessons: lessons,
        isCovered: isCovered ?? this.isCovered,
        coveredDate: coveredDate,
        coveredBy: coveredBy,
      );

  SyllabusTopic withCovered(bool v) => _copy(isCovered: v);

  SyllabusTopic withSubTopicCovered(int subNo, bool v) {
    final subs = [for (final s in subTopics) s.no == subNo ? s.withCovered(v) : s];
    return _copy(subs: subs, isCovered: subs.isNotEmpty && subs.every((s) => s.isCovered));
  }
}

class SyllabusUnit {
  final int no;
  final String name;
  final List<SyllabusTopic> topics;
  const SyllabusUnit({required this.no, this.name = '', this.topics = const []});

  factory SyllabusUnit.fromJson(Map<String, dynamic> j) => SyllabusUnit(
        no: readInt(j['unitNo']) ?? 0,
        name: readText(j['unitName']),
        topics: asJsonMapList(j['topics']).map(SyllabusTopic.fromJson).toList(),
      );

  SyllabusProgress get progress => topics.fold(const SyllabusProgress(0, 0), (a, t) => a + t.progress);
}

class Syllabus {
  final String id;
  final String subjectName;
  final String gradeLevel;

  /// '' = applies to every section of the grade (syllabus.schema.ts:125).
  final String sectionName;
  final String term;
  final String academicYearLabel;

  /// draft | active | approved | archived (schema :160)
  final String status;

  /// not_started | on_track | behind | completed (schema :156). `behind` is only ever set by an explicit PATCH (service :551-562).
  final String trackStatus;
  final String teacherId;
  final String teacherName;
  final int totalWeeks;
  final List<SyllabusUnit> units;
  final int serverTotal;
  final int serverCovered;
  final DateTime? lastTrackedAt;

  const Syllabus({
    required this.id,
    this.subjectName = '',
    this.gradeLevel = '',
    this.sectionName = '',
    this.term = '',
    this.academicYearLabel = '',
    this.status = 'draft',
    this.trackStatus = 'not_started',
    this.teacherId = '',
    this.teacherName = '',
    this.totalWeeks = 0,
    this.units = const [],
    this.serverTotal = 0,
    this.serverCovered = 0,
    this.lastTrackedAt,
  });

  factory Syllabus.fromJson(Map<String, dynamic> j) => Syllabus(
        id: readId(j['_id'] ?? j['id']) ?? '',
        subjectName: readText(j['subjectName']),
        gradeLevel: readText(j['gradeLevel']),
        sectionName: readText(j['sectionName']),
        term: readText(j['term']),
        academicYearLabel: readText(j['academicYearLabel']),
        status: readString(j['status']) ?? 'draft',
        trackStatus: readString(j['trackStatus']) ?? 'not_started',
        teacherId: readId(j['teacherId']) ?? '',
        teacherName: readText(j['teacherName']),
        totalWeeks: readInt(j['totalWeeks']) ?? 0,
        units: asJsonMapList(j['units']).map(SyllabusUnit.fromJson).toList(),
        serverTotal: readInt(j['totalTopics']) ?? 0,
        serverCovered: readInt(j['coveredTopics']) ?? 0,
        lastTrackedAt: readDate(j['lastTrackedAt']),
      );

  String get classLabel => sectionName.isEmpty ? gradeLevel : '$gradeLevel - $sectionName';
  String get title => '$subjectName · $classLabel';
  bool get isBehind => trackStatus == 'behind';

  /// Overall progress computed from the tree (same rule as the server's rollup); falls back to the server's cached numbers when the
  /// tree is empty but the rollup says otherwise.
  SyllabusProgress get progress {
    final fromTree = units.fold(const SyllabusProgress(0, 0), (a, u) => a + u.progress);
    if (fromTree.total == 0 && serverTotal > 0) return SyllabusProgress(serverTotal, serverCovered);
    return fromTree;
  }

  Syllabus _withUnits(List<SyllabusUnit> u) => Syllabus(
        id: id,
        subjectName: subjectName,
        gradeLevel: gradeLevel,
        sectionName: sectionName,
        term: term,
        academicYearLabel: academicYearLabel,
        status: status,
        trackStatus: trackStatus,
        teacherId: teacherId,
        teacherName: teacherName,
        totalWeeks: totalWeeks,
        units: u,
        serverTotal: serverTotal,
        serverCovered: serverCovered,
        lastTrackedAt: lastTrackedAt,
      );

  SyllabusTopic? topicAt(int unitNo, int topicNo) {
    for (final u in units) {
      if (u.no != unitNo) continue;
      for (final t in u.topics) {
        if (t.no == topicNo) return t;
      }
    }
    return null;
  }

  /// Copy with a topic's flag changed (the optimistic update; the server's answer replaces the whole syllabus).
  Syllabus withTopicCovered(int unitNo, int topicNo, bool v) => _withUnits([
        for (final u in units) u.no == unitNo ? SyllabusUnit(no: u.no, name: u.name, topics: [for (final t in u.topics) t.no == topicNo ? t.withCovered(v) : t]) : u,
      ]);

  Syllabus withSubTopicCovered(int unitNo, int topicNo, int subNo, bool v) => _withUnits([
        for (final u in units)
          u.no == unitNo ? SyllabusUnit(no: u.no, name: u.name, topics: [for (final t in u.topics) t.no == topicNo ? t.withSubTopicCovered(subNo, v) : t]) : u,
      ]);

  /// Sub-topics planned for a week EARLIER than [week] that are still not covered (derived from real `plannedWeek` data).
  List<({SyllabusUnit unit, SyllabusTopic topic, SyllabusSubTopic sub})> uncoveredBefore(int week) => [
        for (final u in units)
          for (final t in u.topics)
            for (final s in t.subTopics)
              if (!s.isCovered && s.plannedWeek != null && s.plannedWeek! < week) (unit: u, topic: t, sub: s),
      ];

  List<({SyllabusUnit unit, SyllabusTopic topic, SyllabusSubTopic sub})> plannedIn(int week) => [
        for (final u in units)
          for (final t in u.topics)
            for (final s in t.subTopics)
              if (s.plannedWeek == week) (unit: u, topic: t, sub: s),
      ];
}

/// One sub-topic of `GET /syllabus/weekly-planner` (syllabus.service.ts:314-322).
class PlannerItem {
  final int unitNo;
  final String unitName;
  final int topicNo;
  final String topicName;
  final int subTopicNo;
  final String subTopicName;
  final bool isCovered;
  const PlannerItem({required this.unitNo, this.unitName = '', required this.topicNo, this.topicName = '', required this.subTopicNo, this.subTopicName = '', this.isCovered = false});

  factory PlannerItem.fromJson(Map<String, dynamic> j) => PlannerItem(
        unitNo: readInt(j['unitNo']) ?? 0,
        unitName: readText(j['unitName']),
        topicNo: readInt(j['topicNo']) ?? 0,
        topicName: readText(j['topicName']),
        subTopicNo: readInt(j['subTopicNo']) ?? 0,
        subTopicName: readText(j['subTopicName']),
        isCovered: readBool(j['isCovered']),
      );
}

/// One syllabus of the planner response (syllabus.service.ts:325-328): the CURRENT week only (there is no week parameter).
class PlannerEntry {
  final String syllabusId;
  final String subjectName;
  final String gradeLevel;
  final String sectionName;
  final int currentWeek;
  final List<PlannerItem> items;
  const PlannerEntry({required this.syllabusId, this.subjectName = '', this.gradeLevel = '', this.sectionName = '', required this.currentWeek, this.items = const []});

  factory PlannerEntry.fromJson(Map<String, dynamic> j) => PlannerEntry(
        syllabusId: readId(j['syllabusId']) ?? '',
        subjectName: readText(j['subjectName']),
        gradeLevel: readText(j['gradeLevel']),
        sectionName: readText(j['sectionName']),
        currentWeek: readInt(j['currentWeek']) ?? 0,
        items: asJsonMapList(j['subTopics']).map(PlannerItem.fromJson).toList(),
      );

  String get classLabel => sectionName.isEmpty ? gradeLevel : '$gradeLevel - $sectionName';
}
