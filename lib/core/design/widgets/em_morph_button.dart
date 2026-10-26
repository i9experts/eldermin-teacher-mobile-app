import 'package:flutter/material.dart';
import '../motion/reduce_motion.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_motion.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_typography.dart';

enum EmMorphPhase { idle, loading, success }

/// The accent submit button of the auth card. Press -> it morphs into a
/// circular spinner while [phase] is loading; on success the spinner becomes a
/// drawn check; going back to idle (an error) expands it again.
/// Reduce motion: the label is swapped in place (no width morph, the check
/// appears at once).
class EmMorphButton extends StatelessWidget {
  const EmMorphButton(
      {super.key,
      required this.label,
      required this.phase,
      required this.onPressed,
      this.loadingLabel = 'Signing in...',
      this.successLabel = 'Signed in'});

  final String label;
  final String loadingLabel;
  final String successLabel;
  final EmMorphPhase phase;
  final VoidCallback? onPressed;

  static const double height = 52;

  /// Fill and content colours. The content is `ink` (7.1:1 on the accent), NOT the navy `onAccent`
  /// (4.43:1: icons / large text only), so the 16 px label passes AA as normal text.
  static const Color fill = EmColors.accent;
  static const Color content = EmColors.ink;

  @override
  Widget build(BuildContext context) {
    final reduced = EmReduceMotion.of(context);
    final busy = phase != EmMorphPhase.idle;
    final spoken = switch (phase) {
      EmMorphPhase.idle => label,
      EmMorphPhase.loading => loadingLabel,
      EmMorphPhase.success => successLabel,
    };
    return Semantics(
      button: true,
      label: spoken,
      enabled: !busy && onPressed != null,
      liveRegion: busy,
      excludeSemantics: true,
      onTap: busy ? null : onPressed,
      child: LayoutBuilder(
        builder: (context, box) {
          final full = box.maxWidth.isFinite ? box.maxWidth : 280.0;
          return Align(
            child: AnimatedContainer(
              duration: reduced ? Duration.zero : EmMotion.normal,
              curve: Curves.easeInOutCubic,
              width: busy ? height : full,
              height: height,
              decoration: const BoxDecoration(color: fill, borderRadius: EmRadius.controlAll),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: EmRadius.controlAll,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: busy ? null : onPressed,
                  child: Center(child: _content(reduced)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _content(bool reduced) {
    final child = switch (phase) {
      EmMorphPhase.idle => Text(label,
          key: const ValueKey('idle'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: EmType.bodyLarge.copyWith(color: content, fontWeight: FontWeight.w700)),
      EmMorphPhase.loading => const SizedBox(
          key: ValueKey('loading'), width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: content)),
      EmMorphPhase.success => _Check(key: const ValueKey('success'), animate: !reduced),
    };
    return AnimatedSwitcher(duration: reduced ? EmMotion.crossfade : EmMotion.fast, child: child);
  }
}

/// A check mark that draws itself (stroke trimmed 0 -> 1).
class _Check extends StatelessWidget {
  const _Check({super.key, required this.animate});
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: EmMotion.normal,
      curve: Curves.easeOut,
      builder: (context, t, _) => CustomPaint(size: const Size(24, 24), painter: CheckPainter(t)),
    );
  }
}

/// The drawn check. [progress] 0..1 along the two strokes: exposed for tests.
class CheckPainter extends CustomPainter {
  const CheckPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width * 0.14, size.height * 0.54)
      ..lineTo(size.width * 0.40, size.height * 0.78)
      ..lineTo(size.width * 0.86, size.height * 0.26);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = EmMorphButton.content;
    for (final m in p.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(CheckPainter old) => old.progress != progress;
}
