import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../core/design/design.dart';
import '../../controllers/evidence_photos.dart';
import '../../controllers/quick_observe_controller.dart' show EyRefs;

/// Learning area -> skill -> level chips. Used by the quick and the full observation forms.
class EySkillPicker extends StatelessWidget {
  final EyRefs refs;
  final String? domainId;
  final String? skillId;
  final String? level;
  final ValueChanged<String> onDomain;
  final ValueChanged<String> onSkill;
  final ValueChanged<String> onLevel;
  final String? skillError;
  final String? levelError;
  final bool required;
  const EySkillPicker({
    super.key,
    required this.refs,
    required this.domainId,
    required this.skillId,
    required this.level,
    required this.onDomain,
    required this.onSkill,
    required this.onLevel,
    this.skillError,
    this.levelError,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    final domains = refs.domains.where((d) => refs.skillsOf(d.id).isNotEmpty).toList();
    final skills = refs.skillsOf(domainId);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      EyLabel(required ? 'Learning area *' : 'Learning area'),
      Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
        for (final d in domains) EmChip(key: Key('ey_dom_${d.id}'), label: d.name, selected: domainId == d.id, onTap: () => onDomain(d.id)),
      ]),
      const SizedBox(height: EmSpacing.block),
      if (domainId != null) ...[
        EyLabel(required ? 'Skill *' : 'Skill', error: skillError),
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
          for (final s in skills) EmChip(key: Key('ey_skill_${s.id}'), label: s.name, selected: skillId == s.id, onTap: () => onSkill(s.id)),
        ]),
        const SizedBox(height: EmSpacing.block),
      ] else if (skillError != null)
        Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s8), child: Text(skillError!, style: EmType.caption.copyWith(color: EmColors.error))),
      EyLabel(required ? 'Level *' : 'Level', error: levelError),
      Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
        for (final l in refs.levels) EmChip(key: Key('ey_lvl_$l'), label: l, selected: level == l, onTap: () => onLevel(l)),
      ]),
      const SizedBox(height: EmSpacing.block),
    ]);
  }
}

/// The photos of a form: "Add photos", a thumbnail per photo with its upload state, retry and remove.
class EyPhotosSection extends StatelessWidget {
  final EvidencePhotos photos;
  final String? error;
  const EyPhotosSection({super.key, required this.photos, this.error});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = photos.photos.toList();
      final notice = photos.notice.value;
      final unavailable = photos.unavailable.value;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EyLabel('Photos', error: error),
        if (unavailable)
          const Padding(
            padding: EdgeInsets.only(bottom: EmSpacing.s8),
            child: EmInfoBanner(key: Key('ey_upload_unavailable'), tone: EmTone.warning, icon: Icons.cloud_off_rounded, text: 'Photo uploads are not available on this server right now. You can still save without photos.'),
          ),
        if (notice != null) Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s8), child: Text(notice, key: const Key('ey_photo_notice'), style: EmType.caption.copyWith(color: EmColors.error))),
        if (list.isNotEmpty)
          Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [for (final p in list) _PhotoChip(photos: photos, photo: p)]),
        if (list.length < EvidencePhotos.maxPhotos)
          Padding(
            padding: const EdgeInsets.only(top: EmSpacing.s8),
            child: EmSecondaryButton(key: const Key('ey_add_photos'), label: list.isEmpty ? 'Add photos' : 'Add more photos', icon: Icons.add_photo_alternate_outlined, onPressed: photos.pick),
          ),
        const SizedBox(height: EmSpacing.block),
      ]);
    });
  }
}

class _PhotoChip extends StatelessWidget {
  final EvidencePhotos photos;
  final EyPhoto photo;
  const _PhotoChip({required this.photos, required this.photo});

  static const double size = 88;

  @override
  Widget build(BuildContext context) {
    final failed = photo.status == EyPhotoStatus.failed;
    return SizedBox(
      key: ValueKey('ey_photo_${photo.id}'),
      width: size,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          ClipRRect(
            borderRadius: EmRadius.smAll,
            child: SizedBox(
              width: size,
              height: size,
              child: Image.file(File(photo.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: EmColors.background, child: Icon(Icons.image_outlined, color: EmColors.textSecondary))),
            ),
          ),
          if (photo.status == EyPhotoStatus.uploading)
            Positioned.fill(
              child: ColoredBox(
                color: EmColors.ink.withValues(alpha: 0.35),
                child: Center(child: SizedBox(width: EmSpacing.s24, height: EmSpacing.s24, child: CircularProgressIndicator(value: photo.progress > 0 && photo.progress < 1 ? photo.progress : null, strokeWidth: 3, color: EmColors.onPrimary))),
              ),
            ),
          if (photo.status == EyPhotoStatus.done)
            const Positioned(left: EmSpacing.s4, bottom: EmSpacing.s4, child: Icon(Icons.check_circle_rounded, size: 20, color: EmColors.onPrimary)),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: Key('ey_photo_remove_${photo.id}'),
              tooltip: 'Remove photo',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.cancel_rounded, color: EmColors.onPrimary),
              onPressed: photo.status == EyPhotoStatus.uploading ? null : () => photos.remove(photo.id),
            ),
          ),
        ]),
        if (failed)
          TextButton(key: Key('ey_photo_retry_${photo.id}'), onPressed: () => photos.retry(photo.id), child: Text('Retry', style: EmType.label.copyWith(color: EmColors.error))),
      ]),
    );
  }
}

/// "Share with the family" switch, OFF by default, with a line saying what it does.
class EyShareSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String note;
  const EyShareSwitch({super.key, required this.value, required this.onChanged, required this.note});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.block),
        child: EmCard(
        child: SwitchListTile(
          key: const Key('ey_share_switch'),
          contentPadding: EdgeInsets.zero,
          title: Text('Share with the family', style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
          subtitle: Text(note, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          value: value,
          onChanged: onChanged,
        ),
        ),
      );
}

/// Section that explains why a form cannot be used (no permission, child not in my classes).
class EyBlockedView extends StatelessWidget {
  final String message;
  const EyBlockedView({super.key, required this.message});
  @override
  Widget build(BuildContext context) => EmEmptyState(key: const Key('ey_blocked'), icon: Icons.lock_outline_rounded, title: "You can't add this", message: message);
}

/// A form label above a chip group, with an inline error line.
class EyLabel extends StatelessWidget {
  final String text;
  final String? error;
  const EyLabel(this.text, {super.key, this.error});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.textSecondary)),
          if (error != null) Text(error!, style: EmType.caption.copyWith(color: EmColors.error)),
        ]),
      );
}

/// Multi-line text field in the form style.
Widget eyField({required String label, required TextEditingController controller, required Key fieldKey, int maxLines = 1, String? hint, String? error, ValueChanged<String>? onChanged}) => Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.block),
      child: EmTextField(key: fieldKey, label: label, controller: controller, hint: hint, errorText: error, maxLines: maxLines, onChanged: onChanged, textCapitalization: TextCapitalization.sentences),
    );
