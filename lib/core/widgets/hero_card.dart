import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../app/components/custom_text.dart';

/// Matches the mockup's `.hero-card` — navy gradient, decorative ring
/// cutout, a kicker/value/trend on the left and a progress ring on the
/// right, with up to 3 metrics along the bottom.
class HeroCard extends StatelessWidget {
  final String kicker;
  final String value;
  final String trend;
  final bool trendWarn;
  final int percent;
  final Color ringColor;
  final List<(String, String)> metrics;

  const HeroCard({
    super.key,
    required this.kicker,
    required this.value,
    required this.trend,
    this.trendWarn = false,
    required this.percent,
    this.ringColor = AppColors.amber,
    this.metrics = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.heroGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.primaryColor.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -70, top: -70,
            child: Container(
              width: 170, height: 170,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.06), width: 38)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(text: kicker.toUpperCase(), color: Colors.white.withOpacity(0.75), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        CustomText(text: value, color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        CustomText(text: trend, color: trendWarn ? const Color(0xFFFFDCA2) : const Color(0xFFC8F1DF), fontSize: 11, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  _ProgressRing(percent: percent, ringColor: ringColor),
                ],
              ),
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.14)))),
                  child: Row(
                    children: metrics.asMap().entries.map((entry) {
                      final isFirst = entry.key == 0;
                      return Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(left: 12),
                          decoration: isFirst ? null : BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withOpacity(0.12)))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomText(text: entry.value.$1, color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              CustomText(text: entry.value.$2, color: Colors.white.withOpacity(0.7), fontSize: 9, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final int percent;
  final Color ringColor;
  const _ProgressRing({required this.percent, required this.ringColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76, height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(76, 76), painter: _RingPainter(percent: percent, color: ringColor)),
          CustomText(text: '$percent%', color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int percent;
  final Color color;
  _RingPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    const strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * 3.14159265 * (percent.clamp(0, 100) / 100);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - strokeWidth / 2), -3.14159265 / 2, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.percent != percent || oldDelegate.color != color;
}
