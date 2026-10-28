import '../json_helpers.dart';

/// Early Years models (backend `ece/`, `src/ece/ece.controller.ts`).
///
/// Every model reads an explicit allow-list of fields and ignores everything else on purpose: the raw student and ECE documents carry
/// care, allergy, medical, guardian and support data that this app must never parse, keep or show. Ids are strings (B0_ID_TYPING.md).

const List<String> kDefaultProgressionLevels = ['Not Observed', 'Emerging', 'Developing', 'Consistent', 'Independent', 'Mastered'];

/// One child of the Early Years roster: `GET /ece/children` (ece.service.ts getChildren, select
/// `firstName lastName photo dateOfBirth currentGrade currentSection studentId`). The route returns EVERY Early Years child of the school,
/// so the app narrows it to the teacher's classes (UI-only scoping, see `early_years_scope.dart`).
class EceChild {
  final String id;
  final String studentCode;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final DateTime? dateOfBirth;
  final String grade;
  final String section;

  const EceChild({
    required this.id,
    this.studentCode = '',
    this.firstName = '',
    this.lastName = '',
    this.photoUrl,
    this.dateOfBirth,
    this.grade = '',
    this.section = '',
  });

  factory EceChild.fromJson(Map<String, dynamic> j) => EceChild(
        id: readId(j['_id'] ?? j['id']) ?? '',
        studentCode: readText(j['studentId']),
        firstName: readText(j['firstName']),
        lastName: readText(j['lastName']),
        photoUrl: readString(j['photo']),
        dateOfBirth: readDate(j['dateOfBirth']),
        grade: readText(j['currentGrade']),
        section: readText(j['currentSection']),
      );

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final s = '$f$l'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  String get classLabel => section.isEmpty ? grade : '$grade - $section';
}

/// `GET /ece/domains` row.
class EceDomain {
  final String id;
  final String name;
  final int order;
  const EceDomain({required this.id, required this.name, this.order = 0});
  factory EceDomain.fromJson(Map<String, dynamic> j) =>
      EceDomain(id: readId(j['_id'] ?? j['id']) ?? '', name: readText(j['name']), order: readInt(j['order']) ?? 0);
}

/// `GET /ece/skills` row.
class EceSkill {
  final String id;
  final String domainId;
  final String name;
  final String subDomain;
  const EceSkill({required this.id, required this.domainId, required this.name, this.subDomain = ''});
  factory EceSkill.fromJson(Map<String, dynamic> j) => EceSkill(
        id: readId(j['_id'] ?? j['id']) ?? '',
        domainId: readId(j['domainId']) ?? '',
        name: readText(j['name']),
        subDomain: readText(j['subDomainName']),
      );
}

/// `GET /ece/frameworks` row: only the level names are used (the web uses `frameworks[0].progressionLevels` too).
class EceFramework {
  final String id;
  final String name;
  final List<String> progressionLevels;
  const EceFramework({required this.id, required this.name, required this.progressionLevels});
  factory EceFramework.fromJson(Map<String, dynamic> j) {
    final levels = readStringList(j['progressionLevels']).where((e) => e.trim().isNotEmpty).toList();
    return EceFramework(id: readId(j['_id'] ?? j['id']) ?? '', name: readText(j['name']), progressionLevels: levels.isEmpty ? kDefaultProgressionLevels : levels);
  }
}

/// One domain of a child's development rollup (`domainSummaries[]`).
class EceDomainSummary {
  final String domainId;
  final String level;
  final int evidenceCount;
  final DateTime? lastObservedAt;
  const EceDomainSummary({required this.domainId, this.level = '', this.evidenceCount = 0, this.lastObservedAt});
  factory EceDomainSummary.fromJson(Map<String, dynamic> j) => EceDomainSummary(
        domainId: readId(j['domainId']) ?? '',
        level: readText(j['currentLevel']),
        evidenceCount: readInt(j['evidenceCount']) ?? 0,
        lastObservedAt: readDate(j['lastObservedAt']),
      );
}

