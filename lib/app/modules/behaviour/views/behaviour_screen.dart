import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/behaviour_controller.dart';

/// Behaviour & Tarbiyah - route shell (`/behaviour`). Honest placeholder until built.
class BehaviourScreen extends GetView<BehaviourController> {
  const BehaviourScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Behaviour & Tarbiyah');
}
