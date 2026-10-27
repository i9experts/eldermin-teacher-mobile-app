import 'package:flutter/material.dart';
import '../../../../core/models/behaviour/behaviour_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/detail_bottom_sheet.dart';
import 'widgets/behaviour_widgets.dart';

/// Opens the full detail of one behaviour record (read-only). [mine] says whether I logged it (shown as "You").
Future<void> showBehaviourDetailSheet(BuildContext context, BehaviourRecord record, {required bool mine}) =>
    DetailBottomSheet.show<void>(context, data: () => behaviourSheetData(record, mine: mine));

/// What the sheet shows. `reportedById` is an internal id and is never shown.
DetailSheetData behaviourSheetData(BehaviourRecord r, {required bool mine}) {
  final k = r.kind;
  final demerit = k == BehaviourKind.demerit;
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
      DetailField('Severity', demerit && r.severity.isNotEmpty ? r.severity[0].toUpperCase() + r.severity.substring(1) : null),
      DetailField('Points', r.points == 0 ? null : pointsText(r.points)),
      DetailField('Logged by', mine ? 'You' : r.reportedBy),
      DetailField('Status', demerit ? (r.resolved ? 'Resolved' : 'Open') : null),
      DetailField('Resolution note', r.resolved ? r.resolvedNote : null),
    ],
    longTextLabel: 'Description',
    longText: r.description,
  );
}
