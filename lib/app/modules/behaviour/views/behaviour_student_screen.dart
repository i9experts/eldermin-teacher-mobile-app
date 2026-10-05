import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/behaviour_controller.dart';

/// Student behaviour - route shell (`/behaviour/student/:id`). Honest placeholder until built.
class BehaviourStudentScreen extends GetView<BehaviourController> {
  const BehaviourStudentScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Student behaviour');
}
