import 'package:flutter/material.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';
import 'em_tone.dart';

/// Inline notice: tone container + dark text + a leading icon (so the meaning never relies on colour alone), optional trailing action.
/// Replaces the legacy ad-hoc banners (`ErrorBanner`, attendance `_Banner`, ...).
class EmInfoBanner extends StatelessWidget {
  const EmInfoBanner({super.key, required this.text, this.tone = EmTone.info, this.icon, this.actionLabel, this.onAction, this.actionKey});

  final String text;
  final EmTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  static IconData _defaultIcon(EmTone t) => switch (t) {
        EmTone.error => Icons.error_outline_rounded,
        EmTone.warning => Icons.warning_amber_rounded,
        EmTone.success => Icons.check_circle_outline_rounded,
        EmTone.leave => Icons.event_available_outlined,
        EmTone.neutral => Icons.info_outline_rounded,
        EmTone.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: Semantics(
        container: true,
        liveRegion: tone == EmTone.error,
        child: DecoratedBox(
          decoration: BoxDecoration(color: tone.background, borderRadius: EmRadius.mdAll),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s12, EmSpacing.s12, EmSpacing.s8, EmSpacing.s12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ExcludeSemantics(child: Icon(icon ?? _defaultIcon(tone), size: 20, color: tone.foreground)),
              const SizedBox(width: EmSpacing.s8),
              Expanded(child: Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: Text(text, style: EmType.body.copyWith(color: tone.foreground, fontWeight: FontWeight.w500)))),
              if (actionLabel != null)
                TextButton(key: actionKey, onPressed: onAction, style: TextButton.styleFrom(foregroundColor: tone.foreground), child: Text(actionLabel!, style: EmType.label.copyWith(color: tone.foreground))),
            ]),
          ),
        ),
      ),
    );
  }
}