/// `GET /ece/students/:id/profile`: a cached rollup per academic year. A never-observed child gets the empty shape (not a 404).
class EceProfile {
  final List<EceDomainSummary> domains;
  final List<String> interests;
  final List<String> schemas;
  const EceProfile({this.domains = const [], this.interests = const [], this.schemas = const []});
  factory EceProfile.fromJson(Map<String, dynamic> j) => EceProfile(
        domains: [for (final d in asJsonMapList(j['domainSummaries'])) EceDomainSummary.fromJson(d)],
        interests: readStringList(j['interests']),
        schemas: readStringList(j['schemas']),
      );
  bool get isEmpty => domains.isEmpty && interests.isEmpty && schemas.isEmpty;
}

/// Photo / media attached to an observation or portfolio entry: `{type, url, caption}`.
class EceEvidence {
  final String type;
  final String url;
  final String caption;
  const EceEvidence({required this.type, required this.url, this.caption = ''});
  factory EceEvidence.fromJson(Map<String, dynamic> j) => EceEvidence(type: readText(j['type']), url: readText(j['url']), caption: readText(j['caption']));
  bool get isPhoto => type == 'photo';
  Map<String, Object?> toJson() => {'type': type, 'url': url, if (caption.trim().isNotEmpty) 'caption': caption.trim()};

  /// The upload key behind [url] (`<school>/ece-evidence/<file>`), used to ask for a signed link; null when [url] is not one of ours.
  String? get key => eceEvidenceKey(url);
}

/// `<school>/<folder>/<file>` of a stored evidence url (a full S3 url or a bare key), else null. The signed-url route does not check the key
/// against the caller's school on `main`, so only keys read from rows the teacher already received are ever requested.
String? eceEvidenceKey(String? stored) {
  var k = (stored ?? '').trim();
  if (k.isEmpty) return null;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(k)) {
    final uri = Uri.tryParse(k);
    if (uri == null) return null;
    k = Uri.decodeComponent(uri.path);
  }
  k = k.replaceFirst(RegExp(r'^/+'), '');
  if (k.contains('..') || k.contains('\\') || k.contains('//') || k.contains('?')) return null;
  final parts = k.split('/');
  if (parts.length != 3 || parts.any((p) => p.isEmpty)) return null;
  return k;
}

/// One skill the observation was mapped to.
class EceSkillMapping {
  final String skillId;
  final String level;
  const EceSkillMapping({required this.skillId, required this.level});
  factory EceSkillMapping.fromJson(Map<String, dynamic> j) => EceSkillMapping(skillId: readId(j['skillId']) ?? '', level: readText(j['progressionLevel']));
}

/// `GET /ece/observations?studentId=` row. Staff-side view: the observer's display name is shown, the observer's id is never read.
class EceObservation {
  final String id;
  final String type;
  final String narrative;
  final String nextStep;
  final String observedBy;
  final List<EceSkillMapping> skills;
  final List<EceEvidence> evidence;
  final bool sharedWithFamily;
  final DateTime? createdAt;
  const EceObservation({
    required this.id,
    this.type = '',
    this.narrative = '',
    this.nextStep = '',
    this.observedBy = '',
    this.skills = const [],
    this.evidence = const [],
    this.sharedWithFamily = false,
    this.createdAt,
  });
  factory EceObservation.fromJson(Map<String, dynamic> j) => EceObservation(
        id: readId(j['_id'] ?? j['id']) ?? '',
        type: readText(j['observationType']),
        narrative: readText(j['narrative']),
        nextStep: readText(j['nextStep']),
        observedBy: readText(j['observedBy']),
        skills: [for (final m in asJsonMapList(j['skillMappings'])) EceSkillMapping.fromJson(m)],
        evidence: [for (final e in asJsonMapList(j['evidence'])) EceEvidence.fromJson(e)],
        sharedWithFamily: readBool(j['isSharedWithFamily']),
        createdAt: readDate(j['createdAt']),
      );
}

