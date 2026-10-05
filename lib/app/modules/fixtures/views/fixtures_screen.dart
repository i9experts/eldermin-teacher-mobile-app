import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/fixtures_controller.dart';

/// Substitutions - route shell (`/fixtures`). Honest placeholder until built.
class FixturesScreen extends GetView<FixturesController> {
  const FixturesScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Substitutions');
}
