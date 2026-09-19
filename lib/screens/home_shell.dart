import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_events.dart';
import '../core/theme.dart';
import '../models/app_settings.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';
import 'attendance/attendance_tab.dart';
import 'overview/overview_tab.dart';
import 'settings/settings_tab.dart';
import 'welcome_dialog.dart';

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
  StreamSubscription<AppSettings>? _settingsSub;

  @override
  void initState() {
    super.initState();
    AppEvents.requestTab.addListener(_onTabRequested);
    // Dialog chào mừng, chỉ hiện lần đầu của mỗi tài khoản trên máy đó.
    // Phải chờ khung hình đầu: trong `initState` chưa có `Overlay` để đẩy
    // dialog lên.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showWelcomeIfFirstTime(context);
    });
    // Áp lại lịch "Nhắc chấm công cuối ngày" mỗi khi thiết lập đổi - nghe
    // thẳng từ Firestore như mọi màn khác (§2), nên bật/tắt hoặc đổi giờ ở
    // màn Cài đặt tự có hiệu lực mà không cần gọi tay từ đó.
    _settingsSub = DataService.instance.watchSettings().listen(
      NotificationService.instance.applySettings,
    );
  }

  @override
  void dispose() {
    AppEvents.requestTab.removeListener(_onTabRequested);
    _settingsSub?.cancel();
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
        // Bỏ nền viên thuốc sau icon khi active, chữ nhãn tự đậm lên và đổi
        // sang màu của icon active (primaryDark) thay cho nền đó.
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? AppColors.primaryDark : AppColors.textMuted,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            height: 66,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: Colors.transparent,
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
      ),
    );
  }
}
