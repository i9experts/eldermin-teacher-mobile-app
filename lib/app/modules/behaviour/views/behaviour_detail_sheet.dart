import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/models/classroom/student_360.dart' show BehaviourItem;
import '../../../../core/models/json_helpers.dart' show storedCalendarDay;
import '../../../../core/services/behaviour_repository.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/detail_bottom_sheet.dart';
import '../../../common/action_failure.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import 'widgets/behaviour_widgets.dart';

/// What the sheet may do besides showing the record. Everything is optional; a null callback hides its button.
class BehaviourSheetActions {
  /// Edit = open the log form on this record (only records I logged: the server answers 403 for anyone else's).
  final void Function(BehaviourRecord record)? onEdit;

  /// Resolve with a note (any record of my classes). Called with the updated record after the server answered.
  final void Function(BehaviourRecord updated)? onResolved;

  /// "View student" (the list opens the student's history; the history itself does not offer it).
  final void Function(BehaviourRecord record)? onOpenStudent;
  const BehaviourSheetActions({this.onEdit, this.onResolved, this.onOpenStudent});
}

/// Opens the full detail of one behaviour record: every field a teacher may see, plus Edit (mine) / Resolve (open concerns) /
/// View student. [mine] says whether I logged it (shown as "You"). [repository] is only for tests.
///
/// [loader]: the sheet opens on [record] (title only) in a loading state, fetches the full record, then shows it (Retry on failure; a
/// 403 / 404 becomes a friendly message, never a crash). [mineOf] then decides "mine" from the loaded record.
Future<void> showBehaviourDetailSheet(
  BuildContext context,
  BehaviourRecord record, {
  required bool mine,
  BehaviourSheetActions actions = const BehaviourSheetActions(),
  BehaviourRepository? repository,
  Future<BehaviourRecord> Function()? loader,
  bool Function(BehaviourRecord)? mineOf,
}) {
  final rec = Rx<BehaviourRecord>(record);
  final busy = false.obs;
  final error = RxnString();
  final loading = (loader != null).obs;
  final loadError = RxnString();
  final isMine = mine.obs;

  Future<void> load() async {
    if (loader == null) return;
    loading.value = true;
    loadError.value = null;
    try {
      final r = await loader();
      rec.value = r;
      if (mineOf != null) isMine.value = mineOf(r);
    } catch (e) {
      loadError.value = ActionFailure.from(e, what: 'open this entry').message;
    } finally {
      loading.value = false;
    }
  }

  if (loader != null) load();

  Future<void> resolve() async {
    final note = await _askResolutionNote(context);
    if (note == null) return;
    busy.value = true;
    error.value = null;
    try {
      final repo = repository ?? Get.find<BehaviourRepository>();
      final updated = await repo.resolve(rec.value.id, note: note);
      // the server answers with the whole document; keep the name/class we already have if it comes back thin
      rec.value = updated.id.isEmpty ? rec.value.copyWith(resolved: true, resolvedNote: note) : updated;
      actions.onResolved?.call(rec.value);
    } catch (e) {
      error.value = ActionFailure.from(e, what: 'resolve this record').message;
    } finally {
      busy.value = false;
    }
  }

  return DetailBottomSheet.show<void>(
    context,
    reactive: true,
    data: () {
      final r = rec.value;
      if (loading.value) return DetailSheetData(title: r.title.isEmpty ? 'Behaviour record' : r.title, state: DetailSheetState.loading);
      if (loadError.value != null) return DetailSheetData(title: 'Behaviour record', state: DetailSheetState.error, errorMessage: loadError.value, onRetry: load);
      final mine = isMine.value;
      final canResolve = actions.onResolved != null && behaviourCanResolve(r);
      final canEdit = mine && actions.onEdit != null;
      final canOpen = actions.onOpenStudent != null;
      final hasFooter = canResolve || canEdit || canOpen || error.value != null;
      return behaviourSheetData(
        r,
        mine: mine,
        footer: hasFooter
            ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (error.value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: EmSpacing.s8),
                    child: Text(error.value!, key: const Key('detail_action_error'), style: EmType.body.copyWith(color: EmColors.error)),
                  ),
                if (canResolve)
                  EmPrimaryButton(key: const Key('detail_resolve'), label: 'Resolve', loading: busy.value, onPressed: busy.value ? null : resolve),
                if (canEdit) ...[
                  if (canResolve) const SizedBox(height: EmSpacing.s8),
                  EmSecondaryButton(
                    key: const Key('detail_edit'),
                    label: 'Edit entry',
                    onPressed: busy.value
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            actions.onEdit!(rec.value);
                          },
                  ),
                ],
                if (canOpen) ...[
                  if (canResolve || canEdit) const SizedBox(height: EmSpacing.s8),
                  EmTextAction(
                    key: const Key('detail_open_student'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      actions.onOpenStudent!(rec.value);
                    },
                    icon: Icons.person_outline_rounded,
                    label: 'View student',
                  ),
                ],
              ])
            : null,
      );
    },
  );
}

/// Only an open concern (or any entry that asked for a follow-up) can be resolved.
bool behaviourCanResolve(BehaviourRecord r) => !r.resolved && (r.kind == BehaviourKind.demerit || r.followUpRequired);

