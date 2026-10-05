import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/early_years_controller.dart';

/// Early Years - route shell (`/early-years`). Honest placeholder until built.
class EarlyYearsScreen extends GetView<EarlyYearsController> {
  const EarlyYearsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Early Years');
}
