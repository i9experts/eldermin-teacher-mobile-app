import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/ptm_controller.dart';

/// Parent meetings - route shell (`/ptm`). Honest placeholder until built.
class PtmScreen extends GetView<PtmController> {
  const PtmScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Parent meetings');
}
