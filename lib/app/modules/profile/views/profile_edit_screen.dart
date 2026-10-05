import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/profile_controller.dart';

/// Edit profile - route shell (`/profile/edit`). Honest placeholder until built.
class ProfileEditScreen extends GetView<ProfileController> {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Edit profile');
}
