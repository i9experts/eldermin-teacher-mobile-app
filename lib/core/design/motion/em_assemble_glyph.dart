import 'package:flutter/widgets.dart';
import '../tokens/em_motion.dart';
import 'logomark_geometry.dart';
import 'node_scene.dart';
import 'reduce_motion.dart';

enum EmGlyphKind { envelope, check }

/// A success glyph (an envelope or a check) built from the logomark's nodes:
/// they start scattered, glide into place, the links draw in, and the accent
/// node pulses once. Reduce motion: the finished glyph crossfades in.
class EmAssembleGlyph extends StatefulWidget {
  const EmAssembleGlyph({super.key, required this.kind, this.size = 96, this.palette = EmNetworkPalette.reversed, this.semanticLabel});
  final EmGlyphKind kind;
  final double size;
  final EmNetworkPalette palette;
  final String? semanticLabel;

  @override
  State<EmAssembleGlyph> createState() => _EmAssembleGlyphState();
}

class _EmAssembleGlyphState extends State<EmAssembleGlyph> with TickerProviderStateMixin {
  late final AnimationController _assemble = AnimationController(vsync: this, duration: EmMotion.emphasis + EmMotion.slow);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: EmMotion.emphasis);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (EmReduceMotion.of(context)) {
      _assemble.value = 1;
    } else {
      _assemble.forward().then((_) {
        if (mounted) _pulse.forward();
      });
    }
  }

  @override
  void dispose() {
    _assemble.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final envelope = widget.kind == EmGlyphKind.envelope;
    final scene = SizedBox.square(
      dimension: widget.size,
      child: EmNodeScene(
        layouts: envelope ? EmScenes.envelope : EmScenes.check,
        roles: envelope ? EmScenes.envelopeRoles : EmScenes.checkRoles,
        progress: CurvedAnimation(parent: _assemble, curve: EmMotion.emphasized),
        palette: widget.palette,
        pulse: _pulse,
        semanticLabel: widget.semanticLabel,
      ),
    );
    return EmReduceMotion.of(context) ? FadeTransition(opacity: _assemble, child: scene) : scene;
  }
}
