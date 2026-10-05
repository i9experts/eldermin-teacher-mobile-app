import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../app/components/custom_text.dart';

/// Matches the mockup's `.bar-chart` — one bar per category (e.g. a
/// month), height proportional to a 0-100 value.
class AppBarChart extends StatelessWidget {
  final List<(String label, double value)> data;
  const AppBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final h = (d.$2.clamp(0, 100) / 100) * 80;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: h,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.sky, AppColors.blue], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5), bottom: Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  CustomText(text: d.$1, fontSize: 8, color: AppColors.faint, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Matches the mockup's `lineChart()` — a smoothed line + gradient area
/// fill over 0-100 values, one point per label (e.g. a term/assessment).
class AppLineChart extends StatelessWidget {
  final List<(String label, double value)> points;
  const AppLineChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox(height: 118);
    }
    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].$2)];
    return SizedBox(
      height: 118,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: CustomText(text: points[i].$1, fontSize: 8, color: AppColors.faint, maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AppColors.sky.withOpacity(0.28), AppColors.sky.withOpacity(0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Matches the mockup's `.calendar` month grid — a 7-column M-S day grid
/// with `today` and `eventday` markers.
class AppMonthCalendar extends StatelessWidget {
  final DateTime month;
  final Set<int> eventDays;
  const AppMonthCalendar({super.key, required this.month, this.eventDays = const {}});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final today = DateTime.now();
    final isCurrentMonth = today.year == month.year && today.month == month.month;

    return Column(
      children: [
        Row(
          children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: CustomText(text: d, fontSize: 8, color: AppColors.faint, fontWeight: FontWeight.w700),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leadingBlanks + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemBuilder: (context, i) {
            if (i < leadingBlanks) return const SizedBox.shrink();
            final day = i - leadingBlanks + 1;
            final isToday = isCurrentMonth && today.day == day;
            final hasEvent = eventDays.contains(day);
            return Container(
              decoration: BoxDecoration(
                color: isToday ? AppColors.primaryColor : (hasEvent ? AppColors.pale : null),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: CustomText(
                      text: '$day',
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday ? Colors.white : (hasEvent ? AppColors.blue : const Color(0xFF455C70)),
                    ),
                  ),
                  if (hasEvent && !isToday)
                    Positioned(
                      bottom: 1,
                      child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle)),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
