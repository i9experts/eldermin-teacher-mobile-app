import 'package:flutter/material.dart';
import '../contrast.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';
import '../widgets.dart';

/// Gallery sections are public, state-light widgets so golden tests can render
/// each one on its own. Debug-only (see `design_gallery_screen.dart`).

class GallerySectionTitle extends StatelessWidget {
  const GallerySectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(top: EmSpacing.s24, bottom: EmSpacing.s12),
        child: Semantics(header: true, child: Text(text, style: EmType.title.copyWith(color: EmColors.ink))),
      );
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(top: EmSpacing.s12, bottom: EmSpacing.s8),
        child: Text(text, style: EmType.label.copyWith(color: EmColors.textSecondary)),
      );
}

/// Colour swatches with hex and the contrast ratio of the on-colour.
class GalleryColorsSection extends StatelessWidget {
  const GalleryColorsSection({super.key});

  static const _swatches = <(String, Color, Color)>[
    ('primaryDark', EmColors.primaryDark, EmColors.onPrimaryDark),
    ('primary', EmColors.primary, EmColors.onPrimary),
    ('primaryMid', EmColors.primaryMid, EmColors.ink),
    ('primaryLight', EmColors.primaryLight, EmColors.onPrimaryLight),
    ('primaryContainer', EmColors.primaryContainer, EmColors.onPrimaryContainer),
    ('primaryTint', EmColors.primaryTint, EmColors.ink),
    ('background', EmColors.background, EmColors.ink),
    ('surface', EmColors.surface, EmColors.ink),
    ('accent', EmColors.accent, EmColors.onAccent),
    ('success', EmColors.success, EmColors.onSuccess),
    ('successContainer', EmColors.successContainer, EmColors.onSuccessContainer),
    ('error', EmColors.error, EmColors.onError),
    ('errorContainer', EmColors.errorContainer, EmColors.onErrorContainer),
    ('warning', EmColors.warning, EmColors.onWarning),
    ('warningContainer', EmColors.warningContainer, EmColors.onWarningContainer),
    ('info', EmColors.info, EmColors.onInfo),
    ('infoContainer', EmColors.infoContainer, EmColors.onInfoContainer),
    ('statusLeave', EmColors.statusLeave, EmColors.onStatusLeave),
    ('statusLeaveContainer', EmColors.statusLeaveContainer, EmColors.onStatusLeaveContainer),
    ('ink', EmColors.ink, EmColors.surface),
    ('textSecondary', EmColors.textSecondary, EmColors.surface),
    ('textTertiary', EmColors.textTertiary, EmColors.surface),
    ('outline', EmColors.outline, EmColors.surface),
    ('border', EmColors.border, EmColors.ink),
  ];

  static String hex(Color c) => '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in _swatches)
          Container(
            width: 104,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: s.$2, borderRadius: EmRadius.smAll, border: Border.all(color: EmColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: s.$3, fontWeight: FontWeight.w600, fontSize: 11)),
              Text(hex(s.$2), style: EmType.caption.copyWith(color: s.$3, fontSize: 11)),
              Text('${contrastRatio(s.$3, s.$2).toStringAsFixed(2)}:1', style: EmType.caption.copyWith(color: s.$3, fontSize: 11)),
            ]),
          ),
      ],
    );
  }
}

class GalleryTypeSection extends StatelessWidget {
  const GalleryTypeSection({super.key});
  @override
  Widget build(BuildContext context) {
    final styles = <(String, TextStyle)>[
      ('display 28/600', EmType.display),
      ('title 22/600', EmType.title),
      ('heading 18/600', EmType.heading),
      ('bodyLarge 16/500', EmType.bodyLarge),
      ('body 14/500', EmType.body),
      ('bodyRegular 14/400', EmType.bodyRegular),
      ('label 13/600', EmType.label),
      ('caption 12/500', EmType.caption),
      ('value 20/600 · 0123456789', EmType.value),
    ];
    return EmCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final s in styles) Padding(padding: const EdgeInsetsDirectional.only(bottom: 6), child: Text(s.$1, style: s.$2.copyWith(color: EmColors.ink))),
      ]),
    );
  }
}

class GalleryShapeSection extends StatelessWidget {
  const GalleryShapeSection({super.key});
  @override
  Widget build(BuildContext context) {
    Widget box(String l, double r) => Column(children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: EmColors.primaryContainer, borderRadius: BorderRadius.circular(r), border: Border.all(color: EmColors.primaryLight))),
          const SizedBox(height: 4),
          Text(l, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
        ]);
    return Wrap(spacing: 12, runSpacing: 12, children: [box('sm 12', EmRadius.sm), box('md 16', EmRadius.md), box('tile 20', EmRadius.tile), box('card 24', EmRadius.card), box('hero 28', EmRadius.hero), box('pill', 32)]);
  }
}

