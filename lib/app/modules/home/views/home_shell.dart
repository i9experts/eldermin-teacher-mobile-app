import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../components/custom_text.dart';
import '../../../components/svg_icon.dart';
import '../../../config/app_icons.dart';
import '../../../routes/app_routes.dart';
import '../../attendance/views/attendance_screen.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../classes/views/classes_screen.dart';
import '../../messages/views/messages_screen.dart';
import '../../more/views/more_screen.dart';
import '../../timetable/views/timetable_screen.dart';
import '../bindings/home_binding.dart';
import '../controllers/home_badges_controller.dart';
import '../controllers/home_shell_controller.dart';
import 'home_dashboard_screen.dart';

/// Home · Classes · Attendance (class teachers) or Timetable (everyone
/// else) · Messages · More. Solid navy app bar (the theme's AppBar), same
/// bottom-nav styling as the parent app.
class HomeShell extends StatefulWidget {
  final int initialTab;
  const HomeShell({super.key, this.initialTab = 0});

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
    if (widget.initialTab != 0) shell.changeTab(widget.initialTab);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: InkWell(
          onTap: () => Get.toNamed(Routes.profile),
          child: Obx(() {
            final user = auth.user.value;
            final subtitle = auth.staffMe.value?.subtitle ?? '';
            return Row(
              children: [
                _Avatar(initials: user?.initials ?? '--', url: user?.avatarUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomText(
                          text: user?.name ?? 'Teacher',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (subtitle.isNotEmpty)
                        CustomText(
                            text: subtitle,
                            fontSize: 10,
                            color: const Color(0xFFBCD3E5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => Get.toNamed(Routes.notifications),
              borderRadius: BorderRadius.circular(13),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withOpacity(0.13))),
                // Badge only from the real unread-count endpoint; none when
                // unavailable (404/501, not deployed yet) or zero.
                child: Center(
                  child: Obx(() => _CountBadge(
                        key: const Key('bell_badge'),
                        count: badges.notificationUnread.value,
                        child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20),
                      )),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final classTeacher = auth.isClassTeacher;
        final tabs = <Widget>[
          const HomeDashboardScreen(),
          const ClassesScreen(),
          classTeacher ? const AttendanceScreen(embedded: true) : const TimetableScreen(embedded: true),
          const MessagesScreen(embedded: true),
          const MoreScreen(),
        ];
        return IndexedStack(index: shell.tabIndex.value, children: tabs);
      }),
      bottomNavigationBar: Obx(() {
        final classTeacher = auth.isClassTeacher;
        final icons = [
          AppIcons.home,
          AppIcons.dashboardIcon,
          classTeacher ? AppIcons.checkIcon : AppIcons.calenderIcon,
          AppIcons.messageIcon,
          AppIcons.more,
        ];
        final labels = ['Home', 'Classes', classTeacher ? 'Attendance' : 'Timetable', 'Messages', 'More'];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                  color: AppColors.primaryColor.withOpacity(0.07),
                  blurRadius: 20,
                  offset: const Offset(0, -6)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: shell.tabIndex.value,
              onTap: shell.changeTab,
              items: [
                for (var i = 0; i < icons.length; i++)
                  BottomNavigationBarItem(
                    icon: _CountBadge(
                      key: i == HomeShellController.messagesTab ? const Key('messages_badge') : null,
                      count: i == HomeShellController.messagesTab ? badges.messagesUnread : null,
                      capped: i == HomeShellController.messagesTab && badges.messagesUnreadCapped,
                      child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: shell.tabIndex.value == i ? AppColors.pale : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: SvgIcon(
                        assetName: icons[i],
                        size: 20,
                        color: shell.tabIndex.value == i ? AppColors.blue : AppColors.faint,
                      ),
                    ),
                    ),
                    label: labels[i],
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final String? url;
  const _Avatar({required this.initials, this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
        child: CustomText(
            text: initials, color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 12));
    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.white, Color(0xFFD9EAFA)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
      ),
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

/// Small red count over [child]; nothing when [count] is null or 0.
class _CountBadge extends StatelessWidget {
  final int? count;
  final bool capped;
  final Widget child;
  const _CountBadge({super.key, required this.count, required this.child, this.capped = false});

  @override
  Widget build(BuildContext context) {
    final n = count ?? 0;
    if (n <= 0) return child;
    final text = n > 99 ? '99+' : '$n${capped ? '+' : ''}';
    return Badge(label: Text(text), backgroundColor: AppColors.red, child: child);
  }
}
