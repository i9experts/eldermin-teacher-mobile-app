import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../controllers/library_controller.dart';

/// Library - route shell (`/library`). Honest placeholder until built.
class LibraryScreen extends GetView<LibraryController> {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(title: 'Library');
}