/// `GET /ece/students/:id/portfolio` row (ALL entries, including ones not shared with the family).
class EcePortfolioEntry {
  final String id;
  final String title;
  final String narrative;
  final String tryThisAtHome;
  final List<EceEvidence> evidence;
  final bool visibleToFamily;
  final DateTime? createdAt;
  const EcePortfolioEntry({
    required this.id,
    this.title = '',
    this.narrative = '',
    this.tryThisAtHome = '',
    this.evidence = const [],
    this.visibleToFamily = false,
    this.createdAt,
  });
  factory EcePortfolioEntry.fromJson(Map<String, dynamic> j) => EcePortfolioEntry(
        id: readId(j['_id'] ?? j['id']) ?? '',
        title: readText(j['title']),
        narrative: readText(j['narrative']),
        tryThisAtHome: readText(j['tryThisAtHome']),
        evidence: [for (final e in asJsonMapList(j['evidence'])) EceEvidence.fromJson(e)],
        visibleToFamily: readBool(j['isVisibleToFamily']),
        createdAt: readDate(j['createdAt']),
      );
}

/// `POST /upload/single/ece-evidence` -> `{success, data:{url, key, fileName, fileSize, fileType}}`.
class EceUploaded {
  final String url;
  final String key;
  final String fileName;
  const EceUploaded({required this.url, required this.key, this.fileName = ''});

  static EceUploaded? fromBody(Object? body) {
    final m = asJsonMap(body);
    final d = m['data'] is Map ? asJsonMap(m['data']) : m;
    final key = readString(d['key']);
    final url = readString(d['url']);
    if (key == null && url == null) return null;
    return EceUploaded(url: url ?? key!, key: key ?? eceEvidenceKey(url) ?? '', fileName: readText(d['fileName']));
  }
}

// ── drafts (what the forms send) ────────────────────────────────

const Map<String, String> kObservationTypes = {
  'spontaneous': 'Spontaneous',
  'planned': 'Planned activity',
  'montessori_presentation': 'Montessori presentation',
  'learning_story': 'Learning story',
};

/// `POST /ece/observations/quick` (QuickObserveDto, ece.dto.ts).
class EceQuickObservationDraft {
  final String studentId;
  final String skillId;
  final String level;
  final String narrative;
  const EceQuickObservationDraft({required this.studentId, required this.skillId, required this.level, this.narrative = ''});
  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'skillId': skillId,
        'progressionLevel': level,
        if (narrative.trim().isNotEmpty) 'narrative': narrative.trim(),
      };
}

/// `POST /ece/observations` (CreateObservationDto, ece.dto.ts). `isSharedWithFamily` is stored at creation and cannot be changed later.
class EceObservationDraft {
  final String studentId;
  final String type;
  final String narrative;
  final String nextStep;
  final List<EceSkillMapping> skills;
  final List<EceEvidence> evidence;
  final bool shareWithFamily;
  const EceObservationDraft({
    required this.studentId,
    required this.narrative,
    this.type = 'spontaneous',
    this.nextStep = '',
    this.skills = const [],
    this.evidence = const [],
    this.shareWithFamily = false,
  });
  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'observationType': type,
        'narrative': narrative.trim(),
        if (nextStep.trim().isNotEmpty) 'nextStep': nextStep.trim(),
        if (skills.isNotEmpty) 'skillMappings': [for (final s in skills) {'skillId': s.skillId, 'progressionLevel': s.level}],
        if (evidence.isNotEmpty) 'evidence': [for (final e in evidence) e.toJson()],
        'isSharedWithFamily': shareWithFamily,
      };
}

/// `POST /ece/portfolio` (CreatePortfolioEntryDto, ece.dto.ts). `isVisibleToFamily: true` makes the backend email the child's guardian.
class EcePortfolioDraft {
  final String studentId;
  final String title;
  final String narrative;
  final String tryThisAtHome;
  final List<EceEvidence> evidence;
  final bool shareWithFamily;
  const EcePortfolioDraft({
    required this.studentId,
    required this.title,
    required this.narrative,
    this.tryThisAtHome = '',
    this.evidence = const [],
    this.shareWithFamily = false,
  });
  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'title': title.trim(),
        'narrative': narrative.trim(),
        if (tryThisAtHome.trim().isNotEmpty) 'tryThisAtHome': tryThisAtHome.trim(),
        if (evidence.isNotEmpty) 'evidence': [for (final e in evidence) e.toJson()],
        'isVisibleToFamily': shareWithFamily,
      };
}
