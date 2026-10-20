import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';

/// One quiet context line under the app bar ("Grade 5 - A · Tuesday, 20 October"). Replaces the legacy big in-body title that repeated the app
/// bar's own title.
class EmCaptionLine extends StatelessWidget {
  const EmCaptionLine(this.text, {super.key, this.maxLines = 2});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.block),
        child: Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.textSecondary)),
      );
}