/// Logomark on white and on primaryDark (pending brand approval).
class GalleryBrandSection extends StatelessWidget {
  const GalleryBrandSection({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Container(
          key: const Key('gallery_logo_light'),
          height: 170,
          decoration: BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.cardAll),
          child: const Center(child: EmLogomark(height: 110)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          key: const Key('gallery_logo_dark'),
          height: 170,
          decoration: BoxDecoration(color: EmColors.primaryDark, borderRadius: EmRadius.cardAll),
          child: const Center(child: EmLogomark(height: 110, reversed: true)),
        ),
      ),
    ]);
  }
}

/// App bar, greeting header, search pill, bell, bottom nav + diamond FAB.
class GalleryChromeSection extends StatefulWidget {
  const GalleryChromeSection({super.key});
  @override
  State<GalleryChromeSection> createState() => _GalleryChromeSectionState();
}

class _GalleryChromeSectionState extends State<GalleryChromeSection> {
  int _nav = 0;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Sub('EmAppBar'),
      EmAppBar(title: 'Statistics', onBack: () {}, trailing: EmIconCircleButton(icon: Icons.more_horiz_rounded, semanticLabel: 'More', onTap: () {})),
      const _Sub('EmGreetingHeader + EmIconCircleButton (unread dot)'),
      EmGreetingHeader(
        name: 'Clara Classteacher',
        avatar: const EmAvatar(initials: 'CC'),
        trailing: EmIconCircleButton(icon: Icons.notifications_none_rounded, semanticLabel: 'Notifications', showDot: true, onTap: () {}),
      ),
      const _Sub('EmSearchPill'),
      EmSearchPill(trailing: EmIconCircleButton(icon: Icons.calendar_month_outlined, semanticLabel: 'Calendar', onTap: () {})),
      const _Sub('EmBottomNav + EmDiamondFab (accent)'),
      SizedBox(
        height: EmBottomNav.barHeight + EmBottomNav.overhang + 12,
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: EmBottomNav(
            currentIndex: _nav,
            onTap: (i) => setState(() => _nav = i),
            items: const [
              EmNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
              EmNavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Classes'),
              EmNavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Messages', badgeCount: 3),
              EmNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'More'),
            ],
            centerAction: EmDiamondFab(icon: Icons.add_rounded, semanticLabel: 'Quick actions', onPressed: () {}),
          ),
        ),
      ),
      const _Sub('EmDiamondFab (primary)'),
      Center(child: EmDiamondFab(icon: Icons.add_rounded, semanticLabel: 'Quick actions', style: EmFabStyle.primary, onPressed: () {})),
    ]);
  }
}

/// Date strip, stat tiles, segmented tabs, hero containers.
class GalleryDashboardSection extends StatefulWidget {
  const GalleryDashboardSection({super.key, DateTime? today}) : _today = today;
  final DateTime? _today;
  @override
  State<GalleryDashboardSection> createState() => _GalleryDashboardSectionState();
}

class _GalleryDashboardSectionState extends State<GalleryDashboardSection> {
  late DateTime _sel = widget._today ?? DateTime(2025, 5, 21);
  String _tab = 'week';
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Sub('EmSegmentedTabs'),
      EmSegmentedTabs<String>(
        segments: const [EmSegment('day', 'Day'), EmSegment('week', 'Week'), EmSegment('month', 'Month')],
        selected: _tab,
        onChanged: (v) => setState(() => _tab = v),
      ),
      const _Sub('EmHeroCard · EmDateStrip · EmStatTile'),
      EmHeroCard(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today, 21 May 2025', style: EmType.heading.copyWith(color: EmColors.ink)),
          const SizedBox(height: 12),
          EmDateStrip(days: EmDateStrip.weekOf(_sel), selected: _sel, onSelected: (d) => setState(() => _sel = d)),
          const SizedBox(height: 12),
          const EmStatTileRow(tiles: [
            EmStatTile(icon: Icons.groups_outlined, value: '28', unit: 'present', label: 'Attendance', onMenu: _noop),
            EmStatTile(icon: Icons.menu_book_outlined, value: '4', unit: 'due', label: 'Homework', onMenu: _noop),
            EmStatTile(icon: Icons.schedule_rounded, value: '5', unit: 'classes', label: 'Today', onMenu: _noop),
          ]),
        ]),
      ),
      const _Sub('EmProgressRingCard'),
      EmProgressRingCard(
        title: 'Attendance target',
        subtitle: '28 of 30 students marked',
        value: 0.93,
        centerText: '93%',
        centerCaption: 'present',
        action: EmSecondaryButton(label: 'Mark remaining', onPressed: () {}),
      ),
    ]);
  }

  static void _noop() {}
}

