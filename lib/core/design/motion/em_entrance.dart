import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../tokens/em_motion.dart';
import 'logo_handoff.dart';
import 'reduce_motion.dart';

/// Timeline of a screen entrance: the card rises (`emphasis`), then its items
/// follow [EmMotion.stagger] apart (MOTION_SPEC.md 3.3).
class EmEntrancePlan {
  EmEntrancePlan._();
  static const int maxItems = 6;
  static const Duration itemDuration = Duration(milliseconds: 240);
  static final Duration total = EmMotion.emphasis + EmMotion.stagger * (maxItems - 1) + const Duration(milliseconds: 60);

  static double _at(Duration d) => d.inMicroseconds / total.inMicroseconds;

  /// Window of the card itself.
  static Interval get card => Interval(0, _at(EmMotion.emphasis), curve: EmMotion.enter);

  /// Window of item [index] (0-based, capped at [maxItems] - 1).
  static Interval item(int index) {
    final start = EmMotion.stagger * math.min(index, maxItems - 1) + const Duration(milliseconds: 120);
    return Interval(_at(start), _at(start + itemDuration), curve: EmMotion.enter);
  }
}

/// Provides the entrance animation to [EmStagger] items below it.
class EmEntrance extends InheritedWidget {
  const EmEntrance({super.key, required this.animation, required super.child});
  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<EmEntrance>()?.animation;

  @override
  bool updateShouldNotify(EmEntrance old) => old.animation != animation;
}

/// Fades and slides [child] in as part of the surrounding [EmEntrance]
/// (item [index] of the stagger). Without an entrance above it, it is just [child].
class EmStagger extends StatelessWidget {
  const EmStagger({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parent = EmEntrance.maybeOf(context);
    // always the same wrapper once there is an entrance: swapping it out at the end would remount
    // the child (and drop a field the user is already typing in)
    if (parent == null) return child;
    final a = CurvedAnimation(parent: parent, curve: EmEntrancePlan.item(index));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: child),
    );
  }
}

/// Owns an entrance controller: starts it when the screen is actually visible
/// (not hidden under the splash overlay), and not at all with reduce motion.
class EmEntranceHost extends StatefulWidget {
  const EmEntranceHost({super.key, required this.builder});

  /// Builds the screen from the entrance animation (0 -> 1).
  final Widget Function(BuildContext context, Animation<double> entrance) builder;

  @override
  State<EmEntranceHost> createState() => _EmEntranceHostState();
}

class _EmEntranceHostState extends State<EmEntranceHost> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: EmEntrancePlan.total);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (EmReduceMotion.of(context)) {
      _c.value = 1;
    } else if (EmLogoHandoff.overlay.value && !EmLogoHandoff.flying.value) {
      // the splash is still covering this screen: play the entrance as its navy lifts
      // (or as soon as the overlay is gone, whichever comes first)
      void go() {
        if (!EmLogoHandoff.flying.value && EmLogoHandoff.overlay.value) return;
        _detach?.call();
        _detach = null;
        if (mounted) _c.forward();
      }

      EmLogoHandoff.flying.addListener(go);
      EmLogoHandoff.overlay.addListener(go);
      _detach = () {
        EmLogoHandoff.flying.removeListener(go);
        EmLogoHandoff.overlay.removeListener(go);
      };
    } else {
      _c.forward();
    }
  }

  VoidCallback? _detach;

  @override
  void dispose() {
    _detach?.call();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _c);
}

/// Gentle sideways shake of [child] whenever [trigger] changes (an error).
/// Reduce motion: no shake.
class EmShake extends StatefulWidget {
  const EmShake({super.key, required this.trigger, required this.child});
  final ValueListenable<int> trigger;
  final Widget child;

  @override
  State<EmShake> createState() => _EmShakeState();
}

class _EmShakeState extends State<EmShake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  /// Current offset in dp: exposed for tests.
  double get offset => _offsetAt(_c.value);

  static double _offsetAt(double t) => math.sin(t * math.pi * 6) * (1 - t) * EmMotion.shakeDistance;

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_shake);
  }

  @override
  void didUpdateWidget(EmShake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      old.trigger.removeListener(_shake);
      widget.trigger.addListener(_shake);
    }
  }

  void _shake() {
    if (!mounted || EmReduceMotion.of(context)) return;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_shake);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => Transform.translate(offset: Offset(_c.isAnimating ? offset : 0, 0), child: child),
    );
  }
}
