import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import '../tokens/em_motion.dart';

/// The constellation's clock: an [Animation] (0..1 over [EmMotion.ambientPeriod],
/// wrapping) that can be paused and resumed smoothly.
///
/// [active] false eases the drift to a halt over [easeTime] and then stops its
/// ticker completely (a paused screen schedules no frames); true starts the
/// ticker and eases the drift back up, so a pause or a resume is never a jump.
class EmDriftClock extends Animation<double> with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  EmDriftClock({required TickerProvider vsync, this.easeTime = const Duration(milliseconds: 250), bool active = true}) {
    _ticker = vsync.createTicker(_tick);
    this.active = active;
  }

  final Duration easeTime;
  late final Ticker _ticker;
  bool _active = false;
  double _rate = 0; // 0..1, the current share of full speed
  double _seconds = 0; // accumulated drift time
  Duration _last = Duration.zero;

  /// Whether the drift is (or is easing towards) running.
  bool get active => _active;
  set active(bool v) {
    if (v == _active) return;
    _active = v;
    if (v && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  /// True while the ticker is scheduling frames (false once paused and eased out).
  bool get ticking => _ticker.isActive;

  /// Current share of full speed (0 paused, 1 running): exposed for tests.
  double get rate => _rate;

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final ease = easeTime.inMicroseconds / 1e6;
    final target = _active ? 1.0 : 0.0;
    _rate += (target - _rate) * (dt / ease).clamp(0.0, 1.0);
    if (!_active && _rate < 0.01) {
      _rate = 0;
      _ticker.stop();
    }
    _seconds += dt * _rate;
    notifyListeners();
  }

  @override
  double get value => (_seconds / EmMotion.ambientPeriod.inSeconds) % 1.0;

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}

  void dispose() => _ticker.dispose();
}
