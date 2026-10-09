import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/models/staff_me.dart';
import '../../../../core/services/avatar_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';

String roleLabel(String role) {
  if (role.isEmpty) return '';
  final words = role.replaceAll('_', ' ').replaceAll('-', ' ').split(' ').where((w) => w.isNotEmpty);
  return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}

/// Profile (`/profile`): read-only details + the profile photo, then Help / About / Delete account.
class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({super.key});
  ProfileController get c => controller;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () => c.load(userInitiated: true),
        child: Obx(() {
          final me = auth.staffMe.value;
          final user = auth.user.value;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _header(context, user?.name ?? '', user?.initials ?? '--', user?.avatarUrl, roleLabel(user?.role ?? ''), me),
              const SizedBox(height: 12),
              _photoActions(context),
              _outcome(context),
              const SizedBox(height: 8),
              ..._details(me, auth),
              const SizedBox(height: 8),
              const SubHeadingText('Settings'),
              _nav(Icons.help_outline_rounded, 'Help', 'Guides and support', Routes.help, const Key('profile_help')),
              _nav(Icons.info_outline_rounded, 'About', 'App version', Routes.about, const Key('profile_about')),
              _nav(Icons.person_remove_outlined, 'Delete account', 'Ask the school to delete your account', Routes.deleteAccount, const Key('profile_delete_account'), danger: true),
            ],
          );
        }),
      ),
    );
  }

  Widget _header(BuildContext context, String name, String initials, String? url, String role, StaffMe? me) {
    final local = c.localPreviewPath.value;
    Widget img;
    if (local != null && File(local).existsSync()) {
      img = Image.file(File(local), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials(initials));
    } else if (url != null && url.isNotEmpty) {
      img = Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials(initials));
    } else {
      img = _initials(initials);
    }
    return Column(children: [
      Container(key: const Key('profile_avatar'), width: 96, height: 96, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.line, width: 2)), child: img),
      const SizedBox(height: 10),
      CustomText(key: const Key('profile_name'), text: name.isEmpty ? 'Teacher' : name, fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
      if (role.isNotEmpty) CustomText(text: role, fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
    ]);
  }

  Widget _initials(String t) => Center(child: CustomText(text: t, fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryColor));

  Widget _photoActions(BuildContext context) => Obx(() {
        final busy = c.avatarBusy.value;
        final off = busy || c.uploadUnavailable.value;
        return Row(children: [
          Expanded(child: OutlinedButton.icon(key: const Key('avatar_gallery'), onPressed: off ? null : () => c.choosePhoto(AvatarSource.gallery), icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Choose photo'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(key: const Key('avatar_camera'), onPressed: off ? null : () => c.choosePhoto(AvatarSource.camera), icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('Take photo'))),
        ]);
      });

  Widget _outcome(BuildContext context) => Obx(() {
        if (c.avatarBusy.value) {
          return const Padding(padding: EdgeInsets.only(top: 10), child: Row(key: Key('avatar_busy'), children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), CustomText(text: 'Uploading your photo...', fontSize: 12, color: AppColors.muted)]));
        }
        final o = c.outcome.value;
        final msg = c.outcomeMessage.value;
        if (o == AvatarOutcome.none || msg == null) return const SizedBox.shrink();
        final ok = o == AvatarOutcome.uploaded;
        final title = o == AvatarOutcome.unavailable ? 'Upload unavailable' : null;
        return Container(
          key: Key('avatar_outcome_${o.name}'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ok ? AppColors.greenBg : AppColors.redBg, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) CustomText(text: title, fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.redText),
            CustomText(text: msg, fontSize: 12, color: ok ? AppColors.greenText : AppColors.redText, fontWeight: FontWeight.w600, height: 1.35),
            if (o == AvatarOutcome.denied) Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('avatar_open_settings'), onPressed: openAppSettings, child: const Text('Open Settings'))),
          ]),
        );
      });

  List<Widget> _details(StaffMe? me, AuthController auth) {
    final user = auth.user.value;
    final tp = me?.teacherProfile;
    final classTeacher = tp?.classTeacherOf?.displayName ?? '';
    final subjects = {...?tp?.subjectsCanTeach, ...?tp?.currentAssignments.map((a) => a.subjectName ?? '').where((s) => s.isNotEmpty)}.toList();
    return [
      const SubHeadingText('Account'),
      _card([
        _kv('Email', user?.email ?? '', const Key('profile_email')),
        _kv('Role', roleLabel(user?.role ?? ''), null),
        _kv('School', me?.institution.name ?? auth.institution.value?.name ?? '', null),
      ]),
      if (me != null) ...[
        const SubHeadingText('Work'),
        _card([
          _kv('Campus', me.campus?.name ?? '', const Key('profile_campus')),
          _kv('Department', me.department ?? '', const Key('profile_department')),
          _kv('Designation', tp?.designation ?? '', const Key('profile_designation')),
          _kv('Employee ID', tp?.employeeId ?? '', null),
        ]),
        const SubHeadingText('Teaching'),
        _card([
          _kv('Class teacher of', classTeacher.isEmpty ? (tp?.isClassTeacher == true ? 'Yes' : '') : classTeacher, const Key('profile_class_teacher')),
          _kv('Subjects', subjects.join(', '), const Key('profile_subjects')),
          _kv('Grades', (tp?.gradeLevelsCanTeach ?? const <String>[]).join(', '), null),
          for (final a in tp?.currentAssignments ?? const [])
            _kv('${a.gradeLevel ?? ''}${(a.sectionName ?? '').isEmpty ? '' : ' - ${a.sectionName}'}', [if ((a.subjectName ?? '').isNotEmpty) a.subjectName!, if (a.periodsPerWeek != null) '${a.periodsPerWeek} periods/week'].join(' · '), null),
        ]),
      ],
      const Padding(padding: EdgeInsets.only(top: 6, bottom: 4), child: CustomText(key: Key('profile_readonly_note'), text: 'These details are managed by your school. To change them, contact your school administration.', fontSize: 11.5, color: AppColors.muted, height: 1.4)),
    ];
  }

  Widget _card(List<Widget> rows) {
    final shown = rows.where((r) => r is! SizedBox).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return AppCard(child: Column(children: shown));
  }

  /// A row, or nothing when the server sent no value (never "N/A" filler).
  Widget _kv(String k, String v, Key? key) {
    if (v.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 108, child: CustomText(text: k, fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
        Expanded(child: CustomText(key: key, text: v, fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _nav(IconData icon, String title, String sub, String route, Key key, {bool danger = false}) => ListCardRow(
        key: key,
        icon: icon,
        iconColor: danger ? AppColors.redText : AppColors.blue,
        title: title,
        subtitle: sub,
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
        onTap: () => Get.toNamed(route),
      );
}

class SubHeadingText extends StatelessWidget {
  final String text;
  const SubHeadingText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: CustomText(text: text, color: AppColors.primaryColor, fontSize: 13, fontWeight: FontWeight.w800));
}
