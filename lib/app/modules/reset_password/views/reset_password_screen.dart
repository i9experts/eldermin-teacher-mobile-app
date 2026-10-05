import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/reset_password_controller.dart';

/// Reset password - route shell (`/reset-password`). Honest placeholder until built.
class ResetPasswordScreen extends GetView<ResetPasswordController> {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Reset password');
}
