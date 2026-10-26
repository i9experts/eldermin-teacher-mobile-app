import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/home_time.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../classes/views/classes_screen.dart';
import '../../messages/views/messages_screen.dart';
import '../../more/views/more_screen.dart';
import '../bindings/home_binding.dart';
import '../controllers/home_badges_controller.dart';
import '../controllers/home_dashboard_controller.dart';
import '../controllers/home_shell_controller.dart';
import '../models/shell_quick_actions.dart';
import 'home_dashboard_screen.dart';

/// App shell: greeting header (avatar · greeting · name · notifications bell) over
/// four tabs (Home · Classes · Messages · More) and a bottom bar whose centre
/// diamond FAB opens the Quick actions sheet. Attendance and Timetable are no
/// longer tabs: they are reached from the sheet and from the Classes / More
/// lists (their routes are unchanged).
class HomeShell extends StatefulWidget {
  final int initialTab;
  const HomeShell({super.key, this.initialTab = 0});

  /// Key of the bottom navigation bar (tests and finders use this, not its type).
  static const navKey = Key('app_shell_nav');

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final HomeShellController shell;
  late final HomeBadgesController badges;

  @override
  void initState() {
    super.initState();
    HomeBinding().dependencies();
    shell = Get.find<HomeShellController>();
    badges = Get.find<HomeBadgesController>();
    // after the first frame: changing the Rx tab during initState marks an Obx dirty while the framework is building
    if (widget.initialTab != 0) WidgetsBinding.instance.addPostFrameCallback((_) => shell.changeTab(widget.initialTab));
  }

  void _openQuickActions(List<ShellQuickAction> actions) {
    EmBottomSheet.show<void>(
      context,
      title: 'Quick actions',
      child: Column(
        key: const Key('quick_actions_sheet'),
        children: [
          for (final a in actions) ...[
            EmListRow(
              key: Key('quick_action_${a.id}'),
              icon: a.icon,
              title: a.label,
              subtitle: a.subtitle,
              trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary),
              onTap: () {
                Navigator.of(context).pop(); // close the sheet, then open the (unchanged) route
                Get.toNamed(a.route);
              },
            ),
            const SizedBox(height: EmSpacing.row),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final permissions = Get.find<PermissionService>();

    return EmScaffold(
      extendBody: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s4),
              child: Obx(() {
                final user = auth.user.value;
                final unread = badges.notificationUnread.value ?? 0;
                // the dashboard's injectable clock keeps the greeting testable (and ticking)
                final now = Get.isRegistered<HomeDashboardController>() ? Get.find<HomeDashboardController>().now.value : DateTime.now();
                return EmGreetingHeader(
                  key: const Key('shell_header'),
                  greeting: greetingFor(now),
                  name: (user?.name ?? '').trim().isEmpty ? 'Teacher' : user!.name,
                  avatar: EmAvatar(initials: user?.initials ?? '--', imageUrl: user?.avatarUrl),
                  onTap: () => Get.toNamed(Routes.profile),
                  // The dot appears only from the real unread-count endpoint; none when unavailable (404/501) or zero.
                  trailing: EmIconCircleButton(
                    key: const Key('bell_badge'),
                    icon: Icons.notifications_none_rounded,
                    semanticLabel: 'Notifications',
                    showDot: unread > 0,
                    dotLabel: '$unread unread',
                    onTap: () => Get.toNamed(Routes.notifications),
                  ),
                );
              }),
            ),
            Expanded(
              child: Obx(() => IndexedStack(index: shell.tabIndex.value, children: const [
                    HomeDashboardScreen(),
                    ClassesScreen(),
                    MessagesScreen(embedded: true),
                    MoreScreen(),
                  ])),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Obx(() {
        auth.staffMe.value; // permissions and the class-teacher flag are rebuilt together with the profile
        final actions = shellQuickActions(permissions: permissions, isClassTeacher: auth.isClassTeacher);
        return EmBottomNav(
          key: HomeShell.navKey,
          currentIndex: shell.tabIndex.value,
          onTap: shell.changeTab,
          items: [
            const EmNavItem(svgIcon: 'assets/icons/home.svg', label: 'Home'),
            const EmNavItem(svgIcon: 'assets/icons/dashboard.svg', label: 'Classes'),
            // Badge only from the real unread-conversations endpoint; none when unavailable or zero.
            EmNavItem(
              svgIcon: 'assets/icons/message.svg',
              label: 'Messages',
              badgeCount: badges.messagesUnread,
              badgeCapped: badges.messagesUnreadCapped,
              badgeKey: const Key('messages_badge'),
            ),
            const EmNavItem(svgIcon: 'assets/icons/menu.svg', label: 'More'),
          ],
          // No allowed action -> no FAB (the bar then spreads its four items evenly).
          centerAction: actions.isEmpty
              ? null
              : EmDiamondFab(
                  key: const Key('quick_actions_fab'),
                  icon: Icons.add_rounded,
                  semanticLabel: 'Quick actions',
                  onPressed: () => _openQuickActions(actions),
                ),
        );
      }),
    );
  }
}
