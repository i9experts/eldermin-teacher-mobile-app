import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/models/early_years/ece_models.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/utils/early_years_format.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../controllers/early_years_child_controller.dart' show DomainProgress;

/// Round avatar of an Early Years child: the photo when the backend sent an http(s) url, else initials.
class EceChildAvatar extends StatelessWidget {
  final EceChild child;
  final double size;
  const EceChildAvatar({super.key, required this.child, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final url = child.photoUrl;
    return EmAvatar(initials: child.initials, imageUrl: (url == null || !url.startsWith('http')) ? null : url, size: size);
  }
}

/// One row of the Early Years list: name, class and the school's student id. [onTap] null = not tappable (no chevron).
class EceChildTile extends StatelessWidget {
  final EceChild child;
  final VoidCallback? onTap;
  const EceChildTile({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sub = [if (child.classLabel.isNotEmpty) child.classLabel, if (child.studentCode.isNotEmpty) child.studentCode].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.s8),
      child: EmListRow(
        key: ValueKey('ey_child_${child.id}'),
        leading: EceChildAvatar(child: child),
        title: child.fullName.isEmpty ? 'Child' : child.fullName,
        subtitle: sub.isEmpty ? null : sub,
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

/// One domain of development: its name, the current level (a bar when the level is one of the framework's), how much evidence and when.
class EceDomainProgressTile extends StatelessWidget {
  final DomainProgress progress;
  const EceDomainProgressTile({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final meta = [
      '${p.evidenceCount} ${p.evidenceCount == 1 ? 'observation' : 'observations'}',
      if (p.lastObservedAt != null) 'last ${shortDay(p.lastObservedAt!.toLocal())}',
    ].join(' · ');
    return AppCard(
      key: ValueKey('ey_domain_${p.domainId}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.name, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          if (p.level.isNotEmpty) AppTag(p.level, style: EmTone.info),
        ]),
        if (p.fraction != null) ...[
          const SizedBox(height: EmSpacing.s8),
          AppProgressBar(percent: (p.fraction! * 100).round()),
        ],
        const SizedBox(height: EmSpacing.s8),
        Text(meta, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
      ]),
    );
  }
}

/// A row of photos of an observation or portfolio entry. Each photo gets a signed link on demand; "Photo unavailable" when it cannot be had.
/// Anything that is not a photo (video, voice note, document) is listed by name only: v1 does not play it.
class EceEvidenceStrip extends StatelessWidget {
  final List<EceEvidence> evidence;
  final Future<String?> Function(EceEvidence) resolve;
  const EceEvidenceStrip({super.key, required this.evidence, required this.resolve});

  static const double thumb = 88;

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) return const SizedBox.shrink();
    final photos = evidence.where((e) => e.isPhoto).toList();
    final others = evidence.where((e) => !e.isPhoto).toList();
    return Padding(
      padding: const EdgeInsets.only(top: EmSpacing.s8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (photos.isNotEmpty)
          SizedBox(
            height: thumb,
            child: ListView.separated(
              key: const Key('ey_photos'),
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: EmSpacing.s8),
              itemBuilder: (_, i) => EcePhotoThumb(evidence: photos[i], resolve: resolve),
            ),
          ),
        for (final o in others)
          Padding(
            padding: const EdgeInsets.only(top: EmSpacing.s4),
            child: Text('${_typeLabel(o.type)} attached (not shown in the app yet)', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ),
      ]),
    );
  }

  static String _typeLabel(String t) => switch (t) {
        'video' => 'Video',
        'voice_note' => 'Voice note',
        'document' => 'Document',
        'work_sample' => 'Work sample',
        _ => 'File',
      };
}

class EcePhotoThumb extends StatefulWidget {
  final EceEvidence evidence;
  final Future<String?> Function(EceEvidence) resolve;
  const EcePhotoThumb({super.key, required this.evidence, required this.resolve});

  @override
  State<EcePhotoThumb> createState() => _EcePhotoThumbState();
}

class _EcePhotoThumbState extends State<EcePhotoThumb> {
  // one lookup per thumbnail, not one per rebuild (a new Future every build would flash the placeholder)
  late final Future<String?> _url = widget.resolve(widget.evidence);
  EceEvidence get evidence => widget.evidence;

