import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/ptm_controller.dart';

/// Meeting - route shell (`/ptm/:id`). Honest placeholder until built.
class PtmDetailScreen extends GetView<PtmController> {
  const PtmDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Meeting');
}