class GalleryChartsSection extends StatelessWidget {
  const GalleryChartsSection({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Sub('EmBarChart in EmCard'),
      EmCard(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Weekly attendance', style: EmType.heading.copyWith(color: EmColors.ink))),
            Text('This week', style: EmType.body.copyWith(color: EmColors.textSecondary)),
          ]),
          const SizedBox(height: 12),
          const EmBarChart(data: [
            EmBarDatum('Mon', 42),
            EmBarDatum('Tue', 55),
            EmBarDatum('Wed', 96),
            EmBarDatum('Thu', 78, highlight: true),
            EmBarDatum('Fri', 38),
            EmBarDatum('Sat', 88),
          ]),
        ]),
      ),
      const _Sub('EmProgressRing (sizes)'),
      const Wrap(spacing: 16, runSpacing: 16, children: [
        EmProgressRing(value: 0.35, size: 96, strokeWidth: 10, centerText: '35%'),
        EmProgressRing(value: 0.8, size: 120, centerText: '800', centerCaption: '/2210 ml'),
        EmProgressRing(value: 1, size: 96, strokeWidth: 10, centerText: 'Done'),
      ]),
    ]);
  }
}

class GalleryListsSection extends StatelessWidget {
  const GalleryListsSection({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Sub('EmListRow'),
      EmListRow(icon: Icons.schedule_rounded, title: 'Mathematics · Grade 5 – A', subtitle: '08:00 – 08:45 · Room 101', trailingText: '28/30', onTap: () {}),
      const SizedBox(height: EmSpacing.row),
      EmListRow(icon: Icons.menu_book_outlined, title: 'Fractions worksheet', subtitle: 'Due tomorrow', onMenu: () {}),
      const SizedBox(height: EmSpacing.row),
      EmListRow(icon: Icons.event_busy_outlined, title: 'Leave request', subtitle: 'Aisha Khan · 2 days', trailing: const EmChip.status(label: 'Pending', tone: EmTone.warning), onTap: () {}),
    ]);
  }
}

class GalleryControlsSection extends StatefulWidget {
  const GalleryControlsSection({super.key});
  @override
  State<GalleryControlsSection> createState() => _GalleryControlsSectionState();
}

class _GalleryControlsSectionState extends State<GalleryControlsSection> {
  String _chip = 'All';
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Sub('EmPrimaryButton · EmSecondaryButton'),
      EmPrimaryButton(label: 'Save changes', icon: Icons.check_rounded, onPressed: () {}),
      const SizedBox(height: 8),
      const EmPrimaryButton(label: 'Disabled', onPressed: null),
      const SizedBox(height: 8),
      EmPrimaryButton(label: 'Saving', loading: true, onPressed: () {}),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        EmSecondaryButton(label: 'Drink 200 ml', onPressed: () {}),
        EmSecondaryButton(label: 'With icon', icon: Icons.add_rounded, onPressed: () {}),
      ]),
      const _Sub('EmChip (filter)'),
      Wrap(spacing: 8, runSpacing: 0, children: [
        for (final c in ['All', 'Present', 'Absent', 'Late']) EmChip(label: c, selected: _chip == c, onTap: () => setState(() => _chip = c)),
      ]),
      const _Sub('EmChip.status (container + dark text)'),
      const Wrap(spacing: 8, runSpacing: 8, children: [
        EmChip.status(label: 'Neutral'),
        EmChip.status(label: 'Info', tone: EmTone.info),
        EmChip.status(label: 'Present', tone: EmTone.success),
        EmChip.status(label: 'Late', tone: EmTone.warning),
        EmChip.status(label: 'Absent', tone: EmTone.error),
        EmChip.status(label: 'Half day', tone: EmTone.leave),
      ]),
      const _Sub('EmTextField'),
      const EmTextField(label: 'Email', hint: 'name@school.org', prefixIcon: Icons.mail_outline_rounded),
      const SizedBox(height: 12),
      const EmTextField(label: 'Password', obscureText: true, errorText: 'Password is required'),
      const _Sub('EmEmptyState · EmErrorState · EmLoading'),
      const SizedBox(height: 4),
      const SizedBox(height: 280, child: EmEmptyState(icon: Icons.menu_book_outlined, title: 'No homework yet', message: 'Assignments you create show up here.', actionLabel: 'New homework', onAction: _noop)),
      const SizedBox(height: 300, child: EmErrorState(message: 'We could not load this. Check your connection.', onRetry: _noop)),
      const SizedBox(height: 90, child: EmLoading(showLabel: true)),
      const _Sub('EmBottomSheet'),
      EmSecondaryButton(
        label: 'Open sheet',
        onPressed: () => EmBottomSheet.show<void>(
          context,
          title: 'Choose action',
          child: const Text('Sheet content scrolls when it is taller than 90% of the screen.'),
          footer: EmPrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
        ),
      ),
    ]);
  }

  static void _noop() {}
}
