import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/behaviour_controller.dart';

/// Log behaviour - route shell (`/behaviour/new`). Honest placeholder until built.
class BehaviourNewScreen extends GetView<BehaviourController> {
  const BehaviourNewScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Log behaviour');
}
