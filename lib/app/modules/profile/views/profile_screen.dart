import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/models/staff_me.dart';
import '../../../../core/services/avatar_picker.dart';
import '../../../../core/widgets/app_widgets.dart' show AppCard, ListCardRow;
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../../../../core/design/design.dart';

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
    return EmScaffold(
      appBar: EmAppBar(title: 'Profile'),
      body: RefreshIndicator(
        onRefresh: () => c.load(userInitiated: true),
        child: Obx(() {
          final me = auth.staffMe.value;
          final user = auth.user.value;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s24),
            children: [
              _header(context, user?.name ?? '', user?.initials ?? '--', user?.avatarUrl, roleLabel(user?.role ?? ''), me),
              const SizedBox(height: EmSpacing.s16),
              _photoActions(context),
              _outcome(context),
              const SizedBox(height: EmSpacing.s8),
              ..._details(me, auth),
              const SizedBox(height: EmSpacing.s8),
              const SubHeadingText('Settings'),
              _nav(Icons.help_outline_rounded, 'Help', 'Guides and support', Routes.help, const Key('profile_help')),
              _nav(Icons.info_outline_rounded, 'About', 'App version', Routes.about, const Key('profile_about')),
              _nav(Icons.person_remove_outlined, 'Request account deletion', 'Ask the school to delete your account', Routes.deleteAccount, const Key('profile_delete_account'), danger: true),
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
      Container(key: const Key('profile_avatar'), width: 96, height: 96, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: EmColors.primaryTint, borderRadius: EmRadius.heroAll, border: Border.all(color: EmColors.border, width: 2)), child: img),
      const SizedBox(height: EmSpacing.s12),
      Text(name.isEmpty ? 'Teacher' : name, key: const Key('profile_name'), textAlign: TextAlign.center, style: EmType.heading.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink)),
      if (role.isNotEmpty) Text(role, style: EmType.label.copyWith(color: EmColors.textSecondary)),
    ]);
  }

  Widget _initials(String t) => Center(child: Text(t, style: EmType.display.copyWith(fontWeight: FontWeight.w800, color: EmColors.primary)));

  Widget _photoActions(BuildContext context) => Obx(() {
        final busy = c.avatarBusy.value;
        final off = busy || c.uploadUnavailable.value;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: EmSecondaryButton(key: const Key('avatar_gallery'), label: 'Choose photo', icon: Icons.photo_library_outlined, expand: true, onPressed: off ? null : () => c.choosePhoto(AvatarSource.gallery))),
          const SizedBox(width: EmSpacing.row),
          Expanded(child: EmSecondaryButton(key: const Key('avatar_camera'), label: 'Take photo', icon: Icons.photo_camera_outlined, expand: true, onPressed: off ? null : () => c.choosePhoto(AvatarSource.camera))),
        ]);
      });

  Widget _outcome(BuildContext context) => Obx(() {
        if (c.avatarBusy.value) {
          return Padding(padding: const EdgeInsets.only(top: EmSpacing.s12), child: Row(key: const Key('avatar_busy'), children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: EmSpacing.s12), Expanded(child: Text('Uploading your photo...', style: EmType.label.copyWith(color: EmColors.textSecondary)))]));
        }
        final o = c.outcome.value;
        final msg = c.outcomeMessage.value;
        if (o == AvatarOutcome.none || msg == null) return const SizedBox.shrink();
        final ok = o == AvatarOutcome.uploaded;
        final title = o == AvatarOutcome.unavailable ? 'Upload unavailable' : null;
        final tone = ok ? EmTone.success : EmTone.error;
        return Container(
          key: Key('avatar_outcome_${o.name}'),
          margin: const EdgeInsets.only(top: EmSpacing.s12),
          padding: const EdgeInsets.all(EmSpacing.s12),
          decoration: BoxDecoration(color: tone.background, borderRadius: EmRadius.mdAll),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 20, color: tone.foreground),
            const SizedBox(width: EmSpacing.s8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (title != null) Text(title, style: EmType.label.copyWith(fontWeight: FontWeight.w800, color: tone.foreground)),
                Text(msg, style: EmType.label.copyWith(color: tone.foreground, fontWeight: FontWeight.w600)),
                if (o == AvatarOutcome.denied) Align(alignment: AlignmentDirectional.centerStart, child: EmTextAction(key: const Key('avatar_open_settings'), label: 'Open Settings', onPressed: openAppSettings)),
              ]),
            ),
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
      Padding(padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.s4), child: Text('These details are managed by your school. To change them, contact your school administration.', key: const Key('profile_readonly_note'), style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))),
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
      padding: const EdgeInsets.symmetric(vertical: EmSpacing.s8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 108, child: Text(k, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w700))),
        Expanded(child: Text(v, key: key, style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _nav(IconData icon, String title, String sub, String route, Key key, {bool danger = false}) => ListCardRow(
        key: key,
        icon: icon,
        iconColor: danger ? EmColors.error : EmColors.primary,
        title: title,
        subtitle: sub,
        trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textTertiary),
        onTap: () => Get.toNamed(route),
      );
}

class SubHeadingText extends StatelessWidget {
  final String text;
  const SubHeadingText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: EmSpacing.s8, bottom: EmSpacing.s8), child: Semantics(header: true, child: Text(text, style: EmType.label.copyWith(color: EmColors.primary, fontWeight: FontWeight.w800))));
}
