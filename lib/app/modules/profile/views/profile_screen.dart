import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/profile_controller.dart';

/// Profile - route shell (`/profile`). Honest placeholder until built.
class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Profile');
}
