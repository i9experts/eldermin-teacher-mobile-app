import 'package:flutter/material.dart';
import '../../../../core/models/ptm/ptm_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../controllers/ptm_detail_controller.dart';
import 'widgets/ptm_widgets.dart';
import '../../../../core/design/design.dart';

typedef ResultSink = void Function(PtmResult r);

Widget _fail(String? text) => text == null ? const SizedBox.shrink() : ErrorBanner(bannerKey: const Key('sheet_error'), message: text);

Widget _note(String text) => Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s12), child: Text(text, style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)));

/// A validation message under a field: glyph + words in the error colour (readable at 1.3x, wraps instead of clipping).
Widget _err(String text) => Padding(
      padding: const EdgeInsets.only(top: EmSpacing.s4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: EmSpacing.s2), child: Icon(Icons.error_outline_rounded, size: 16, color: EmColors.error)),
        const SizedBox(width: EmSpacing.s4),
        Expanded(child: Text(text, style: EmType.caption.copyWith(color: EmColors.error, fontWeight: FontWeight.w600))),
      ]),
    );

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: EmType.body.copyWith(color: EmColors.textTertiary),
      counterText: '',
      filled: true,
      fillColor: EmColors.surface,
      border: OutlineInputBorder(borderRadius: EmRadius.smAll, borderSide: const BorderSide(color: EmColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: EmRadius.smAll, borderSide: const BorderSide(color: EmColors.border)),
    );

// ── reschedule ──────────────────────────────────────────────

Future<void> showRescheduleSheet(BuildContext context, PtmDetailController c, {required ResultSink onResult}) =>
    showAppSheet<void>(context, (_) => _RescheduleSheet(c: c, onResult: onResult));

class _RescheduleSheet extends StatefulWidget {
  final PtmDetailController c;
  final ResultSink onResult;
  const _RescheduleSheet({required this.c, required this.onResult});

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  DateTime? day;
  String? start, end;
  Map<String, String> errors = {};
  String? failure;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.c.meeting!;
    final d = m.day;
    final today = widget.c.clock();
    // Prefill the current date unless it already passed (then the teacher must pick a new one).
    day = d != null && !DateTime(d.year, d.month, d.day).isBefore(DateTime(today.year, today.month, today.day)) ? d : null;
    start = m.startTime.isEmpty ? null : m.startTime;
    end = m.endTime.isEmpty ? null : m.endTime;
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() {
      saving = true;
      failure = null;
    });
    final r = await widget.c.reschedule(day: day, start: start, end: end);
    if (!mounted) return;
    switch (r) {
      case PtmDone():
        Navigator.of(context).pop();
        widget.onResult(r);
      case PtmInvalid(:final errors):
        setState(() {
          this.errors = errors;
          saving = false;
        });
      case PtmFailed(:final text):
        setState(() {
          failure = text;
          saving = false;
        });
      case PtmIgnored():
        setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.c.clock();
    return SheetFrame(
      title: 'Reschedule meeting',
      actions: [
        Expanded(child: EmSecondaryButton(key: const Key('reschedule_keep'), label: 'Keep current time', expand: true, onPressed: saving ? null : () => Navigator.of(context).pop())),
        const SizedBox(width: EmSpacing.s12),
        Expanded(child: EmPrimaryButton(key: const Key('reschedule_save'), label: 'Reschedule', loading: saving, onPressed: saving ? null : _save)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fail(failure),
        _note('The meeting goes back to "Requested" and the guardian is told about the new time.'),
        FormLabel('Date *', error: errors['day']),
        PickField(
          fieldKey: const Key('reschedule_day'),
          icon: Icons.event_rounded,
          text: day == null ? 'Choose a date' : '${shortDay(day!)} ${day!.year}',
          filled: day != null,
          error: errors['day'],
          onTap: () async {
            final t = DateTime(today.year, today.month, today.day);
            final p = await showAppDatePicker(context, initialDate: day ?? t, firstDate: t, lastDate: DateTime(t.year + 2, 12, 31));
            if (p != null) {
              setState(() {
                day = DateTime(p.year, p.month, p.day);
                errors.remove('day');
              });
            }
          },
        ),
        const SizedBox(height: EmSpacing.row),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _timeField('Start *', 'reschedule_start', start, errors['start'], (v) => setState(() {
                start = v;
                errors.remove('start');
              }))),
          const SizedBox(width: EmSpacing.row),
          Expanded(child: _timeField('End *', 'reschedule_end', end, errors['end'], (v) => setState(() {
                end = v;
                errors.remove('end');
              }))),
        ]),
      ]),
    );
  }

  Widget _timeField(String label, String key, String? value, String? error, ValueChanged<String> onPicked) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormLabel(label),
        PickField(fieldKey: Key(key), icon: Icons.schedule_rounded, text: value ?? 'Choose', filled: value != null, error: error, onTap: () async {
          final p = await pickHm(context, initial: value);
          if (p != null) onPicked(p);
        }),
        if (error != null) _err(error),
      ]);
}

