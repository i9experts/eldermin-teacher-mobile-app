import 'package:flutter/material.dart';
import '../design/design.dart';
import 'app_widgets.dart' show AppTag;

/// Shared sheet body for every custom picker in this file: a title row with a close button and consistent padding, inside the token bottom
/// panel ([EmBottomSheet.showPanel]: surface, radius 28, drag handle). Month, date and weekday pickers read as one family of control.
class _PickerSheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _PickerSheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.screenH, EmSpacing.s8, EmSpacing.screenH, EmSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Semantics(header: true, child: Text(title, style: EmType.heading.copyWith(color: EmColors.ink)))),
                EmIconCircleButton(icon: Icons.close_rounded, semanticLabel: 'Close', tooltip: 'Close', elevated: false, onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: EmSpacing.s12),
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
  return Row(
    children: [
      EmIconCircleButton(icon: Icons.chevron_left_rounded, semanticLabel: 'Previous', tooltip: 'Previous', elevated: false, onTap: onPrev),
      Expanded(child: Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
      EmIconCircleButton(icon: Icons.chevron_right_rounded, semanticLabel: 'Next', tooltip: 'Next', elevated: false, onTap: onNext),
    ],
  );
}

Widget _todayButton(String label, VoidCallback? onTap) {
  return Padding(
    padding: const EdgeInsets.only(top: EmSpacing.s8),
    child: Center(child: TextButton(onPressed: onTap, child: Text(label, style: EmType.label.copyWith(color: onTap == null ? EmColors.onDisabled : EmColors.primary)))),
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

/// One selectable cell of the month and date grids: selected = filled primary, today = ring, disabled = quiet.
class _Cell extends StatelessWidget {
  final String text;
  final bool selected;
  final bool current;
  final bool enabled;
  final BorderRadius radius;
  final VoidCallback? onTap;
  const _Cell({required this.text, required this.selected, required this.current, required this.enabled, required this.radius, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: text,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Material(
        color: selected ? EmColors.primary : EmColors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: radius, border: current && !selected ? Border.all(color: EmColors.primary, width: 1.5) : null),
            child: Center(
              child: Text(
                text,
                style: (selected || current ? EmType.label : EmType.body).copyWith(color: !enabled ? EmColors.onDisabled : (selected ? EmColors.onPrimary : EmColors.ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a token-styled month/year picker as a bottom panel, replacing the
/// static, non-functional "August 2026"-style labels used across the app.
/// Returns the first day of the chosen month, or null if dismissed.
Future<DateTime?> showAppMonthPicker(
  BuildContext context, {
  required DateTime initialMonth,
  DateTime? minMonth,
  DateTime? maxMonth,
}) {
  return EmBottomSheet.showPanel<DateTime>(
    context,
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
  const _AppMonthPickerSheet({required this.initialMonth, this.minMonth, this.maxMonth});

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

  bool get _canGoPrevYear => widget.minMonth == null || _displayedYear - 1 >= widget.minMonth!.year;
  bool get _canGoNextYear => widget.maxMonth == null || _displayedYear + 1 <= widget.maxMonth!.year;

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
          const SizedBox(height: EmSpacing.s12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: EmSpacing.s8, crossAxisSpacing: EmSpacing.s8, mainAxisExtent: EmSpacing.minTouch),
            itemBuilder: (context, i) {
              final month = i + 1;
              return _Cell(
                text: _monthShort[i],
                enabled: _monthWithinBounds(_displayedYear, month, widget.minMonth, widget.maxMonth),
                selected: _displayedYear == widget.initialMonth.year && month == widget.initialMonth.month,
                current: _displayedYear == now.year && month == now.month,
                radius: EmRadius.mdAll,
                onTap: () => Navigator.of(context).pop(DateTime(_displayedYear, month, 1)),
              );
            },
          ),
          _todayButton(
            'Jump to this month',
            _monthWithinBounds(now.year, now.month, widget.minMonth, widget.maxMonth) ? () => Navigator.of(context).pop(DateTime(now.year, now.month, 1)) : null,
          ),
        ],
      ),
    );
  }
}

/// Opens a token-styled day-level calendar picker as a bottom panel, in the
/// same visual language as [showAppMonthPicker] — used in place of Flutter's
/// default [showDatePicker] wherever a specific date (not just a month)
/// needs to be chosen. Returns the picked date, or null if dismissed.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return EmBottomSheet.showPanel<DateTime>(
    context,
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
  const _AppDatePickerSheet({required this.initialDate, this.firstDate, this.lastDate});

  @override
  State<_AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<_AppDatePickerSheet> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  bool get _canGoPrev =>
      _monthWithinBounds(_displayedMonth.year, _displayedMonth.month - 1 == 0 ? 12 : _displayedMonth.month - 1, widget.firstDate, widget.lastDate) || widget.firstDate == null;
  bool get _canGoNext => widget.lastDate == null || (_displayedMonth.year * 12 + _displayedMonth.month) < (widget.lastDate!.year * 12 + widget.lastDate!.month);

  bool _dayEnabled(DateTime d) {
    if (widget.firstDate != null && d.isBefore(DateTime(widget.firstDate!.year, widget.firstDate!.month, widget.firstDate!.day))) {
      return false;
    }
    if (widget.lastDate != null && d.isAfter(DateTime(widget.lastDate!.year, widget.lastDate!.month, widget.lastDate!.day))) {
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
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final leadingBlanks = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday - 1;
    final todayEnabled = _dayEnabled(today);

    return _PickerSheetShell(
      title: 'Select date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _navHeader(
            label: '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
            onPrev: _canGoPrev ? () => _shiftMonth(-1) : null,
            onNext: _canGoNext ? () => _shiftMonth(1) : null,
          ),
          const SizedBox(height: EmSpacing.s8),
          Row(
            children: _weekdayShort.map((d) => Expanded(child: Center(child: Text(d, style: EmType.caption.copyWith(color: EmColors.textSecondary))))).toList(),
          ),
          const SizedBox(height: EmSpacing.s4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: EmSpacing.s4, crossAxisSpacing: EmSpacing.s4, mainAxisExtent: EmSpacing.minTouch),
            itemBuilder: (context, i) {
              if (i < leadingBlanks) return const SizedBox.shrink();
              final day = i - leadingBlanks + 1;
              final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
              return _Cell(
                text: '$day',
                enabled: _dayEnabled(date),
                selected: date.year == widget.initialDate.year && date.month == widget.initialDate.month && date.day == widget.initialDate.day,
                current: date == today,
                radius: EmRadius.smAll,
                onTap: () => Navigator.of(context).pop(date),
              );
            },
          ),
          _todayButton('Jump to today', todayEnabled ? () => Navigator.of(context).pop(today) : null),
        ],
      ),
    );
  }
}

/// Opens a token-styled day-of-week picker (Mon-Sun) as a bottom panel —
/// used where the underlying data is a single already-loaded weekly
/// structure (e.g. a timetable) and "picking a date" really means "picking
/// which weekday of the already-fetched week to view", so no new fetch or
/// calendar date is meaningful. Returns a 0 (Monday) - 6 (Sunday) index.
Future<int?> showAppWeekdayPicker(
  BuildContext context, {
  required int initialWeekday,
}) {
  return EmBottomSheet.showPanel<int>(context, builder: (ctx) => _AppWeekdayPickerSheet(initialWeekday: initialWeekday));
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
            Semantics(
              button: true,
              selected: i == initialWeekday,
              label: _weekdayNames[i],
              excludeSemantics: true,
              onTap: () => Navigator.of(context).pop(i),
              child: Material(
                color: i == initialWeekday ? EmColors.primaryTint : Colors.transparent,
                borderRadius: EmRadius.mdAll,
                child: InkWell(
                  borderRadius: EmRadius.mdAll,
                  onTap: () => Navigator.of(context).pop(i),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s12, vertical: EmSpacing.s8),
                      child: Row(
                        children: [
                          Text(_weekdayNames[i], style: (i == initialWeekday ? EmType.label : EmType.body).copyWith(color: EmColors.ink)),
                          if (i == todayIndex) ...[const SizedBox(width: EmSpacing.s8), const AppTag('Today')],
                          const Spacer(),
                          if (i == initialWeekday) const ExcludeSemantics(child: Icon(Icons.check_rounded, size: 20, color: EmColors.primary)),
                        ],
                      ),
                    ),
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
