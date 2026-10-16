import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';

/// Avatar + two-line greeting (muted line, bold name) + optional trailing
/// widget (usually an [EmIconCircleButton] bell).
class EmGreetingHeader extends StatelessWidget {
  const EmGreetingHeader({
    super.key,
    required this.name,
    this.greeting = 'Good morning',
    this.avatar,
    this.trailing,
    this.onTap,
  });

  final String name;
  final String greeting;
  final Widget? avatar;
  final Widget? trailing;

  /// Tapping the avatar + text area (e.g. open profile).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final who = Row(
      children: [
        if (avatar != null) ...[avatar!, const SizedBox(width: EmSpacing.s12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(greeting, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.textSecondary)),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.title.copyWith(color: EmColors.ink, fontSize: 20)),
            ],
          ),
        ),
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: '$greeting, $name',
              button: onTap != null,
              excludeSemantics: true,
              onTap: onTap,
              child: onTap == null
                  ? who
                  : InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: who)),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: EmSpacing.s12), trailing!],
        ],
      ),
    );
  }
}

/// 52dp circular avatar: network image when [imageUrl] loads, else initials.
class EmAvatar extends StatelessWidget {
  const EmAvatar({super.key, required this.initials, this.imageUrl, this.size = 52});
  final String initials;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(initials, style: EmType.label.copyWith(color: EmColors.primaryDark, fontSize: size * 0.3)),
    );
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: EmColors.primaryContainer),
        child: (imageUrl == null || imageUrl!.isEmpty)
            ? fallback
            : Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }
}