// ── cancel ──────────────────────────────────────────────────

Future<void> showCancelSheet(BuildContext context, PtmDetailController c, {required ResultSink onResult}) =>
    showAppSheet<void>(context, (_) => _CancelSheet(c: c, onResult: onResult));

class _CancelSheet extends StatefulWidget {
  final PtmDetailController c;
  final ResultSink onResult;
  const _CancelSheet({required this.c, required this.onResult});

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final reason = TextEditingController();
  String? error, failure;
  bool saving = false;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() {
      saving = true;
      failure = null;
    });
    final r = await widget.c.cancel(reason.text);
    if (!mounted) return;
    switch (r) {
      case PtmDone():
        Navigator.of(context).pop();
        widget.onResult(r);
      case PtmInvalid(:final errors):
        setState(() {
          error = errors.values.first;
          saving = false;
        });
      case PtmFailed(:final text):
        setState(() {
          failure = text;
          saving = false;
        });
      case PtmIgnored():
        setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Cancel this meeting?',
      actions: [
        Expanded(child: EmSecondaryButton(key: const Key('cancel_keep'), label: 'Keep meeting', expand: true, onPressed: saving ? null : () => Navigator.of(context).pop())),
        const SizedBox(width: EmSpacing.s12),
        Expanded(child: EmPrimaryButton(key: const Key('cancel_confirm'), label: 'Cancel meeting', destructive: true, loading: saving, onPressed: saving ? null : _save)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fail(failure),
        _note('The guardian is told that it is cancelled. Give a short reason.'),
        LabeledField(label: 'Reason', required: true, controller: reason, fieldKey: const Key('cancel_reason'), maxLines: 3, maxLength: kPtmReasonMax, error: error, onChanged: (_) => setState(() => error = null)),
      ]),
    );
  }
}

// ── outcome ─────────────────────────────────────────────────

Future<void> showOutcomeSheet(BuildContext context, PtmDetailController c, {required ResultSink onResult}) =>
    showAppSheet<void>(context, (_) => _OutcomeSheet(c: c, onResult: onResult));

class _ItemRow {
  final desc = TextEditingController();
  final who = TextEditingController();
  DateTime? due;
  void dispose() {
    desc.dispose();
    who.dispose();
  }
}

class _OutcomeSheet extends StatefulWidget {
  final PtmDetailController c;
  final ResultSink onResult;
  const _OutcomeSheet({required this.c, required this.onResult});

  @override
  State<_OutcomeSheet> createState() => _OutcomeSheetState();
}

class _OutcomeSheetState extends State<_OutcomeSheet> {
  bool attended = true;
  final notes = TextEditingController();
  final items = <_ItemRow>[];
  Map<String, String> errors = {};
  String? failure;
  bool saving = false;

  @override
  void dispose() {
    notes.dispose();
    for (final i in items) {
      i.dispose();
    }
    super.dispose();
  }

  PtmOutcomeRequest get _request => PtmOutcomeRequest(
        parentAttended: attended,
        meetingNotes: notes.text,
        actionItems: [for (final i in items) ActionItemDraft(description: i.desc.text, assignedTo: i.who.text, dueDay: i.due)],
      );

