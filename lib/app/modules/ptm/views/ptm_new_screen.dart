import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../routes/app_routes.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../controllers/ptm_create_controller.dart';
import 'widgets/ptm_widgets.dart';
import '../../../../core/design/design.dart';

/// Schedule a meeting (`/ptm/new`): student of my classes, date, start and end time, discussion points.
class PtmNewScreen extends GetView<PtmCreateController> {
  const PtmNewScreen({super.key});

  PtmCreateController get c => controller;

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || c.saving.value) return;
        if (c.isDirty) {
          final leave = await ConfirmDialog.show(title: 'Discard this meeting?', message: 'What you entered will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(title: 'New meeting'),
        body: Obx(() {
          if (c.classes.isEmpty) {
            return const AppEmptyView(key: Key('ptm_new_no_classes'), icon: Icons.school_outlined, title: "You aren't assigned to any class yet", subtitle: 'You can schedule meetings about students in your classes.');
          }
          return Column(children: [Expanded(child: _form(context)), _bottom(context)]);
        }),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final e = c.errors;
    final s = c.student.value;
    final day = c.day.value;
    final f = c.failure.value;
    final today = c.clock();
    return ListView(padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s24), children: [
      if (f != null) ErrorBanner(bannerKey: const Key('ptm_new_error'), message: f.serverMessage.isNotEmpty ? f.serverMessage : f.message),
      if (e['teacher'] != null) ErrorBanner(bannerKey: const Key('ptm_new_teacher_error'), message: e['teacher']!),
      FormLabel('Student *', error: e['student']),
      InkWell(
        key: const Key('ptm_new_student'),
        borderRadius: EmRadius.mdAll,
        onTap: () => _pickStudent(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
          padding: const EdgeInsets.all(EmSpacing.s12),
          decoration: BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.mdAll, border: Border.all(color: e['student'] == null && e['year'] == null ? EmColors.border : EmColors.error)),
          child: Row(children: [
            if (s != null) ...[StudentAvatar(student: s, size: 34), const SizedBox(width: EmSpacing.s12)] else const Padding(padding: EdgeInsetsDirectional.only(end: EmSpacing.s12), child: Icon(Icons.person_search_rounded, color: EmColors.primary)),
            Expanded(
              child: s == null
                  ? Text('Choose a student from your classes', style: EmType.label.copyWith(color: EmColors.textSecondary))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.fullName, key: const Key('ptm_new_selected'), style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.primary)),
                      Text(s.classLabel, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                    ]),
            ),
            const Icon(Icons.expand_more_rounded, color: EmColors.textSecondary),
          ]),
        ),
      ),
      if (e['year'] != null) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: _error(e['year']!, key: const Key('ptm_new_year_error'))),
      const SizedBox(height: EmSpacing.block),
      FormLabel('Date *', error: e['day']),
      PickField(
        fieldKey: const Key('ptm_new_day'),
        icon: Icons.event_rounded,
        text: day == null ? 'Choose a date' : '${shortDay(day)} ${day.year}',
        filled: day != null,
        error: e['day'],
        onTap: () async {
          final t = DateTime(today.year, today.month, today.day);
          final p = await showAppDatePicker(context, initialDate: day ?? t, firstDate: t, lastDate: DateTime(t.year + 2, 12, 31));
          if (p != null) c.setDay(p);
        },
      ),
      const SizedBox(height: EmSpacing.block),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _time('Start *', 'ptm_new_start', c.start.value, e['start'], c.setStart, context)),
        const SizedBox(width: EmSpacing.row),
        Expanded(child: _time('End *', 'ptm_new_end', c.end.value, e['end'], c.setEnd, context)),
      ]),
      const SizedBox(height: EmSpacing.block),
      FormLabel('Discussion points', error: e['points']),
      for (var i = 0; i < c.points.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: EmSpacing.s8),
          child: Row(children: [
            Expanded(child: TextField(key: Key('ptm_new_point_$i'), controller: c.points[i], maxLength: kPtmPointMax, textCapitalization: TextCapitalization.sentences, style: EmType.body.copyWith(color: EmColors.ink), decoration: InputDecoration(isDense: true, hintText: 'e.g. Progress in maths', hintStyle: EmType.body.copyWith(color: EmColors.textTertiary), counterText: '', filled: true, fillColor: EmColors.surface, border: OutlineInputBorder(borderRadius: EmRadius.mdAll, borderSide: const BorderSide(color: EmColors.border)), enabledBorder: OutlineInputBorder(borderRadius: EmRadius.mdAll, borderSide: const BorderSide(color: EmColors.border))))),
            const SizedBox(width: EmSpacing.s8),
            EmIconCircleButton(key: Key('ptm_new_point_remove_$i'), icon: Icons.close_rounded, semanticLabel: 'Remove point ${i + 1}', tooltip: 'Remove point', onTap: () => c.removePoint(i)),
          ]),
        ),
      Align(alignment: AlignmentDirectional.centerStart, child: EmTextAction(key: const Key('ptm_new_add_point'), label: 'Add a point', icon: Icons.add_rounded, onPressed: c.points.length >= kPtmMaxPoints ? null : c.addPoint)),
      const SizedBox(height: EmSpacing.s8),
      const ParentNote(text: "The meeting is booked with the student's guardian and starts as 'Requested'. The guardian is notified by the school system; you never see their phone number or email."),
    ]);
  }

  Widget _time(String label, String key, String? value, String? err, ValueChanged<String> set, BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormLabel(label),
        PickField(fieldKey: Key(key), icon: Icons.schedule_rounded, text: value ?? 'Choose', filled: value != null, error: err, onTap: () async {
          final p = await pickHm(context, initial: value);
          if (p != null) set(p);
        }),
        if (err != null) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: _error(err)),
      ]);

  /// A validation message: glyph + words in the error colour (readable at 1.3x, wraps instead of clipping).
  Widget _error(String text, {Key? key}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: EmSpacing.s2), child: Icon(Icons.error_outline_rounded, size: 16, color: EmColors.error)),
        const SizedBox(width: EmSpacing.s4),
        Expanded(child: Text(text, key: key, style: EmType.caption.copyWith(color: EmColors.error, fontWeight: FontWeight.w600))),
      ]);

  Widget _bottom(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12),
          decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
          child: Obx(() => EmPrimaryButton(
                key: const Key('ptm_new_submit'),
                label: 'Schedule meeting',
                loading: c.saving.value,
                onPressed: c.saving.value ? null : () => _submit(context),
              )),
        ),
      );

  Future<void> _submit(BuildContext context) async {
    final r = await c.submit();
    if (!context.mounted) return;
    switch (r) {
      case PtmCreated(:final meeting):
        _snack(context, 'Meeting scheduled.');
        Get.offNamed(Routes.ptmDetailOf(meeting.id));
      case PtmCreateInvalid(:final errors):
        _snack(context, errors.values.first);
      case PtmCreateFailed(:final text):
        _snack(context, text);
      case PtmCreateIgnored():
        break;
    }
  }

  Future<void> _pickStudent(BuildContext context) async {
    c.picker.load();
    await showAppSheet<void>(
      context,
      (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * 0.85, child: StudentPickerSheet(picker: c.picker, onPick: (s) => c.selectStudent(s))),
    );
  }
}

/// A small info note (glyph + words on the info tint).
class ParentNote extends StatelessWidget {
  final String text;
  const ParentNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) => EmInfoBanner(text: text, tone: EmTone.info, icon: Icons.info_outline_rounded);
}
