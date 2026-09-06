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
import 'ot_picker_sheet.dart';
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
  String _query = '';
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
    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _AttendanceDatePickerDialog(
        initialDate: _date.isAfter(_today) ? _today : _date,
        lastDate: _today,
      ),
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

  /// Chạm nhanh vào chip trạng thái: đổi qua lại Đi làm và Nghỉ.
  /// Các trường hợp còn lại (nửa công, bỏ chấm) nằm trong bảng chọn đầy đủ.
  Future<void> _toggleStatus(Employee e, AttendanceRecord? current) async {
    if (!_guardEditable()) return;
    final next = switch (current?.status) {
      AttendanceStatus.present ||
      AttendanceStatus.half =>
        AttendanceStatus.absent,
      _ => AttendanceStatus.present,
    };
    await _write(
      e,
      status: next,
      overtimeMinutes: current?.overtimeMinutes ?? 0,
    );
  }

  /// Chạm vào tên nhân viên: mở bảng đủ 4 lựa chọn.
  Future<void> _pickStatus(Employee e, AttendanceRecord? current) async {
    if (!_guardEditable()) return;
    final choice = await showStatusPicker(
      context,
      employeeName: e.name,
      current: current?.status ?? AttendanceStatus.none,
      currentOvertime: current?.overtimeMinutes ?? 0,
      dateLabel: Fmt.fullDate(_date),
    );
    if (choice == null) return;

    if (choice.clear) {
      try {
        await _data.clearRecord(e.id, Fmt.dateKey(_date));
        if (mounted) showToast(context, 'Đã bỏ chấm công của ${e.name}');
      } catch (err) {
        if (mounted) showToast(context, 'Không xoá được: $err', error: true);
      }
      return;
    }

    await _write(
      e,
      status: choice.status,
      overtimeMinutes: choice.overtimeMinutes,
    );
  }

  Future<void> _editOvertime(Employee e, AttendanceRecord? current) async {
    if (!_guardEditable()) return;
    final minutes = await showOtPicker(
      context,
      employeeName: e.name,
      currentMinutes: current?.overtimeMinutes ?? 0,
      presets: _settings.otPresets,
    );
    if (minutes == null) return;
    await _write(
      e,
      // Nhập OT cho người chưa chấm thì mặc định coi như đã đi làm;
      // ai đã có trạng thái thì giữ nguyên trạng thái đó.
      status:
          current?.status == null || current!.status == AttendanceStatus.none
              ? AttendanceStatus.present
              : current.status,
      overtimeMinutes: minutes,
    );
  }

  Future<void> _write(
    Employee e, {
    required AttendanceStatus status,
    required int overtimeMinutes,
  }) async {
    try {
      await _data.saveRecord(
        AttendanceRecord.forDay(
          employeeId: e.id,
          day: _date,
          status: status,
          overtimeMinutes: overtimeMinutes,
        ),
      );
    } catch (err) {
      if (mounted) showToast(context, 'Không lưu được: $err', error: true);
    }
  }

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

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Đã chấm đi làm cho ${employees.length} nhân viên',
            ),
            backgroundColor: AppColors.textDark,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Hoàn tác',
              textColor: Colors.white,
              onPressed: () => _undoMarkAll(day, employees, before),
            ),
          ),
        );
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
    var absent = 0;
    var withOt = 0;
    var marked = 0;
    for (final e in employees) {
      final r = records[e.id];
      if (r == null || r.status == AttendanceStatus.none) continue;
      marked++;
      if (r.status == AttendanceStatus.present) present++;
      if (r.status == AttendanceStatus.half) half++;
      if (r.status == AttendanceStatus.absent) absent++;
      if (r.overtimeMinutes > 0) withOt++;
    }

    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? employees
        : employees.where((e) => e.name.toLowerCase().contains(q)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              PeriodSelector(
                label: Fmt.fullDate(_date),
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
                  ),
                  StatTile(
                    value: '$present',
                    label: 'Đi làm',
                    color: AppColors.present,
                  ),
                  StatTile(
                    value: '$absent',
                    label: 'Nghỉ',
                    color: AppColors.absent,
                  ),
                  StatTile(
                    value: '$withOt',
                    label: 'Có OT',
                    color: AppColors.overtime,
                  ),
                ],
              ),
              if (half > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timelapse_rounded,
                        size: 14,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Trong đó $half người nửa công',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: employees.isEmpty || _bulkBusy || _isFuture
                      ? null
                      : () => _markAllPresent(employees, records),
                  icon: _bulkBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.done_all_rounded, size: 19),
                  label: const Text('Tất cả đi làm'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SearchBox(
                hint: 'Tìm nhân viên...',
                onChanged: (v) => setState(() => _query = v),
              ),
              if (employees.isNotEmpty && !_isFuture)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: _RowHint(),
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
              : visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Không tìm thấy nhân viên',
                      message: 'Thử nhập lại tên khác.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = visible[i];
                        return _AttendanceRow(
                          employee: e,
                          record: records[e.id],
                          locked: _isFuture,
                          onToggleStatus: () => _toggleStatus(e, records[e.id]),
                          onEditOvertime: () => _editOvertime(e, records[e.id]),
                          onPickStatus: () => _pickStatus(e, records[e.id]),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

/// Một dòng chấm công: tên + chip trạng thái + chip OT.
///
/// Chạm chip trạng thái = đổi nhanh Đi làm / Nghỉ.
/// Chạm tên hoặc avatar = mở bảng đủ 4 lựa chọn (kể cả nửa công và bỏ chấm).
class _AttendanceRow extends StatelessWidget {
  final Employee employee;
  final AttendanceRecord? record;
  final bool locked;
  final VoidCallback onToggleStatus;
  final VoidCallback onEditOvertime;
  final VoidCallback onPickStatus;

  const _AttendanceRow({
    required this.employee,
    required this.record,
    required this.locked,
    required this.onToggleStatus,
    required this.onEditOvertime,
    required this.onPickStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = record?.status ?? AttendanceStatus.none;
    final ot = record?.overtimeMinutes ?? 0;

    final (statusColor, statusBg) = switch (status) {
      AttendanceStatus.present => (AppColors.present, AppColors.presentSoft),
      AttendanceStatus.half => (AppColors.info, AppColors.infoSoft),
      AttendanceStatus.absent => (AppColors.absent, AppColors.absentSoft),
      AttendanceStatus.none => (AppColors.textMuted, AppColors.background),
    };

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Vùng chạm mở bảng chọn đầy đủ.
            Expanded(
              child: InkWell(
                onTap: locked ? null : onPickStatus,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      EmployeeAvatar(initials: employee.initials, size: 38),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          employee.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dấu hiệu cho biết chạm được vào đây để mở thêm
                      // lựa chọn - nếu không có thì vùng chạm trông như
                      // khoảng trắng chết.
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          size: 17,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
            TagChip(
              text: status.label,
              color: statusColor,
              background: statusBg,
              onTap: locked ? null : onToggleStatus,
              minWidth: 62,
            ),
            const SizedBox(width: 6),
            TagChip(
              text: Fmt.otHours(ot),
              color: ot > 0 ? AppColors.overtime : AppColors.textMuted,
              background:
                  ot > 0 ? AppColors.overtimeSoft : AppColors.background,
              onTap: locked ? null : onEditOvertime,
              minWidth: 46,
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// Dòng gợi ý thao tác, có vẽ đúng nút ⋯ như trong danh sách để người dùng
/// nhận ra ngay phải chạm vào đâu.
class _RowHint extends StatelessWidget {
  const _RowHint();

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.textMuted,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'Chạm ô trạng thái để đổi nhanh  ·  Chạm '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const TextSpan(text: ' để chọn nửa công hoặc bỏ chấm'),
        ],
      ),
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

class _AttendanceDatePickerDialog extends StatefulWidget {
  const _AttendanceDatePickerDialog({
    required this.initialDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime lastDate;

  @override
  State<_AttendanceDatePickerDialog> createState() =>
      _AttendanceDatePickerDialogState();
}

class _AttendanceDatePickerDialogState
    extends State<_AttendanceDatePickerDialog> {
  // DateTime không có hằng số biên dịch nên phải dùng final, không dùng const.
  static final DateTime _minMonth = DateTime(2020, 1);

  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final clampedInitial = widget.initialDate.isAfter(widget.lastDate)
        ? widget.lastDate
        : widget.initialDate;
    _selectedDate = DateTime(
      clampedInitial.year,
      clampedInitial.month,
      clampedInitial.day,
    );
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  DateTime get _today => DateTime(
        widget.lastDate.year,
        widget.lastDate.month,
        widget.lastDate.day,
      );

  DateTime get _currentMonthStart =>
      DateTime(_visibleMonth.year, _visibleMonth.month);

  DateTime get _lastAllowedMonth => DateTime(_today.year, _today.month);

  bool get _canGoPrevMonth => _currentMonthStart.isAfter(_minMonth);

  bool get _canGoNextMonth => _currentMonthStart.isBefore(_lastAllowedMonth);

  int get _daysInMonth => Fmt.daysInMonth(_visibleMonth);

  DateTime _dayDate(int day) =>
      DateTime(_visibleMonth.year, _visibleMonth.month, day);

  void _changeMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    if (next.isAfter(_lastAllowedMonth) || next.isBefore(_minMonth)) {
      return;
    }

    setState(() {
      _visibleMonth = next;
      final maxDay = Fmt.daysInMonth(next);
      final selectedDay =
          _selectedDate.year == next.year && _selectedDate.month == next.month
              ? _selectedDate.day
              : _selectedDate.day.clamp(1, maxDay).toInt();
      _selectedDate = DateTime(next.year, next.month, selectedDay);
      if (_selectedDate.isAfter(_today)) {
        _selectedDate = _today;
      }
    });
  }

  void _selectDay(int day) {
    final picked = _dayDate(day);
    if (picked.isAfter(_today)) return;
    setState(() => _selectedDate = picked);
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ hai';
      case DateTime.tuesday:
        return 'Thứ ba';
      case DateTime.wednesday:
        return 'Thứ tư';
      case DateTime.thursday:
        return 'Thứ năm';
      case DateTime.friday:
        return 'Thứ sáu';
      case DateTime.saturday:
        return 'Thứ bảy';
      case DateTime.sunday:
        return 'Chủ nhật';
      default:
        return '';
    }
  }

  String _monthLabel(DateTime date) => 'Tháng ${date.month}/${date.year}';

  String _shortDateLabel(DateTime date) =>
      '${_weekdayLabel(date.weekday)}, ${Fmt.pad2(date.day)}/${Fmt.pad2(date.month)}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstWeekday =
        DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday;
    final offset = firstWeekday - DateTime.monday;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        // Máy màn nhỏ hoặc người dùng để cỡ chữ lớn thì nội dung cao hơn màn
        // hình, phải cho cuộn chứ không để tràn.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn ngày chấm công',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortDateLabel(_selectedDate),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ngày ${_selectedDate.day} tháng ${_selectedDate.month}, ${_selectedDate.year}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chỉ chọn được ngày hôm nay trở về trước.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    _monthLabel(_visibleMonth),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Tháng trước',
                    onPressed: _canGoPrevMonth ? () => _changeMonth(-1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Tháng sau',
                    onPressed: _canGoNextMonth ? () => _changeMonth(1) : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.1,
                children: const [
                  _WeekdayLabel('T2'),
                  _WeekdayLabel('T3'),
                  _WeekdayLabel('T4'),
                  _WeekdayLabel('T5'),
                  _WeekdayLabel('T6'),
                  _WeekdayLabel('T7'),
                  _WeekdayLabel('CN'),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // Chỉ vẽ đúng số tuần mà tháng này cần, tránh thừa một hàng
                // trống làm bảng cao thêm vô ích.
                itemCount: ((offset + _daysInMonth) / 7).ceil() * 7,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final day = index - offset + 1;
                  if (day < 1 || day > _daysInMonth) {
                    return const SizedBox.shrink();
                  }

                  final dayDate = _dayDate(day);
                  final isSelected = Fmt.isSameDay(dayDate, _selectedDate);
                  final isToday = Fmt.isSameDay(dayDate, _today);
                  final isFuture = dayDate.isAfter(_today);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: isFuture ? null : () => _selectDay(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : isToday
                                  ? AppColors.primarySoft
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isToday && !isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '$day',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : isFuture
                                    ? AppColors.textMuted
                                    : AppColors.textDark,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedDate),
                    child: const Text('Chọn'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
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