  Widget _placeholder(String text) => Container(
        width: EceEvidenceStrip.thumb,
        height: EceEvidenceStrip.thumb,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(EmSpacing.s4),
        decoration: const BoxDecoration(color: EmColors.background, borderRadius: EmRadius.smAll),
        child: Text(text, textAlign: TextAlign.center, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _placeholder('Loading…');
        final url = snap.data;
        if (url == null) return _placeholder('Photo unavailable');
        return InkWell(
          key: const Key('ey_photo'),
          borderRadius: EmRadius.smAll,
          onTap: () => showEcePhoto(context, url, evidence.caption),
          child: ClipRRect(
            borderRadius: EmRadius.smAll,
            child: Image.network(
              url,
              width: EceEvidenceStrip.thumb,
              height: EceEvidenceStrip.thumb,
              fit: BoxFit.cover,
              semanticLabel: evidence.caption.isEmpty ? 'Photo' : evidence.caption,
              errorBuilder: (_, __, ___) => _placeholder('Photo unavailable'),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen, pinch-to-zoom view of one photo. In-memory only: a signed link is never written to disk.
Future<void> showEcePhoto(BuildContext context, String url, String caption) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: EmColors.ink,
      child: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            child: Center(
              child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text('Photo unavailable', style: EmType.body.copyWith(color: EmColors.onPrimary))),
            ),
          ),
        ),
        if (caption.isNotEmpty)
          Positioned(left: 0, right: 0, bottom: 0, child: ColoredBox(color: EmColors.ink, child: Padding(padding: const EdgeInsets.all(EmSpacing.s16), child: Text(caption, style: EmType.body.copyWith(color: EmColors.onPrimary))))),
        Positioned(
          top: EmSpacing.s16,
          right: EmSpacing.s16,
          child: SafeArea(child: IconButton(key: const Key('ey_photo_close'), tooltip: 'Close', icon: const Icon(Icons.close_rounded, color: EmColors.onPrimary), onPressed: () => Navigator.of(ctx).pop())),
        ),
      ]),
    ),
  );
}

/// "Shared with the family" / "Private" marker (what the backend stored; see [EcePortfolioEntry.visibleToFamily]).
class EceShareTag extends StatelessWidget {
  final bool shared;
  const EceShareTag({super.key, required this.shared});
  @override
  Widget build(BuildContext context) => AppTag(shared ? 'SHARED WITH FAMILY' : 'PRIVATE', style: shared ? EmTone.success : EmTone.neutral);
}

class EceObservationCard extends StatelessWidget {
  final EceObservation observation;
  final Map<String, String> skillNames;
  final Future<String?> Function(EceEvidence) resolve;
  const EceObservationCard({super.key, required this.observation, required this.skillNames, required this.resolve});

  @override
  Widget build(BuildContext context) {
    final o = observation;
    final meta = [if (o.createdAt != null) shortDay(o.createdAt!.toLocal()), if (o.observedBy.isNotEmpty) o.observedBy].join(' · ');
    return AppCard(
      key: ValueKey('ey_obs_${o.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          AppTag(observationTypeLabel(o.type).toUpperCase(), style: EmTone.neutral),
          EceShareTag(shared: o.sharedWithFamily),
          if (meta.isNotEmpty) Text(meta, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ]),
        if (o.narrative.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s8),
          Text(o.narrative, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.4)),
        ],
        if (o.skills.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s8),
          Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, children: [
            for (final s in o.skills) AppTag(skillNames[s.skillId] == null ? s.level : '${skillNames[s.skillId]} · ${s.level}', style: EmTone.info),
          ]),
        ],
        if (o.nextStep.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s8),
          Text('Next step: ${o.nextStep}', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ],
        EceEvidenceStrip(evidence: o.evidence, resolve: resolve),
      ]),
    );
  }
}

class EcePortfolioCard extends StatelessWidget {
  final EcePortfolioEntry entry;
  final Future<String?> Function(EceEvidence) resolve;
  const EcePortfolioCard({super.key, required this.entry, required this.resolve});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return AppCard(
      key: ValueKey('ey_entry_${e.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(e.title.isEmpty ? 'Portfolio entry' : e.title, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          EceShareTag(shared: e.visibleToFamily),
        ]),
        if (e.createdAt != null)
          Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: Text(fullDay(e.createdAt!.toLocal()), style: EmType.caption.copyWith(color: EmColors.textSecondary))),
        if (e.narrative.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s8),
          Text(e.narrative, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.4)),
        ],
        if (e.tryThisAtHome.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s8),
          EmInfoBanner(key: const Key('ey_try_home'), tone: EmTone.info, icon: Icons.home_outlined, text: 'Try this at home: ${e.tryThisAtHome}'),
        ],
        EceEvidenceStrip(evidence: e.evidence, resolve: resolve),
      ]),
    );
  }
}
