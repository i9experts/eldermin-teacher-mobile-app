import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/models/early_years/ece_models.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/utils/early_years_format.dart';
import '../../../../../core/widgets/detail_bottom_sheet.dart';
import '../../controllers/early_years_child_controller.dart' show DomainProgress, EcePhotoLinks;

/// Round avatar of an Early Years child: the photo when the backend sent an http(s) url, else initials.
class EceChildAvatar extends StatelessWidget {
  final EceChild child;
  final double size;
  const EceChildAvatar({super.key, required this.child, this.size = EmSpacing.s48});

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

/// One domain of development: a ring when the level is one of the framework's, the level name, how much evidence and when.
class EceDomainProgressTile extends StatelessWidget {
  final DomainProgress progress;
  const EceDomainProgressTile({super.key, required this.progress});

  static const double ringSize = 64;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final meta = [
      '${p.evidenceCount} ${p.evidenceCount == 1 ? 'observation' : 'observations'}',
      if (p.lastObservedAt != null) 'last ${shortDay(p.lastObservedAt!.toLocal())}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.s8),
      child: EmCard(
        key: ValueKey('ey_domain_${p.domainId}'),
        child: Row(children: [
          if (p.fraction != null) ...[
            EmProgressRing(key: ValueKey('ey_ring_${p.domainId}'), value: p.fraction!, size: ringSize, strokeWidth: EmSpacing.s8, semanticLabel: '${p.name}: ${p.level}'),
            const SizedBox(width: EmSpacing.row),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
              if (p.level.isNotEmpty) ...[
                const SizedBox(height: EmSpacing.s4),
                Align(alignment: AlignmentDirectional.centerStart, child: EmChip.status(label: p.level, tone: EmTone.info)),
              ],
              const SizedBox(height: EmSpacing.s4),
              Text(meta, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// "Shared with the family" / "Private" marker (what the backend stored; see [EcePortfolioEntry.visibleToFamily]).
class EceShareTag extends StatelessWidget {
  final bool shared;
  const EceShareTag({super.key, required this.shared});
  @override
  Widget build(BuildContext context) => EmChip.status(label: shared ? 'Shared with family' : 'Private', tone: shared ? EmTone.success : EmTone.neutral);
}

/// An observation in the list: type, share state, a two-line preview. Tapping opens its detail sheet ([onTap]).
class EceObservationRow extends StatelessWidget {
  final EceObservation observation;
  final VoidCallback onTap;
  const EceObservationRow({super.key, required this.observation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final o = observation;
    final meta = [if (o.createdAt != null) shortDay(o.createdAt!.toLocal()), if (o.observedBy.isNotEmpty) o.observedBy].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.s8),
      child: EmCard(
        key: ValueKey('ey_obs_${o.id}'),
        onTap: onTap,
        semanticLabel: 'Observation: ${observationTypeLabel(o.type)}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            EmChip.status(label: observationTypeLabel(o.type), tone: EmTone.neutral),
            EceShareTag(shared: o.sharedWithFamily),
          ]),
          if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text(meta, style: EmType.caption.copyWith(color: EmColors.textSecondary))),
          if (o.narrative.isNotEmpty) ...[
            const SizedBox(height: EmSpacing.s8),
            Text(o.narrative, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.ink)),
          ],
        ]),
      ),
    );
  }
}

/// A portfolio entry in the list. Tapping opens its detail sheet ([onTap]).
class EcePortfolioRow extends StatelessWidget {
  final EcePortfolioEntry entry;
  final VoidCallback onTap;
  const EcePortfolioRow({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.s8),
      child: EmCard(
        key: ValueKey('ey_entry_${e.id}'),
        onTap: onTap,
        semanticLabel: 'Portfolio entry: ${e.title}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title.isEmpty ? 'Portfolio entry' : e.title, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
          if (e.createdAt != null) Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: Text(fullDay(e.createdAt!.toLocal()), style: EmType.caption.copyWith(color: EmColors.textSecondary))),
          const SizedBox(height: EmSpacing.s8),
          EceShareTag(shared: e.visibleToFamily),
          if (e.narrative.isNotEmpty) ...[
            const SizedBox(height: EmSpacing.s8),
            Text(e.narrative, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.ink)),
          ],
        ]),
      ),
    );
  }
}

String _count(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

/// Sheet content of an observation. [photos] null = the photo links are still being fetched (the sheet shows its loading state);
/// non-photo evidence (video, voice note, document) is only counted: v1 does not play it.
DetailSheetData observationSheetData(EceObservation o, Map<String, String> skillNames, EcePhotoLinks? photos) {
  final others = o.evidence.where((e) => !e.isPhoto).length;
  return DetailSheetData(
    title: observationTypeLabel(o.type),
    statusLabel: o.sharedWithFamily ? 'Shared with family' : 'Private',
    statusTone: o.sharedWithFamily ? EmTone.success : EmTone.neutral,
    state: photos == null ? DetailSheetState.loading : DetailSheetState.ready,
    notice: photos != null && photos.failed > 0 ? '${_count(photos.failed, 'photo')} could not be opened. Close and reopen this to try again.' : null,
    fields: [
      DetailField('Date', o.createdAt == null ? null : fullDay(o.createdAt!.toLocal())),
      DetailField('Observed by', o.observedBy),
      DetailField('Next step', o.nextStep),
      DetailField('Skills', o.skills.isEmpty ? null : o.skills.map((s) => skillNames[s.skillId] == null ? s.level : '${skillNames[s.skillId]} · ${s.level}').join('\n')),
      DetailField('Other files', others == 0 ? null : '${_count(others, 'file')} attached (not shown in the app yet)'),
    ],
    longTextLabel: 'What was observed',
    longText: o.narrative,
    attachments: photos?.items ?? const [],
  );
}

DetailSheetData portfolioSheetData(EcePortfolioEntry e, EcePhotoLinks? photos) {
  final others = e.evidence.where((x) => !x.isPhoto).length;
  return DetailSheetData(
    title: e.title.isEmpty ? 'Portfolio entry' : e.title,
    statusLabel: e.visibleToFamily ? 'Shared with family' : 'Private',
    statusTone: e.visibleToFamily ? EmTone.success : EmTone.neutral,
    state: photos == null ? DetailSheetState.loading : DetailSheetState.ready,
    notice: photos != null && photos.failed > 0 ? '${_count(photos.failed, 'photo')} could not be opened. Close and reopen this to try again.' : null,
    fields: [
      DetailField('Date', e.createdAt == null ? null : fullDay(e.createdAt!.toLocal())),
      DetailField('Try this at home', e.tryThisAtHome),
      DetailField('Other files', others == 0 ? null : '${_count(others, 'file')} attached (not shown in the app yet)'),
    ],
    longTextLabel: 'What happened',
    longText: e.narrative,
    attachments: photos?.items ?? const [],
  );
}
