import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/delete_account_controller.dart';

/// Delete account - route shell (`/delete-account`). Honest placeholder until built.
class DeleteAccountScreen extends GetView<DeleteAccountController> {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Delete account');
}
