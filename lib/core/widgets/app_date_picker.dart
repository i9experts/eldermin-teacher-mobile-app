import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../app/components/custom_text.dart';
import 'app_widgets.dart' show AppTag;

/// Shared bottom-sheet chrome for every custom picker in this file: a
/// rounded-top white sheet with a drag handle, a title row with a close
/// button, and consistent padding — so month/date/weekday pickers all read
/// as the same family of control instead of three bespoke designs.
class _PickerSheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _PickerSheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomText(
                    text: title,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryColor),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.muted),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

Widget _navHeader({
  required String label,
  required VoidCallback? onPrev,
  required VoidCallback? onNext,
}) {
  Widget arrow(IconData icon, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: onTap == null
                  ? AppColors.background.withOpacity(0.5)
                  : AppColors.background,
              shape: BoxShape.circle),
          child: Icon(icon,
              size: 18, color: onTap == null ? AppColors.faint : AppColors.primaryColor),
        ),
      ),
    );
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      arrow(Icons.chevron_left_rounded, onPrev),
      CustomText(
          text: label,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryColor),
      arrow(Icons.chevron_right_rounded, onNext),
    ],
  );
}

Widget _todayButton(String label, VoidCallback? onTap) {
  return Align(
    alignment: Alignment.center,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: onTap == null ? AppColors.background : AppColors.pale,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: CustomText(
              text: label,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: onTap == null ? AppColors.faint : AppColors.blue),
        ),
      ),
    ),
  );
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

bool _monthWithinBounds(int year, int month, DateTime? min, DateTime? max) {
  final v = year * 12 + month;
  if (min != null && v < min.year * 12 + min.month) return false;
  if (max != null && v > max.year * 12 + max.month) return false;
  return true;
}

/// Opens a custom-styled month/year picker as a bottom sheet, replacing the
/// static, non-functional "August 2026"-style labels used across the app.
/// Returns the first day of the chosen month, or null if dismissed.
Future<DateTime?> showAppMonthPicker(
  BuildContext context, {
  required DateTime initialMonth,
  DateTime? minMonth,
  DateTime? maxMonth,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AppMonthPickerSheet(
      initialMonth: initialMonth,
      minMonth: minMonth,
      maxMonth: maxMonth,
    ),
  );
}

class _AppMonthPickerSheet extends StatefulWidget {
  final DateTime initialMonth;
  final DateTime? minMonth;
  final DateTime? maxMonth;
  const _AppMonthPickerSheet(
      {required this.initialMonth, this.minMonth, this.maxMonth});

  @override
  State<_AppMonthPickerSheet> createState() => _AppMonthPickerSheetState();
}

class _AppMonthPickerSheetState extends State<_AppMonthPickerSheet> {
  late int _displayedYear;

  @override
  void initState() {
    super.initState();
    _displayedYear = widget.initialMonth.year;
  }

