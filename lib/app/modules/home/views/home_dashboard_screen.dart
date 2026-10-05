import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../../../components/custom_refresh_wrapper.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/home_dashboard_controller.dart';

/// Home tab body. Honest placeholder: no fabricated schedule or stats.
///
/// Pull-to-refresh already works (even over the placeholder): it re-fetches
/// `/staff-portal/me` so a changed class-teacher assignment shows up
/// immediately (Phase 4 adds the dashboard sections to the same refresh).
class HomeDashboardScreen extends GetView<HomeDashboardController> {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomRefreshWrapper(
      onRefresh: () => Get.find<AuthController>().refreshProfile(force: true),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const ComingSoonScreen(title: 'Home dashboard', embedded: true),
          ),
        ),
      ),
    );
  }
}
