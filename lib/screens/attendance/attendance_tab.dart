import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_events.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../models/attendance_record.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';
import '../home_shell.dart';
import 'attendance_actions.dart';
import 'attendance_row.dart';
import 'attendance_search_screen.dart';
import 'date_picker_dialog.dart';
import 'status_picker_sheet.dart';

/// Tab được dùng nhiều nhất: chấm công cho toàn bộ nhân viên trong một ngày.
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  final _data = DataService.instance;

  DateTime _date = DateTime.now();
  bool _bulkBusy = false;
  AppSettings _settings = const AppSettings();

  StreamSubscription<AppSettings>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _date = DateTime(_date.year, _date.month, _date.day);
    AppEvents.jumpToDate.addListener(_onJumpRequested);
    // Theo dõi thiết lập để các mốc OT nhanh đổi ngay khi sửa trong Cài đặt.
    _settingsSub = _data.watchSettings().listen(
      (s) {
        if (mounted) setState(() => _settings = s);
      },
      // Chưa có document settings/app thì dùng giá trị mặc định.
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    AppEvents.jumpToDate.removeListener(_onJumpRequested);
    super.dispose();
  }

  void _onJumpRequested() {
    final target = AppEvents.jumpToDate.value;
    if (target == null || !mounted) return;
    setState(() => _date = target);
    AppEvents.jumpToDate.value = null;
  }

  /// Hôm nay, đã bỏ phần giờ phút.
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Ngày chưa tới thì không cho chấm - phải đợi đúng sang ngày đó.
  bool get _isFuture => _date.isAfter(_today);

  void _shiftDay(int days) {
    final next = _date.add(Duration(days: days));
    if (next.isAfter(_today)) {
      showToast(context, 'Chưa đến ngày này nên chưa chấm công được');
      return;
    }
    setState(() => _date = next);
  }

  void _goToToday() => setState(() => _date = _today);

  Future<void> _pickDate() async {
    final picked = await showAttendanceDatePicker(
      context,
      initialDate: _date.isAfter(_today) ? _today : _date,
      lastDate: _today,
      payPeriodStartDay: _settings.payPeriodStartDay,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  // ------------------------------------------------------------ Ghi dữ liệu

  /// Chặn mọi thao tác ghi khi đang đứng ở một ngày chưa tới.
  bool _guardEditable() {
    if (!_isFuture) return true;
    showToast(
      context,
      'Ngày này chưa tới, phải đợi đúng ngày mới chấm được',
      error: true,
    );
    return false;
  }

  /// Các thao tác chấm công dùng chung với màn tìm kiếm.
  AttendanceActions get _actions => AttendanceActions(
        data: _data,
        date: _date,
        settings: _settings,
      );

  Future<void> _markAllPresent(
    List<Employee> employees,
    Map<String, AttendanceRecord> records,
  ) async {
    if (employees.isEmpty || _bulkBusy) return;
    if (!_guardEditable()) return;

    // Giữ lại trạng thái cũ để có thể hoàn tác nếu bấm nhầm.
    final before = Map<String, AttendanceRecord>.from(records);
    final day = _date;

    setState(() => _bulkBusy = true);
    try {
      await _data.markAllPresent(
        day: day,
        employees: employees,
        existing: records,
      );
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      const snackDuration = Duration(seconds: 4);
      final controller = messenger.showSnackBar(
        SnackBar(
          content: Text('Đã chấm đi làm cho ${employees.length} nhân viên'),
          backgroundColor: AppColors.textDark,
          duration: snackDuration,
          action: SnackBarAction(
            label: 'Hoàn tác',
            textColor: Colors.white,
            onPressed: () => _undoMarkAll(day, employees, before),
          ),
        ),
      );
      // Máy bật hỗ trợ tiếp cận (TalkBack...) thì Flutter cố ý không tự ẩn
      // SnackBar theo `duration` nữa, bắt vuốt tay - tự hẹn giờ đóng để vẫn
      // ẩn đúng lúc như thiết kế.
      Timer(snackDuration, controller.close);
    } catch (err) {
      if (mounted) showToast(context, 'Không lưu được: $err', error: true);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _undoMarkAll(
    DateTime day,
    List<Employee> employees,
    Map<String, AttendanceRecord> before,
  ) async {
    try {
      await _data.restoreDay(
        day: day,
        employees: employees,
        previous: before,
      );
      if (mounted) showToast(context, 'Đã hoàn tác');
    } catch (err) {
      if (mounted) showToast(context, 'Không hoàn tác được: $err', error: true);
    }
  }

  // ------------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm công'),
        actions: [
          IconButton(
            tooltip: 'Cách chấm công',
            onPressed: () => showAttendanceHelp(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<Employee>>(
        stream: _data.watchActiveEmployees(),
        builder: (context, empSnap) {
          if (empSnap.hasError) {
            return _ErrorView(message: '${empSnap.error}');
          }
          if (!empSnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final employees = empSnap.data!;

          return StreamBuilder<Map<String, AttendanceRecord>>(
            stream: _data.watchDay(_date),
            builder: (context, recSnap) {
              final records =
                  recSnap.data ?? const <String, AttendanceRecord>{};
              return _buildBody(employees, records);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    List<Employee> employees,
    Map<String, AttendanceRecord> records,
  ) {
    var present = 0;
    var half = 0;
    var custom = 0;
    var absent = 0;
    var withOt = 0;
    var marked = 0;
    for (final e in employees) {
      final r = records[e.id];
      if (r == null || r.status == AttendanceStatus.none) continue;
      marked++;
      if (r.status == AttendanceStatus.present) present++;
      if (r.status == AttendanceStatus.half) half++;
      if (r.status == AttendanceStatus.custom) custom++;
      if (r.status == AttendanceStatus.absent) absent++;
      if (r.overtimeMinutes > 0) withOt++;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              PeriodSelector(
                label: Fmt.fullDate(_date),
                // Cơ sở tính công theo lịch âm nên ngày âm phải nhìn thấy
                // ngay, không bắt mở lịch ra mới biết.
                subLabel: Fmt.lunarBrief(_date),
                onPrev: () => _shiftDay(-1),
                onNext: () => _shiftDay(1),
                onTapLabel: _pickDate,
                trailingIcon: Icons.calendar_today_rounded,
              ),
              if (_isFuture)
                _Banner(
                  icon: Icons.lock_clock_rounded,
                  color: AppColors.absent,
                  background: AppColors.absentSoft,
                  text: 'Ngày này chưa tới, chưa chấm công được',
                  actionLabel: 'Về hôm nay',
                  onAction: _goToToday,
                )
              else if (!Fmt.isSameDay(_date, _today))
                _Banner(
                  icon: Icons.history_rounded,
                  color: AppColors.overtime,
                  background: AppColors.overtimeSoft,
                  text: 'Đang chấm bù cho ngày đã qua',
                  actionLabel: 'Về hôm nay',
                  onAction: _goToToday,
                ),
              const SizedBox(height: 12),
              StatRow(
                children: [
                  StatTile(
                    value: '$marked/${employees.length}',
                    label: 'Đã chấm',
                    color: AppColors.primaryDark,
                    icon: Icons.groups_rounded,
                  ),
                  StatTile(
                    value: '$present',
                    label: 'Đi làm',
                    color: AppColors.present,
                    icon: Icons.check_rounded,
                  ),
                  StatTile(
                    value: '$absent',
                    label: 'Nghỉ',
                    color: AppColors.absent,
                    icon: Icons.nightlight_round,
                  ),
                  StatTile(
                    value: '$withOt',
                    label: 'Có OT',
                    color: AppColors.overtime,
                    icon: Icons.access_time_filled_rounded,
                  ),
                ],
              ),
              if (half > 0 || custom > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timelapse_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Trong đó ${[
                          if (half > 0) '$half nửa công',
                          if (custom > 0) '$custom tuỳ chỉnh',
                        ].join(', ')}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              GradientButton(
                label: 'Tất cả đi làm',
                icon: Icons.done_all_rounded,
                busy: _bulkBusy,
                onPressed: employees.isEmpty || _isFuture
                    ? null
                    : () => _markAllPresent(employees, records),
              ),
              const SizedBox(height: 12),
              // Ô này chỉ là nút: chạm vào mở hẳn một màn tìm kiếm riêng.
              // Gõ tại chỗ thì bàn phím che gần hết danh sách vì ô nằm dưới
              // bốn ô thống kê và nút "Tất cả đi làm".
              SearchBox(
                hint: 'Tìm nhân viên...',
                readOnly: true,
                onTap: () => showAttendanceSearch(
                  context,
                  date: _date,
                  settings: _settings,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: employees.isEmpty
              ? EmptyState(
                  icon: Icons.group_add_outlined,
                  title: 'Chưa có nhân viên nào',
                  message:
                      'Vào tab Cài đặt > Danh sách nhân viên để thêm nhân viên '
                      'trước khi chấm công.',
                  action: SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: () => HomeShell.of(context)?.goToTab(2),
                      child: const Text('Mở Cài đặt'),
                    ),
                  ),
                )
              : ListView.separated(
                  // Cộng chiều cao thanh điều hướng Android vào đáy, không
                  // thì dòng cuối bị che (xem §5.2.3).
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    24 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  itemCount: employees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = employees[i];
                    final actions = _actions;
                    return AttendanceRow(
                      index: i + 1,
                      employee: e,
                      record: records[e.id],
                      locked: _isFuture,
                      workHoursPerDay: _settings.workHoursPerDay,
                      onToggleStatus: () =>
                          actions.toggleStatus(context, e, records[e.id]),
                      onEditOvertime: () =>
                          actions.editOvertime(context, e, records[e.id]),
                      onPickStatus: () =>
                          actions.pickStatus(context, e, records[e.id]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Dải thông báo nhỏ dưới thanh chọn ngày.
class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _Banner({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: color, height: 1.3),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Không tải được dữ liệu',
      message: message,
    );
  }
}
