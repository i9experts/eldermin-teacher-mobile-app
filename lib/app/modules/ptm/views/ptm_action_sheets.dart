import 'package:flutter/material.dart';
import '../../../../core/models/ptm/ptm_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../components/custom_text.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../controllers/ptm_detail_controller.dart';
import 'widgets/ptm_widgets.dart';

typedef ResultSink = void Function(PtmResult r);

Widget _fail(String? text) => text == null ? const SizedBox.shrink() : ErrorBanner(bannerKey: const Key('sheet_error'), message: text);

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
        Expanded(child: OutlinedButton(key: const Key('reschedule_keep'), onPressed: saving ? null : () => Navigator.of(context).pop(), child: const Text('Keep current time'))),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            key: const Key('reschedule_save'),
            onPressed: saving ? null : _save,
            child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Reschedule'),
          ),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fail(failure),
        const CustomText(text: 'The meeting goes back to "Requested" and the guardian is told about the new time.', fontSize: 12, color: AppColors.muted, height: 1.35),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _timeField('Start *', 'reschedule_start', start, errors['start'], (v) => setState(() {
                start = v;
                errors.remove('start');
              }))),
          const SizedBox(width: 12),
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
        if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: error, color: AppColors.redText, fontSize: 11, fontWeight: FontWeight.w600)),
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
        Expanded(child: OutlinedButton(key: const Key('cancel_keep'), onPressed: saving ? null : () => Navigator.of(context).pop(), child: const Text('Keep meeting'))),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            key: const Key('cancel_confirm'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.redText),
            onPressed: saving ? null : _save,
            child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Cancel meeting'),
          ),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fail(failure),
        const CustomText(text: 'The guardian is told that it is cancelled. Give a short reason.', fontSize: 12, color: AppColors.muted, height: 1.35),
        const SizedBox(height: 10),
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
        Expanded(child: OutlinedButton(key: const Key('outcome_close'), onPressed: saving ? null : () => Navigator.of(context).pop(), child: const Text('Not now'))),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            key: const Key('outcome_save'),
            onPressed: saving ? null : _save,
            child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save outcome'),
          ),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fail(failure),
        const FormLabel('Did the parent attend?'),
        Row(children: [
          Expanded(child: ChoiceChip(key: const Key('outcome_attended'), label: const Center(child: Text('Attended')), selected: attended, onSelected: (_) => setState(() => attended = true))),
          const SizedBox(width: 10),
          Expanded(child: ChoiceChip(key: const Key('outcome_noshow'), label: const Center(child: Text('No-show')), selected: !attended, onSelected: (_) => setState(() => attended = false))),
        ]),
        const SizedBox(height: 14),
        LabeledField(label: 'Meeting notes', controller: notes, fieldKey: const Key('outcome_notes'), maxLines: 4, maxLength: kPtmNotesMax, hint: 'What was discussed?', error: errors['notes']),
        FormLabel('Action items', error: errors['items']),
        for (var i = 0; i < items.length; i++) _itemEditor(i),
        TextButton.icon(
          key: const Key('outcome_add_item'),
          onPressed: items.length >= kPtmMaxActionItems ? null : () => setState(() => items.add(_ItemRow())),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add action item'),
        ),
      ]),
    );
  }

  Widget _itemEditor(int i) {
    final row = items[i];
    final err = errors['item$i'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: err == null ? AppColors.line : AppColors.redText)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CustomText(text: 'Item ${i + 1}', fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryColor)),
          IconButton(key: Key('outcome_remove_$i'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => items.removeAt(i).dispose())),
        ]),
        TextField(key: Key('outcome_item_desc_$i'), controller: row.desc, maxLength: kPtmActionDescriptionMax, decoration: const InputDecoration(isDense: true, hintText: 'What needs to happen?', counterText: '', filled: true, fillColor: Colors.white)),
        const SizedBox(height: 8),
        TextField(key: Key('outcome_item_who_$i'), controller: row.who, maxLength: kPtmActionAssigneeMax, decoration: const InputDecoration(isDense: true, hintText: 'Who? (Teacher, Parent ...)', counterText: '', filled: true, fillColor: Colors.white)),
        const SizedBox(height: 8),
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
        if (err != null) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(text: err, color: AppColors.redText, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