  Future<void> _save() async {
    if (saving) return;
    setState(() {
      saving = true;
      failure = null;
    });
    final r = await widget.c.recordOutcome(_request);
    if (!mounted) return;
    switch (r) {
      case PtmDone():
        Navigator.of(context).pop();
        widget.onResult(r);
      case PtmInvalid(:final errors):
        setState(() {
          this.errors = errors;
          saving = false;
        });
      case PtmFailed(:final text):
        setState(() {
          failure = text;
          saving = false;
        });
      case PtmIgnored():
        setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Record outcome',
      actions: [
        Expanded(child: EmSecondaryButton(key: const Key('outcome_close'), label: 'Not now', expand: true, onPressed: saving ? null : () => Navigator.of(context).pop())),
        const SizedBox(width: EmSpacing.s12),
        Expanded(child: EmPrimaryButton(key: const Key('outcome_save'), label: 'Save outcome', loading: saving, onPressed: saving ? null : _save)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fail(failure),
        const FormLabel('Did the parent attend?'),
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
          EmChip(key: const Key('outcome_attended'), label: 'Attended', icon: attended ? Icons.check_rounded : null, selected: attended, onTap: () => setState(() => attended = true)),
          EmChip(key: const Key('outcome_noshow'), label: 'No-show', icon: !attended ? Icons.check_rounded : null, selected: !attended, onTap: () => setState(() => attended = false)),
        ]),
        const SizedBox(height: EmSpacing.block),
        LabeledField(label: 'Meeting notes', controller: notes, fieldKey: const Key('outcome_notes'), maxLines: 4, maxLength: kPtmNotesMax, hint: 'What was discussed?', error: errors['notes']),
        FormLabel('Action items', error: errors['items']),
        for (var i = 0; i < items.length; i++) _itemEditor(i),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: EmTextAction(key: const Key('outcome_add_item'), label: 'Add action item', icon: Icons.add_rounded, onPressed: items.length >= kPtmMaxActionItems ? null : () => setState(() => items.add(_ItemRow()))),
        ),
      ]),
    );
  }

  Widget _itemEditor(int i) {
    final row = items[i];
    final err = errors['item$i'];
    return Container(
      margin: const EdgeInsets.only(bottom: EmSpacing.s12),
      padding: const EdgeInsets.all(EmSpacing.s12),
      decoration: BoxDecoration(color: EmColors.background, borderRadius: EmRadius.mdAll, border: Border.all(color: err == null ? EmColors.border : EmColors.error)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Item ${i + 1}', style: EmType.label.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink))),
          EmIconCircleButton(key: Key('outcome_remove_$i'), icon: Icons.close_rounded, semanticLabel: 'Remove item ${i + 1}', tooltip: 'Remove item', onTap: () => setState(() => items.removeAt(i).dispose())),
        ]),
        TextField(key: Key('outcome_item_desc_$i'), controller: row.desc, maxLength: kPtmActionDescriptionMax, style: EmType.body.copyWith(color: EmColors.ink), onChanged: (_) { if (errors.containsKey('item$i')) setState(() => errors.remove('item$i')); }, decoration: _fieldDecoration('What needs to happen?')),
        const SizedBox(height: EmSpacing.s8),
        TextField(key: Key('outcome_item_who_$i'), controller: row.who, maxLength: kPtmActionAssigneeMax, style: EmType.body.copyWith(color: EmColors.ink), decoration: _fieldDecoration('Who? (Teacher, Parent ...)')),
        const SizedBox(height: EmSpacing.s8),
        PickField(
          fieldKey: Key('outcome_item_due_$i'),
          icon: Icons.event_rounded,
          text: row.due == null ? 'Due date (optional)' : 'Due ${shortDay(row.due!)} ${row.due!.year}',
          filled: row.due != null,
          onTap: () async {
            final t = widget.c.clock();
            final today = DateTime(t.year, t.month, t.day);
            final p = await showAppDatePicker(context, initialDate: row.due ?? today, firstDate: today, lastDate: DateTime(today.year + 2, 12, 31));
            if (p != null) setState(() => row.due = DateTime(p.year, p.month, p.day));
          },
        ),
        if (err != null) _err(err),
      ]),
    );
  }
}
