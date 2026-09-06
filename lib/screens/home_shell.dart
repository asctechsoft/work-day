import 'package:flutter/material.dart';

import '../core/app_events.dart';
import '../core/theme.dart';
import 'attendance/attendance_tab.dart';
import 'overview/overview_tab.dart';
import 'settings/settings_tab.dart';

/// Bộ khung 3 tab duy nhất của app: Chấm công - Tổng quan - Cài đặt.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Cho phép màn con yêu cầu chuyển tab (ví dụ: từ Tổng quan sang Chấm công
  /// của đúng ngày cần sửa).
  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    AppEvents.requestTab.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    AppEvents.requestTab.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final target = AppEvents.requestTab.value;
    if (target == null || !mounted) return;
    AppEvents.requestTab.value = null;
    goToTab(target);
  }

  /// Chuyển sang tab theo số thứ tự (0: Chấm công, 1: Tổng quan, 2: Cài đặt).
  void goToTab(int index) {
    if (_index != index) setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [AttendanceTab(), OverviewTab(), SettingsTab()],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          height: 66,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primarySoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(
                Icons.event_available_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'Chấm công',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(
                Icons.bar_chart_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(
                Icons.settings_rounded,
                color: AppColors.primaryDark,
              ),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }
}
