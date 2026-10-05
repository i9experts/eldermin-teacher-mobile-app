import 'package:get/get.dart';

class HomeShellController extends GetxController {
  /// Index of the Messages tab in the shell's bottom navigation.
  static const int messagesTab = 3;

  final tabIndex = 0.obs;

  void changeTab(int index) => tabIndex.value = index;
}
