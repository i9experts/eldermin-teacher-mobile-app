import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/models/early_years/ece_models.dart';

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
