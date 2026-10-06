import 'package:get/get.dart';
import '../../../../core/services/assessment_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../controllers/assessments_controller.dart';
import '../controllers/marks_entry_controller.dart';
import '../controllers/quiz_controllers.dart';
import '../controllers/report_remarks_controller.dart';

void _shared() {
  if (!Get.isRegistered<AssessmentRepository>()) Get.lazyPut<AssessmentRepository>(() => AssessmentRepository(), fenix: true);
  if (!Get.isRegistered<StudentsRepository>()) Get.lazyPut<StudentsRepository>(() => StudentsRepository(), fenix: true);
  if (!Get.isRegistered<AssessmentsController>()) Get.lazyPut<AssessmentsController>(() => AssessmentsController(), fenix: true);
}

/// `/assessments`.
class AssessmentsBinding extends Bindings {
  @override
  void dependencies() => _shared();
}

/// `/assessments/:id`.
class AssessmentDetailBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<AssessmentDetailController>(() => AssessmentDetailController(id: Get.parameters['id'] ?? ''));
  }
}

/// `/assessments/:id/marks?subject=&section=`.
class AssessmentMarksBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<MarksEntryController>(() => MarksEntryController(
          assessmentId: Get.parameters['id'] ?? '',
          subject: Get.parameters['subject'] ?? '',
          initialSection: Get.parameters['section'],
        ));
  }
}

/// `/assessments/report-remarks?assessmentId=`.
class ReportRemarksBinding extends Bindings {
  @override
  void dependencies() {
    _shared();
    Get.lazyPut<ReportRemarksController>(() => ReportRemarksController(initialAssessmentId: Get.parameters['assessmentId']));
  }
}

void _quizShared() {
  _shared();
  if (!Get.isRegistered<QuizAttemptsController>()) Get.lazyPut<QuizAttemptsController>(() => QuizAttemptsController(), fenix: true);
}

/// `/assessments/quiz-attempts`.
class QuizAttemptsBinding extends Bindings {
  @override
  void dependencies() => _quizShared();
}

/// `/assessments/quiz-attempts/:id`.
class QuizAttemptDetailBinding extends Bindings {
  @override
  void dependencies() {
    _quizShared();
    Get.lazyPut<QuizAttemptDetailController>(() => QuizAttemptDetailController(id: Get.parameters['id'] ?? ''));
  }
}
