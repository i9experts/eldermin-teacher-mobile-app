import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/homework_controller.dart';

/// New homework - route shell (`/homework/new`). Honest placeholder until built.
class HomeworkNewScreen extends GetView<HomeworkController> {
  const HomeworkNewScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'New homework');
}