/// Asks for the resolution note (optional). Null = cancelled.
Future<String?> _askResolutionNote(BuildContext context) => EmBottomSheet.show<String>(context, title: 'Resolve this entry', child: const _ResolveNoteForm());

/// Owns its text controller (disposed with the State, i.e. AFTER the sheet's closing animation, never while it is still on screen).
class _ResolveNoteForm extends StatefulWidget {
  const _ResolveNoteForm();

  @override
  State<_ResolveNoteForm> createState() => _ResolveNoteFormState();
}

class _ResolveNoteFormState extends State<_ResolveNoteForm> {
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, 0, EmSpacing.screenH, EmSpacing.s16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LabeledField(label: 'Resolution note', controller: note, fieldKey: const Key('resolve_note'), maxLines: 3, hint: 'What was done (optional)'),
          const SizedBox(height: EmSpacing.s12),
          EmPrimaryButton(key: const Key('resolve_confirm'), label: 'Mark resolved', onPressed: () => Navigator.of(context).pop(note.text)),
        ]),
      );
}

/// What the sheet shows. `reportedById` is an internal id and is never shown. [footer] = the action buttons.
DetailSheetData behaviourSheetData(BehaviourRecord r, {required bool mine, Widget? footer}) {
  final k = r.kind;
  final demerit = k == BehaviourKind.demerit;
  String? yesNo(bool v) => v ? 'Yes' : null;
  final followUp = [
    if (r.followUpRequired) 'Required',
    if (r.followUpDate != null) 'by ${fullDay(_cal(r.followUpDate!))}',
  ].join(' ');
  final notified = r.parentNotified
      ? [
          'Yes',
          if (r.parentNotifiedDate != null) 'on ${fullDay(_cal(r.parentNotifiedDate!))}',
          if (r.parentNotifiedBy.isNotEmpty) 'by ${r.parentNotifiedBy}',
        ].join(' ')
      : null;
  return DetailSheetData(
    title: r.title.isEmpty ? (categoryLabel(r.category).isEmpty ? 'Behaviour record' : categoryLabel(r.category)) : r.title,
    statusLabel: k?.label,
    statusTone: kindTone(k),
    notice: 'Parents can see what you log here in their app.',
    fields: [
      DetailField('Student', r.studentName),
      DetailField('Class', r.classLabel),
      DetailField('Date', r.day == null ? null : fullDay(r.day!)),
      DetailField('Category', categoryLabel(r.category)),
      // severity defaults to "medium" on every record, so it only means something for a concern
      DetailField('Severity', demerit && r.severity.isNotEmpty ? severityLabel(r.severity) : null),
      DetailField('Points', r.points == 0 ? null : pointsText(r.points)),
      DetailField('Consequence', consequenceLabel(r.consequence)),
      DetailField('Location', r.location),
      DetailField('Action taken', r.actionTaken),
      DetailField('Witnesses', r.witnesses.join(', ')),
      DetailField('Follow-up', followUp),
      DetailField('Follow-up note', r.followUpNote),
      DetailField('Parents notified', notified),
      DetailField('Parent response', r.parentResponse),
      DetailField('Logged by', mine ? 'You' : r.reportedBy),
      DetailField('Verified', r.verified ? (r.verifiedBy.isEmpty ? 'Yes' : 'Yes, by ${r.verifiedBy}') : yesNo(false)),
      DetailField('Status', demerit || r.resolved ? (r.resolved ? 'Resolved' : 'Open') : null),
      DetailField('Resolved on', r.resolved && r.resolvedDate != null ? fullDay(_cal(r.resolvedDate!)) : null),
      DetailField('Resolution note', r.resolved ? r.resolvedNote : null),
    ],
    longTextLabel: 'Description',
    longText: r.description,
    attachments: [for (final u in r.attachments) DetailAttachment(_fileName(u), u)],
    footer: footer,
  );
}

DateTime _cal(DateTime d) => storedCalendarDay(d) ?? d;

String _fileName(String url) {
  final seg = url.split('?').first.split('/').where((e) => e.isNotEmpty).toList();
  return seg.isEmpty ? url : Uri.decodeComponent(seg.last);
}


/// A behaviour row of the Student 360 card. An item of the Behaviour module's own store (backend B1 `source: 'records'`) opens the FULL
/// record (fetched by id); a legacy item shows what the 360 carries, read-only.
Future<void> showBehaviourItemSheet(
  BuildContext context,
  BehaviourItem item, {
  required String studentId,
  required String studentName,
  required String myId,
  required String myName,
  BehaviourSheetActions actions = const BehaviourSheetActions(),
  BehaviourRepository? repository,
}) {
  final stub = BehaviourRecord(
    id: item.id,
    studentId: studentId,
    studentName: studentName,
    date: item.date,
    typeWire: item.type,
    category: item.category,
    title: item.title,
    description: item.description,
    severity: item.severity.isEmpty ? 'medium' : item.severity,
    points: item.points,
    resolved: item.resolved,
  );
  if (!item.isRecord) {
    return showBehaviourDetailSheet(context, stub, mine: false, repository: repository);
  }
  return showBehaviourDetailSheet(
    context,
    stub,
    mine: false,
    actions: actions,
    repository: repository,
    loader: () => (repository ?? Get.find<BehaviourRepository>()).fetchRecord(item.id),
    mineOf: (r) => r.isMine(userId: myId, userName: myName),
  );
}
