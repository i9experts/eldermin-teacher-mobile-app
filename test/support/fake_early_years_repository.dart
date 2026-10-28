import 'package:eldermin_teacher_app/core/models/early_years/ece_models.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'package:eldermin_teacher_app/core/services/early_years_repository.dart';

/// Records every call and answers from closures. No network: the real [BaseClient] it extends is never used.
class FakeEarlyYearsRepository extends EarlyYearsRepository {
  Future<List<EceChild>> Function() children = () async => [];
  Future<List<EceDomain>> Function() domains = () async => [];
  Future<List<EceSkill>> Function(String? domainId) skills = (_) async => [];
  Future<List<String>> Function() levels = () async => kDefaultProgressionLevels;
  Future<EceProfile> Function(String id) profile = (_) async => const EceProfile();
  Future<List<EceObservation>> Function(String id) observations = (_) async => [];
  Future<List<EcePortfolioEntry>> Function(String id) portfolio = (_) async => [];
  Future<String?> Function() year = () async => '2025-26';
  Future<EceObservation> Function(Map<String, Object?> body) onQuick = (b) async => EceObservation.fromJson({'_id': 'q1', ...b});
  Future<EceObservation> Function(Map<String, Object?> body) onObservation = (b) async => EceObservation.fromJson({'_id': 'o1', ...b});
  Future<EcePortfolioEntry> Function(Map<String, Object?> body) onPortfolio = (b) async => EcePortfolioEntry.fromJson({'_id': 'p1', ...b});
  Future<EceUploaded> Function(String path, String name) onUpload = (p, n) async => EceUploaded(url: 'https://b.s3.x.amazonaws.com/s/ece-evidence/$n', key: 's/ece-evidence/$n', fileName: n);
  Future<String> Function(String key) onSigned = (k) async => 'https://signed.example/$k?sig=1';

  final calls = <String>[];
  final bodies = <Map<String, Object?>>[];

  @override
  Future<String?> currentAcademicYear({bool refresh = false}) {
    calls.add('year');
    return year();
  }

  @override
  Future<String> requireAcademicYear() async {
    final y = await year();
    if (y == null || y.isEmpty) throw const AcademicYearUnknown();
    return y;
  }

  @override
  Future<List<EceChild>> fetchChildren() {
    calls.add('children');
    return children();
  }

  @override
  Future<List<EceDomain>> fetchDomains() {
    calls.add('domains');
    return domains();
  }

  @override
  Future<List<EceSkill>> fetchSkills({String? domainId}) {
    calls.add('skills:${domainId ?? ''}');
    return skills(domainId);
  }

  @override
  Future<List<String>> fetchProgressionLevels() {
    calls.add('levels');
    return levels();
  }

  @override
  Future<EceProfile> fetchProfile(String studentId) {
    calls.add('profile:$studentId');
    return profile(studentId);
  }

  @override
  Future<List<EceObservation>> fetchObservations(String studentId) {
    calls.add('observations:$studentId');
    return observations(studentId);
  }

  @override
  Future<List<EcePortfolioEntry>> fetchPortfolio(String studentId) {
    calls.add('portfolio:$studentId');
    return portfolio(studentId);
  }

  @override
  Future<EceObservation> createQuickObservation(EceQuickObservationDraft draft) async {
    calls.add('create:quick');
    await requireAcademicYear();
    bodies.add(draft.toJson());
    return onQuick(draft.toJson());
  }

  @override
  Future<EceObservation> createObservation(EceObservationDraft draft) async {
    calls.add('create:observation');
    await requireAcademicYear();
    bodies.add(draft.toJson());
    return onObservation(draft.toJson());
  }

  @override
  Future<EcePortfolioEntry> createPortfolioEntry(EcePortfolioDraft draft) async {
    calls.add('create:portfolio');
    await requireAcademicYear();
    bodies.add(draft.toJson());
    return onPortfolio(draft.toJson());
  }

  @override
  Future<EceUploaded> uploadEvidence({required String path, required String fileName, void Function(int sent, int total)? onProgress}) {
    calls.add('upload:$fileName');
    onProgress?.call(1, 2);
    onProgress?.call(2, 2);
    return onUpload(path, fileName);
  }

  @override
  Future<String> signedUrl(String key) {
    calls.add('signed:$key');
    return onSigned(key);
  }
}

EceChild child(int n, {String first = 'Child', String grade = 'Nursery', String section = 'A', String? photo}) => EceChild.fromJson({
      '_id': 'c$n',
      'studentId': 'ST-$n',
      'firstName': '$first$n',
      'lastName': 'Khan',
      'currentGrade': grade,
      'currentSection': section,
      'dateOfBirth': '2022-03-01T00:00:00.000Z',
      if (photo != null) 'photo': photo,
    });

/// Photo picker that returns whatever the test sets.
class FakePhotoPicker implements AttachmentPicker {
  List<PickedAttachment> next = const [];
  int calls = 0;
  @override
  Future<List<PickedAttachment>> pickPhotos() async {
    calls++;
    return next;
  }

  @override
  Future<List<PickedAttachment>> pickDocuments() async => const [];
}

PickedAttachment pickedPhoto(String name, {int size = 1000}) => PickedAttachment(name: name, path: '/tmp/$name', size: size);
