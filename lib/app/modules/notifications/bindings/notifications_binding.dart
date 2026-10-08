import 'package:get/get.dart';
import '../../home/bindings/home_binding.dart';
import '../../messages/bindings/messages_binding.dart';
import '../controllers/notifications_controller.dart';

class NotificationsBinding extends Bindings {
  @override
  void dependencies() {
    ensureMessagingRepository();
    ensureHomeBadges();
    Get.lazyPut<NotificationsController>(() => NotificationsController(), fenix: true);
  }
}
