// ignore_for_file: invalid_use_of_protected_member
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/early_years_child_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/evidence_photos.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/ey_submit.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/observation_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/portfolio_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/quick_observe_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/early_years/ece_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_early_years_repository.dart';

const nurseryA = {'gradeLevel': 'Nursery', 'sectionName': 'A', 'subjectName': 'All'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeEarlyYearsRepository repo;
  late FakePhotoPicker picker;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeEarlyYearsRepository();
    picker = FakePhotoPicker();
    repo.domains = () async => const [EceDomain(id: 'd1', name: 'Physical', order: 1), EceDomain(id: 'd2', name: 'Language', order: 2)];
    repo.skills = (_) async => const [
          EceSkill(id: 's1', domainId: 'd1', name: 'Pencil Control'),
          EceSkill(id: 's2', domainId: 'd1', name: 'Balance'),
          EceSkill(id: 's3', domainId: 'd2', name: 'Vocabulary'),
        ];
  });
  tearDown(Get.reset);

  Future<({dynamic auth, dynamic perms})> session({List<String>? permissions}) async {
    final h = await signedIn(permissions: permissions);
    h.api.assignments = const [nurseryA];
    await h.auth.refreshProfile(force: true);
    return (auth: h.auth, perms: h.perms);
  }

  group('EvidencePhotos', () {
    test('picks are uploaded one by one to the evidence folder and become photo evidence rows', () async {
      picker.next = [pickedPhoto('a.jpg'), pickedPhoto('b.PNG')];
      final p = EvidencePhotos(repo: repo, picker: picker);
      await p.pick();
      expect(repo.calls.where((x) => x.startsWith('upload:')), ['upload:a.jpg', 'upload:b.PNG']);
      expect(p.photos.every((x) => x.status == EyPhotoStatus.done), isTrue);
      expect(p.busy, isFalse);
      expect(p.evidence.map((e) => e.type), ['photo', 'photo']);
      expect(p.evidence.first.url, contains('ece-evidence/a.jpg'));
    });

    test('wrong type, too big and too many are refused with a plain message and never uploaded', () async {
      final p = EvidencePhotos(repo: repo, picker: picker);
      picker.next = [pickedPhoto('doc.pdf'), pickedPhoto('clip.mp4'), pickedPhoto('huge.jpg', size: EvidencePhotos.maxBytes + 1)];
      await p.pick();
      expect(p.photos, isEmpty);
      expect(p.notice.value, isNotNull);
      expect(repo.calls.where((x) => x.startsWith('upload:')), isEmpty);

      picker.next = [for (var i = 0; i < 8; i++) pickedPhoto('p$i.jpg')];
      await p.pick();
      expect(p.photos, hasLength(EvidencePhotos.maxPhotos));
      expect(p.notice.value, contains('up to ${EvidencePhotos.maxPhotos}'));
    });

    test('a failed upload is kept for Retry; Retry succeeds; Remove drops it', () async {
      var fail = true;
      repo.onUpload = (path, name) async {
        if (fail) throw ApiException('The server had a problem', statusCode: 500);
        return EceUploaded(url: 'https://b/s/ece-evidence/$name', key: 's/ece-evidence/$name', fileName: name);
      };
      picker.next = [pickedPhoto('a.jpg')];
      final p = EvidencePhotos(repo: repo, picker: picker);
      await p.pick();
      expect(p.hasFailed, isTrue);
      expect(p.evidence, isEmpty);
      fail = false;
      await p.retry(p.photos.single.id);
      expect(p.hasFailed, isFalse);
      expect(p.evidence, hasLength(1));
      p.remove(p.photos.single.id);
      expect(p.photos, isEmpty);
    });

    test('storage not configured (503): flagged unavailable so the form can say so, photo stays failed', () async {
      repo.onUpload = (path, name) async => throw ApiException('File uploads are not available on this server (storage is not configured).', statusCode: 503);
      picker.next = [pickedPhoto('a.jpg')];
      final p = EvidencePhotos(repo: repo, picker: picker);
      await p.pick();
      expect(p.unavailable.value, isTrue);
      expect(p.photos.single.status, EyPhotoStatus.failed);
      p.remove(p.photos.single.id);
      expect(p.unavailable.value, isFalse);
    });

    test('403 on upload: the photo stays failed with a readable ActionFailure message, uploads are not flagged unavailable', () async {
      repo.onUpload = (path, name) async => throw ApiException('Forbidden resource', statusCode: 403);
      picker.next = [pickedPhoto('a.jpg')];
      final p = EvidencePhotos(repo: repo, picker: picker);
      await p.pick();
      expect(p.unavailable.value, isFalse);
      expect(p.photos.single.status, EyPhotoStatus.failed);
      expect(p.photos.single.error, startsWith("You can't upload this photo."));
    });

    test('a picker that throws is a message, not a crash', () async {
      final p = EvidencePhotos(repo: repo, picker: _ThrowingPicker());
      await p.pick();
      expect(p.notice.value, isNotNull);
      expect(p.photos, isEmpty);
    });
  });

  group('quick observation', () {
    Future<QuickObserveController> make({EceChild? initial, List<String>? permissions}) async {
      final s = await session(permissions: permissions);
      return QuickObserveController(childId: (initial ?? child(1)).id, initial: initial ?? child(1), repository: repo, auth: s.auth, permissions: s.perms);
    }

    test('pickers load; choosing another learning area clears the skill', () async {
      final c = await make();
      await c.loadRefs();
      expect(c.refs.value.status, SectionStatus.data);
      expect(c.refs.value.data!.skillsOf('d1').map((s) => s.id), ['s1', 's2']);
      c.setDomain('d1');
      c.setSkill('s1');
      c.setDomain('d2');
      expect(c.skillId.value, isNull);
      expect(c.refs.value.data!.skillsOf(null), isEmpty);
    });

    test('skill and level are required; nothing is sent until both are chosen', () async {
      final c = await make();
      await c.loadRefs();
      final r = await c.submit();
      expect(r, isA<EyInvalid<EceObservation>>());
      expect(c.errors.keys, containsAll(['skill', 'level']));
      expect(repo.calls.where((x) => x.startsWith('create')), isEmpty);
    });

    test('saves exactly {studentId, skillId, progressionLevel, narrative?}, shows on the child page, and ignores a second tap while saving', () async {
      final c = await make();
      await c.loadRefs();
      c.setDomain('d1');
      c.setSkill('s1');
      c.setLevel('Emerging');
      c.narrativeC.text = '  Held the pencil well  ';
      final first = c.submit();
      final second = await c.submit();
      expect(second, isA<EyIgnored<EceObservation>>());
      final r = await first;
      expect(r, isA<EySaved<EceObservation>>());
      expect(repo.bodies.single, {'studentId': 'c1', 'skillId': 's1', 'progressionLevel': 'Emerging', 'narrative': 'Held the pencil well'});
      expect(repo.calls.where((x) => x == 'create:quick'), hasLength(1));
    });

    test('a server failure keeps the form and says what happened', () async {
      repo.onQuick = (b) async => throw ApiException('The server had a problem', statusCode: 500);
      final c = await make();
      await c.loadRefs();
      c.setDomain('d1');
      c.setSkill('s1');
      c.setLevel('Emerging');
      final r = await c.submit();
      expect(r, isA<EyFailed<EceObservation>>());
      expect(c.failure.value, isNotNull);
      expect(c.saving.value, isFalse);
      expect(c.isDirty, isTrue);
    });

    test('the school year cannot be worked out: nothing is saved and the message says why', () async {
      repo.year = () async => null;
      final c = await make();
      await c.loadRefs();
      c.setDomain('d1');
      c.setSkill('s1');
      c.setLevel('Emerging');
      final r = await c.submit();
      expect(r, isA<EyFailed<EceObservation>>());
      expect(c.failure.value!.message, contains('academic year'));
      expect(repo.bodies, isEmpty);
    });

    test('blocked without early-years:manage, and for a child outside my classes (nothing requested)', () async {
      final noManage = await make(permissions: const ['early-years:view']);
      expect(noManage.blocked, isNotNull);
      expect(await noManage.submit(), isA<EyInvalid<EceObservation>>());
      final other = await make(initial: child(7, grade: 'KG-2', section: 'B'));
      expect(other.blocked, contains("isn't one of the children in your classes"));
      expect(await other.submit(), isA<EyInvalid<EceObservation>>());
      await other.loadRefs();
      expect(repo.calls.where((x) => x.startsWith('domains') || x.startsWith('skills') || x.startsWith('create')), isEmpty);
    });

    test('no skills set up: an honest empty state', () async {
      repo.skills = (_) async => const [];
      final c = await make();
      await c.loadRefs();
      expect(c.refs.value.status, SectionStatus.empty);
    });
  });

  group('full observation', () {
    Future<ObservationFormController> make({EceChild? initial, List<String>? permissions}) async {
      final s = await session(permissions: permissions);
      return ObservationFormController(childId: (initial ?? child(1)).id, initial: initial ?? child(1), repository: repo, auth: s.auth, permissions: s.perms, picker: picker);
    }

    test('narrative is required; the share switch starts OFF; the default body is private', () async {
      final c = await make();
      expect(c.share.value, isFalse);
      expect(c.needsShareConfirm, isFalse);
      expect(await c.submit(), isA<EyInvalid<EceObservation>>());
      expect(c.errors['narrative'], isNotNull);
      c.narrativeC.text = 'Built a tower of six blocks';
      expect(await c.submit(), isA<EySaved<EceObservation>>());
      expect(repo.bodies.single, {'studentId': 'c1', 'observationType': 'spontaneous', 'narrative': 'Built a tower of six blocks', 'isSharedWithFamily': false});
    });

    test('a skill needs its level and a level needs its skill', () async {
      final c = await make();
      await c.loadRefs();
      c.narrativeC.text = 'n';
      c.setDomain('d1');
      c.setSkill('s1');
      expect((await c.submit()), isA<EyInvalid<EceObservation>>());
      expect(c.errors['skill'], contains('level'));
      c.clearSkill();
      c.setLevel('Emerging');
      expect(await c.submit(), isA<EyInvalid<EceObservation>>());
      expect(c.errors['skill'], contains('skill'));
      c.setDomain('d1');
      c.setSkill('s1');
      expect(await c.submit(), isA<EySaved<EceObservation>>());
      expect(repo.bodies.single['skillMappings'], [{'skillId': 's1', 'progressionLevel': 'Emerging'}]);
    });

    test('share ON needs the confirm and sends isSharedWithFamily true; the type and next step go along', () async {
      final c = await make();
      c.narrativeC.text = 'n';
      c.nextStepC.text = ' Count them ';
      c.setType('learning_story');
      c.setShare(true);
      expect(c.needsShareConfirm, isTrue);
      expect(ObservationFormController.shareConfirmMessage, contains('Parents will be able to see'));
      await c.submit();
      final b = repo.bodies.single;
      expect(b['isSharedWithFamily'], isTrue);
      expect(b['observationType'], 'learning_story');
      expect(b['nextStep'], 'Count them');
    });

    test('photos: saving waits for uploads and refuses a failed one; finished photos become evidence', () async {
      final c = await make();
      c.narrativeC.text = 'n';
      repo.onUpload = (p, n) async => throw ApiException('x', statusCode: 500);
      picker.next = [pickedPhoto('a.jpg')];
      await c.photos.pick();
      expect(await c.submit(), isA<EyInvalid<EceObservation>>());
      expect(c.errors['photos'], contains('Retry or remove'));
      c.photos.remove(c.photos.photos.single.id);
      repo.onUpload = (p, n) async => EceUploaded(url: 'https://b/s/ece-evidence/$n', key: 's/ece-evidence/$n');
      picker.next = [pickedPhoto('ok.jpg')];
      await c.photos.pick();
      expect(await c.submit(), isA<EySaved<EceObservation>>());
      expect(repo.bodies.single['evidence'], [{'type': 'photo', 'url': 'https://b/s/ece-evidence/ok.jpg'}]);
    });

    test('dirty tracking drives the discard prompt', () async {
      final c = await make();
      expect(c.isDirty, isFalse);
      c.nextStepC.text = 'x';
      expect(c.isDirty, isTrue);
    });

    test('a created observation is added to the child page that is open behind', () async {
      final s = await session();
      repo.observations = (_) async => [];
      final page = Get.put(EarlyYearsChildController(childId: 'c1', initial: child(1), repository: repo, auth: s.auth, permissions: s.perms));
      await page.load();
      final c = ObservationFormController(childId: 'c1', initial: child(1), repository: repo, auth: s.auth, permissions: s.perms, picker: picker);
      c.narrativeC.text = 'Fresh';
      await c.submit();
      expect(page.observationsState.value.data!.single.narrative, 'Fresh');
    });
  });

  group('portfolio entry', () {
    Future<PortfolioFormController> make({EceChild? initial, List<String>? permissions}) async {
      final s = await session(permissions: permissions);
      return PortfolioFormController(childId: (initial ?? child(1)).id, initial: initial ?? child(1), repository: repo, auth: s.auth, permissions: s.perms, picker: picker);
    }

    test('title and what happened are required; PRIVATE by default', () async {
      final c = await make();
      expect(c.share.value, isFalse);
      expect(await c.submit(), isA<EyInvalid<EcePortfolioEntry>>());
      expect(c.errors.keys, containsAll(['title', 'narrative']));
      c.titleC.text = ' Painting ';
      c.narrativeC.text = ' Mixed colours ';
      expect(await c.submit(), isA<EySaved<EcePortfolioEntry>>());
      expect(repo.bodies.single, {'studentId': 'c1', 'title': 'Painting', 'narrative': 'Mixed colours', 'isVisibleToFamily': false});
    });

    test('sharing says the guardian will be emailed, and is sent only when switched on', () async {
      expect(PortfolioFormController.shareConfirmMessage, contains('guardian will be emailed'));
      final c = await make();
      c.titleC.text = 't';
      c.narrativeC.text = 'n';
      c.tryHomeC.text = 'Paint with water';
      c.setShare(true);
      expect(c.needsShareConfirm, isTrue);
      await c.submit();
      expect(repo.bodies.single['isVisibleToFamily'], isTrue);
      expect(repo.bodies.single['tryThisAtHome'], 'Paint with water');
    });

    test('a failure keeps the entry; blocked for no manage permission and for a child outside my classes', () async {
      repo.onPortfolio = (b) async => throw ApiException('offline', statusCode: null);
      final c = await make();
      c.titleC.text = 't';
      c.narrativeC.text = 'n';
      expect(await c.submit(), isA<EyFailed<EcePortfolioEntry>>());
      expect(c.failure.value!.message, contains('Your changes are kept'));
      expect((await make(permissions: const ['early-years:view'])).blocked, isNotNull);
      expect((await make(initial: child(9, grade: 'KG-2', section: 'B'))).blocked, isNotNull);
    });

    test('the new entry shows on the child page behind', () async {
      final s = await session();
      final page = Get.put(EarlyYearsChildController(childId: 'c1', initial: child(1), repository: repo, auth: s.auth, permissions: s.perms));
      await page.load();
      final c = PortfolioFormController(childId: 'c1', initial: child(1), repository: repo, auth: s.auth, permissions: s.perms, picker: picker);
      c.titleC.text = 'New';
      c.narrativeC.text = 'n';
      await c.submit();
      expect(page.portfolioState.value.data!.single.title, 'New');
    });
  });
}

class _ThrowingPicker extends FakePhotoPicker {
  @override
  Future<List<PickedAttachment>> pickPhotos() async => throw Exception('no gallery');
}
