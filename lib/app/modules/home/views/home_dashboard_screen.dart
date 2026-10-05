import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/home_dashboard_controller.dart';

/// Home tab body. Honest placeholder: no fabricated schedule or stats.
class HomeDashboardScreen extends GetView<HomeDashboardController> {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Home dashboard', embedded: true);
}
