import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Duration ms(int v) => Duration(milliseconds: v);

  group('EmSplashTimeline.exitDelay', () {
    test('waits for the end of the current beat', () {
      expect(EmSplashTimeline.exitDelay(ms(0)), ms(700));
      expect(EmSplashTimeline.exitDelay(ms(450)), ms(250));
      expect(EmSplashTimeline.exitDelay(ms(700)), ms(600)); // next beat B2 -> 1300
      expect(EmSplashTimeline.exitDelay(ms(1299)), ms(1));
      expect(EmSplashTimeline.exitDelay(ms(1400)), ms(100));
    });
    test('never waits once the intro is over (init slower than the motion)', () {
      expect(EmSplashTimeline.exitDelay(ms(1500)), Duration.zero);
      expect(EmSplashTimeline.exitDelay(ms(4000)), Duration.zero);
    });
    test('wait + exit stays under the hard cap after init', () {
      for (var e = 0; e < 3000; e += 7) {
        final w = EmSplashTimeline.exitDelay(ms(e));
        expect(w + EmMotion.hero, lessThanOrEqualTo(EmSplashTimeline.maxAfterInit), reason: 'init at $e ms');
      }
      // a tight cap clamps the wait
      expect(EmSplashTimeline.exitDelay(ms(0), exit: ms(1400)), ms(200));
    });
    test('windows sit inside the intro', () {
      for (final w in [
        EmSplashTimeline.charge,
        EmSplashTimeline.pulse,
        EmSplashTimeline.ripple,
        EmSplashTimeline.constellation,
        EmSplashTimeline.text
      ]) {
        expect(w.begin, greaterThanOrEqualTo(0));
        expect(w.end, lessThanOrEqualTo(EmSplashTimeline.intro.inMilliseconds));
      }
      // painter sweeps and their windows agree
      expect(EmSplashTimeline.charge.end - EmSplashTimeline.charge.begin, NodeNetworkPainter.chargeTotalMs);
      expect(EmSplashTimeline.ripple.end - EmSplashTimeline.ripple.begin, NodeNetworkPainter.rippleTotalMs);
    });
  });

  test('constellation is deterministic and drift loops without a seam', () {
    // same seed -> same painter output is covered by paint determinism; here the loop contract:
    // every node uses whole cycles per ambient loop
    expect(EmMotion.ambientPeriod.inMilliseconds % EmMotion.dashPeriod.inMilliseconds, 0);
  });
}
