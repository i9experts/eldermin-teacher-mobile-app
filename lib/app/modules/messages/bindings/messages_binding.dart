import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/services/messaging_repository.dart';
import '../../../../core/services/students_repository.dart';
import '../../home/bindings/home_binding.dart';
import '../controllers/messages_controller.dart';
import '../controllers/new_thread_controller.dart';

/// Registers the shared [MessagingRepository] (messages, notifications and student leaves all use it).
void ensureMessagingRepository() {
  if (!Get.isRegistered<MessagingRepository>()) Get.lazyPut<MessagingRepository>(() => MessagingRepository(), fenix: true);
}

class MessagesBinding extends Bindings {
  @override
  void dependencies() {
    ensureMessagingRepository();
    Get.lazyPut<MessagesController>(() => MessagesController(), fenix: true);
  }
}

/// `/messages/:threadId` (the screen creates its own tagged ChatController).
class MessageThreadBinding extends Bindings {
  @override
  void dependencies() {
    ensureMessagingRepository();
    ensureHomeBadges();
  }
}

/// `/messages/new`: optionally a [StudentSummary] in `arguments` preselects the student (Student 360 -> "Message guardian").
class NewThreadBinding extends Bindings {
  @override
  void dependencies() {
    ensureMessagingRepository();
    ensureHomeBadges();
    if (!Get.isRegistered<StudentsRepository>()) Get.lazyPut<StudentsRepository>(() => StudentsRepository(), fenix: true);
    final arg = Get.arguments;
    Get.lazyPut<NewThreadController>(() => NewThreadController(initialStudent: arg is StudentSummary ? arg : null));
  }
}
