import 'package:get/get.dart';
import 'home_badges_controller.dart';

class HomeShellController extends GetxController {
  /// Index of the Messages tab in the shell's bottom navigation.
  static const int messagesTab = 3;

  final tabIndex = 0.obs;

  void changeTab(int index) {
    tabIndex.value = index;
    // Opening the Messages tab re-reads the open threads right away instead of waiting for the next 60 s poll (no extra timer).
    if (index == messagesTab && Get.isRegistered<HomeBadgesController>()) {
      Get.find<HomeBadgesController>().refreshThreads();
    }
  }
}
