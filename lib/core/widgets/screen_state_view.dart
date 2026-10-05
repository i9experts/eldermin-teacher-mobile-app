import 'package:flutter/material.dart';
import '../../app/components/custom_text.dart';
import '../../app/modules/home/models/section_state.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'shimmer_widgets.dart';

/// Full-screen list state for the classroom modules: shimmer while loading, the
/// data children, an empty message, error + Retry, "You don't have access"
/// (403) and "not available on this server yet" (404/501). Everything is inside a
/// [RefreshIndicator] + always-scrollable [ListView], so pull-to-refresh works in
/// EVERY state (including error and empty).
class ScreenStateView<T> extends StatelessWidget {
  final SectionState<T> state;
  final List<Widget> Function(T data) builder;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  /// Always shown above the state body (title, tabs, date strip ...).
  final List<Widget> header;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;
  final int skeletonRows;
  final EdgeInsets padding;

  const ScreenStateView({
    super.key,
    required this.state,
    required this.builder,
    required this.onRefresh,
    required this.onRetry,
    this.header = const [],
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here',
    this.emptySubtitle,
    this.skeletonRows = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [...header, ..._body()],
      ),
    );
  }

  Widget _centered(Widget child) => Padding(padding: const EdgeInsets.only(top: 24), child: child);

  List<Widget> _body() {
    switch (state.status) {
      case SectionStatus.loading:
        return [
          AppShimmer(
            key: const Key('screen_loading'),
            child: Column(children: List.generate(skeletonRows, (_) => const ShimmerListRowSkeleton())),
          ),
        ];
      case SectionStatus.data:
        return builder(state.data as T);
      case SectionStatus.empty:
        return [_centered(AppEmptyView(key: const Key('screen_empty'), icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle))];
      case SectionStatus.forbidden:
        return [
          _centered(const AppEmptyView(
            key: Key('screen_forbidden'),
            icon: Icons.lock_outline_rounded,
            title: "You don't have access",
            subtitle: "Your account isn't allowed to view this. Ask your school admin if you think this is a mistake.",
          ))
        ];
      case SectionStatus.unavailable:
        return [
          _centered(const AppEmptyView(
            key: Key('screen_unavailable'),
            icon: Icons.cloud_off_rounded,
            title: 'Not available on this server yet',
            subtitle: 'This feature has not been deployed to your school’s server.',
          ))
        ];
      case SectionStatus.error:
        return [
          _centered(AppErrorView(key: const Key('screen_error'), message: state.message ?? 'Something went wrong', onRetry: onRetry)),
        ];
    }
  }
}

/// Small helper used by several classroom screens: a section title row.
class SubHeading extends StatelessWidget {
  final String text;
  const SubHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: CustomText(text: text, color: AppColors.primaryColor, fontSize: 13, fontWeight: FontWeight.w800),
      );
}
