import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_typography.dart';

/// Modal sheet: surface, top radius 28, drag handle, optional title, scrollable
/// content capped at 90% of the screen, safe-area padding.
class EmBottomSheet extends StatelessWidget {
  const EmBottomSheet({super.key, this.title, required this.child, this.footer});

  final String? title;
  final Widget child;

  /// Pinned below the scrolling content (e.g. buttons).
  final Widget? footer;

  static Future<T?> show<T>(BuildContext context, {String? title, required Widget child, Widget? footer}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: EmColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(EmRadius.hero))),
      builder: (_) => EmBottomSheet(title: title, footer: footer, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Container(width: 40, height: 4, decoration: const BoxDecoration(color: EmColors.border, borderRadius: EmRadius.pillAll)),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Semantics(header: true, child: Text(title!, style: EmType.heading.copyWith(color: EmColors.ink))),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 16),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 20), child: footer),
          ],
        ),
      ),
    );
  }
}
