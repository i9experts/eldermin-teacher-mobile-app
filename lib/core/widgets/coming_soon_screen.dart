import 'package:flutter/material.dart';
import '../../app/components/custom_text.dart';
import 'app_widgets.dart';

/// Used only for screens genuinely not built yet - never a substitute
/// for a real screen with fabricated data. Every entry point in the app
/// either shows real data or honestly says "not built yet", never
/// something in between.
///
/// Copied from the parent app. [embedded] renders just the body (no
/// Scaffold/AppBar) for use inside a HomeShell tab.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final bool embedded;
  const ComingSoonScreen({super.key, required this.title, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = AppEmptyView(
      icon: Icons.construction_rounded,
      title: embedded ? '$title is still being built' : 'This screen is still being built',
      subtitle: "It'll be wired up to real data in an upcoming update.",
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: title,
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: body,
    );
  }
}
