import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/forgot_password_controller.dart';

/// Forgot password - route shell (`/forgot-password`). Honest placeholder until built.
class ForgotPasswordScreen extends GetView<ForgotPasswordController> {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Forgot password');
}