  bool get _canGoPrevYear =>
      widget.minMonth == null || _displayedYear - 1 >= widget.minMonth!.year;
  bool get _canGoNextYear =>
      widget.maxMonth == null || _displayedYear + 1 <= widget.maxMonth!.year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _PickerSheetShell(
      title: 'Select month',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _navHeader(
            label: '$_displayedYear',
            onPrev: _canGoPrevYear ? () => setState(() => _displayedYear--) : null,
            onNext: _canGoNextYear ? () => setState(() => _displayedYear++) : null,
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6),
            itemBuilder: (context, i) {
              final month = i + 1;
              final enabled = _monthWithinBounds(
                  _displayedYear, month, widget.minMonth, widget.maxMonth);
              final isSelected = _displayedYear == widget.initialMonth.year &&
                  month == widget.initialMonth.month;
              final isCurrent =
                  _displayedYear == now.year && month == now.month;
              return Material(
                color: isSelected ? AppColors.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: enabled
                      ? () => Navigator.of(context)
                          .pop(DateTime(_displayedYear, month, 1))
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryColor
                            : (isCurrent ? AppColors.blue : AppColors.line),
                        width: isCurrent && !isSelected ? 1.4 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: CustomText(
                      text: _monthShort[i],
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: !enabled
                          ? AppColors.faint
                          : (isSelected ? Colors.white : AppColors.ink),
                    ),
                  ),
                ),
              );
            },
          ),
          _todayButton(
            'Jump to this month',
            _monthWithinBounds(now.year, now.month, widget.minMonth, widget.maxMonth)
                ? () => Navigator.of(context).pop(DateTime(now.year, now.month, 1))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Opens a custom-styled day-level calendar picker as a bottom sheet, in the
/// same visual language as [showAppMonthPicker] — used in place of Flutter's
/// default [showDatePicker] wherever a specific date (not just a month)
/// needs to be chosen. Returns the picked date, or null if dismissed.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AppDatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _AppDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  const _AppDatePickerSheet(
      {required this.initialDate, this.firstDate, this.lastDate});

  @override
  State<_AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<_AppDatePickerSheet> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth =
        DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  bool get _canGoPrev => _monthWithinBounds(_displayedMonth.year,
      _displayedMonth.month - 1 == 0 ? 12 : _displayedMonth.month - 1,
      widget.firstDate, widget.lastDate) ||
      widget.firstDate == null;
  bool get _canGoNext => widget.lastDate == null ||
      (_displayedMonth.year * 12 + _displayedMonth.month) <
          (widget.lastDate!.year * 12 + widget.lastDate!.month);

  bool _dayEnabled(DateTime d) {
    if (widget.firstDate != null && d.isBefore(DateTime(
        widget.firstDate!.year, widget.firstDate!.month, widget.firstDate!.day))) {
      return false;
    }
    if (widget.lastDate != null && d.isAfter(DateTime(
        widget.lastDate!.year, widget.lastDate!.month, widget.lastDate!.day))) {
      return false;
    }
    return true;
  }

  void _shiftMonth(int delta) {
    setState(() {
      final total = _displayedMonth.year * 12 + (_displayedMonth.month - 1) + delta;
      _displayedMonth = DateTime(total ~/ 12, total % 12 + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final leadingBlanks =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday - 1;
    final todayEnabled = _dayEnabled(today);

    return _PickerSheetShell(
      title: 'Select date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _navHeader(
            label:
                '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
            onPrev: _canGoPrev ? () => _shiftMonth(-1) : null,
            onNext: _canGoNext ? () => _shiftMonth(1) : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _weekdayShort
                .map((d) => Expanded(
                      child: Center(
                        child: CustomText(
                            text: d,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.faint),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemBuilder: (context, i) {
              if (i < leadingBlanks) return const SizedBox.shrink();
              final day = i - leadingBlanks + 1;
              final date =
                  DateTime(_displayedMonth.year, _displayedMonth.month, day);
              final isToday = date == today;
              final isSelected = date.year == widget.initialDate.year &&
                  date.month == widget.initialDate.month &&
                  date.day == widget.initialDate.day;
              final enabled = _dayEnabled(date);
              return Material(
                color: isSelected ? AppColors.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: enabled ? () => Navigator.of(context).pop(date) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: isToday && !isSelected
                          ? Border.all(color: AppColors.blue, width: 1.4)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: CustomText(
                      text: '$day',
                      fontSize: 12,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: !enabled
                          ? AppColors.faint.withOpacity(0.5)
                          : (isSelected ? Colors.white : AppColors.ink),
                    ),
                  ),
                ),
              );
            },
          ),
          _todayButton('Jump to today', todayEnabled ? () => Navigator.of(context).pop(today) : null),
        ],
      ),
    );
  }
}

/// Opens a custom-styled day-of-week picker (Mon-Sun) as a bottom sheet —
/// used where the underlying data is a single already-loaded weekly
/// structure (e.g. a timetable) and "picking a date" really means "picking
/// which weekday of the already-fetched week to view", so no new fetch or
/// calendar date is meaningful. Returns a 0 (Monday) - 6 (Sunday) index.
Future<int?> showAppWeekdayPicker(
  BuildContext context, {
  required int initialWeekday,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AppWeekdayPickerSheet(initialWeekday: initialWeekday),
  );
}

class _AppWeekdayPickerSheet extends StatelessWidget {
  final int initialWeekday;
  const _AppWeekdayPickerSheet({required this.initialWeekday});

  @override
  Widget build(BuildContext context) {
    final todayIndex = DateTime.now().weekday - 1;
    return _PickerSheetShell(
      title: 'Select day',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 7; i++) ...[
            Material(
              color: i == initialWeekday ? AppColors.pale : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => Navigator.of(context).pop(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      CustomText(
                        text: _weekdayNames[i],
                        fontSize: 13,
                        fontWeight: i == initialWeekday
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: i == initialWeekday
                            ? AppColors.primaryColor
                            : AppColors.ink,
                      ),
                      if (i == todayIndex) ...[
                        const SizedBox(width: 8),
                        const AppTag('Today'),
                      ],
                      const Spacer(),
                      if (i == initialWeekday)
                        const Icon(Icons.check_rounded,
                            size: 18, color: AppColors.primaryColor),
                    ],
                  ),
                ),
              ),
            ),
            if (i != 6) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
