import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../students/views/widgets/student_widgets.dart';
import '../controllers/ptm_create_controller.dart';
import 'widgets/ptm_widgets.dart';

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
      child: Scaffold(
        appBar: AppBar(title: const Text('New meeting')),
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
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      if (f != null) ErrorBanner(bannerKey: const Key('ptm_new_error'), message: f.serverMessage.isNotEmpty ? f.serverMessage : f.message),
      if (e['teacher'] != null) ErrorBanner(bannerKey: const Key('ptm_new_teacher_error'), message: e['teacher']!),
      FormLabel('Student *', error: e['student']),
      InkWell(
        key: const Key('ptm_new_student'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _pickStudent(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: e['student'] == null && e['year'] == null ? AppColors.line : AppColors.redText)),
          child: Row(children: [
            if (s != null) ...[StudentAvatar(student: s, size: 34), const SizedBox(width: 10)] else const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.person_search_rounded, color: AppColors.primaryColor)),
            Expanded(
              child: s == null
                  ? const CustomText(text: 'Choose a student from your classes', color: AppColors.faint, fontSize: 13)
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CustomText(key: const Key('ptm_new_selected'), text: s.fullName, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13),
                      CustomText(text: s.classLabel, color: AppColors.muted, fontSize: 11),
                    ]),
            ),
            const Icon(Icons.expand_more_rounded, color: AppColors.muted),
          ]),
        ),
      ),
      if (e['year'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(key: const Key('ptm_new_year_error'), text: e['year']!, color: AppColors.redText, fontSize: 11.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
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
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _time('Start *', 'ptm_new_start', c.start.value, e['start'], c.setStart, context)),
        const SizedBox(width: 12),
        Expanded(child: _time('End *', 'ptm_new_end', c.end.value, e['end'], c.setEnd, context)),
      ]),
      const SizedBox(height: 14),
      FormLabel('Discussion points', error: e['points']),
      for (var i = 0; i < c.points.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: TextField(key: Key('ptm_new_point_$i'), controller: c.points[i], maxLength: kPtmPointMax, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(isDense: true, hintText: 'e.g. Progress in maths', counterText: '', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))))),
            IconButton(key: Key('ptm_new_point_remove_$i'), icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => c.removePoint(i)),
          ]),
        ),
      TextButton.icon(key: const Key('ptm_new_add_point'), onPressed: c.points.length >= kPtmMaxPoints ? null : c.addPoint, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add a point')),
      const SizedBox(height: 8),
      const ParentNote(text: "The meeting is booked with the student's guardian and starts as 'Requested'. The guardian is notified by the school system; you never see their phone number or email."),
    ]);
  }

  Widget _time(String label, String key, String? value, String? err, ValueChanged<String> set, BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormLabel(label),
        PickField(fieldKey: Key(key), icon: Icons.schedule_rounded, text: value ?? 'Choose', filled: value != null, error: err, onTap: () async {
          final p = await pickHm(context, initial: value);
          if (p != null) set(p);
        }),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: err, color: AppColors.redText, fontSize: 11, fontWeight: FontWeight.w600)),
      ]);

  Widget _bottom(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
          child: SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  key: const Key('ptm_new_submit'),
                  onPressed: c.saving.value ? null : () => _submit(context),
                  child: c.saving.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const CustomText(text: 'Schedule meeting', color: Colors.white, fontWeight: FontWeight.w700),
                )),
          ),
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

/// A small muted info note.
class ParentNote extends StatelessWidget {
  final String text;
  const ParentNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.blue),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: text, fontSize: 11.5, color: AppColors.muted, height: 1.35)),
        ]),
      );
}
