import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/pay_period.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../models/attendance_record.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';
import '../../services/export_service.dart';
import '../../widgets/common.dart';
import '../../widgets/highlights_card.dart';
import '../../widgets/payroll_trend_chart.dart';
import 'employee_month_screen.dart';
import 'period_picker_sheet.dart';

/// Tab Tổng quan: tổng công, OT và lương của cả kỳ lương.
/// Lương luôn tính lại từ dữ liệu công nên không cần "chốt bảng lương".
class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final _data = DataService.instance;

  AppSettings _settings = const AppSettings();
  StreamSubscription<AppSettings>? _settingsSub;

  DateTime _anchor = DateTime(DateTime.now().year, DateTime.now().month);
  int _view = 0; // 0 = bảng lương, 1 = biểu đồ
  bool _exporting = false;

  PayPeriod get _period => PayPeriod.of(_anchor, _settings.payPeriodStartDay);

  @override
  void initState() {
    super.initState();
    _settingsSub = _data.watchSettings().listen(
      (s) {
        if (!mounted) return;
        setState(() {
          final startDayChanged = s.payPeriodStartDay != _settings.payPeriodStartDay;
          _settings = s;
          // Đổi ngày chốt kỳ thì nhảy về kỳ đang diễn ra cho khỏi lệch.
          if (startDayChanged) {
            _anchor = PayPeriod.current(s.payPeriodStartDay).anchor;
          }
        });
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  void _shiftMonth(int months) {
    setState(() => _anchor = DateTime(_anchor.year, _anchor.month + months));
  }

  /// Chạm vào tên kỳ: mở danh sách kỳ để nhảy thẳng, khỏi bấm ‹ › nhiều lần.
  Future<void> _pickPeriod() async {
    final picked = await showPeriodPicker(
      context,
      current: _period,
      startDay: _settings.payPeriodStartDay,
    );
    if (picked == null || !mounted) return;
    setState(() => _anchor = picked);
  }

  Future<void> _export() async {
    if (_exporting) return;

    setState(() => _exporting = true);
    final period = _period;
    try {
      // Đọc lại một lần từ Firestore để chắc chắn lấy đủ dữ liệu của kỳ.
      final records = await _data.getPeriod(period);
      final all = await _data.getAllEmployees();
      // Người đã nghỉ nhưng có công trong kỳ vẫn phải nằm trong bảng lương.
      final employees = DataService.employeesForExport(all, records);

      if (employees.isEmpty) {
        if (mounted) {
          showToast(context, 'Chưa có nhân viên nào để xuất', error: true);
        }
        return;
      }

      await ExportService.instance.exportAndShare(
        period: period,
        employees: employees,
        records: records,
        orgName: _settings.orgName,
        workHoursPerDay: _settings.workHoursPerDay,
      );
    } catch (e) {
      if (mounted) showToast(context, 'Không xuất được file: $e', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Employee>>(
      stream: _data.watchActiveEmployees(),
      builder: (context, empSnap) {
        final employees = empSnap.data ?? const <Employee>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tổng quan'),
            actions: [
              IconButton(
                tooltip: 'Tải bảng công',
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.file_download_outlined),
              ),
            ],
          ),
          body: !empSnap.hasData
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : StreamBuilder<List<AttendanceRecord>>(
                  stream: _data.watchPeriod(_period),
                  builder: (context, recSnap) {
                    final records =
                        recSnap.data ?? const <AttendanceRecord>[];
                    final summaries =
                        DataService.summarize(employees, records);
                    return _buildBody(employees, summaries);
                  },
                ),
        );
      },
    );
  }

  Widget _buildBody(List<Employee> employees, List<MonthlySummary> summaries) {
    final period = _period;

    var totalUnits = 0.0;
    var totalOt = 0;
    var totalPay = 0.0;
    for (final s in summaries) {
      totalUnits += s.totalWorkUnits;
      totalOt += s.overtimeMinutes;
      totalPay += s.totalPay;
    }

    // Phần đầu (chọn kỳ + thống kê + chuyển kiểu xem) đứng yên, chỉ phần
    // nội dung bên dưới mới cuộn.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              PeriodSelector(
                label: period.title,
                // Luôn hiện khoảng ngày, kể cả khi kỳ trùng tháng dương lịch:
                // câu hỏi đầu tiên của người dùng là "công tháng này tính từ
                // ngày nào đến ngày nào".
                subLabel: 'Tính công ${period.rangeLabel}',
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
                onTapLabel: _pickPeriod,
                trailingIcon: Icons.expand_more_rounded,
              ),
              const SizedBox(height: 12),
              // Lưới 2 cột thay vì một hàng 4 ô: số tiền viết đủ được, không
              // phải rút thành "22,4 tr" nữa.
              StatGrid(
                items: [
                  StatItem(
                    label: 'Nhân viên',
                    value: '${employees.length}',
                    unit: 'người',
                    color: AppColors.primaryDark,
                    icon: Icons.groups_rounded,
                  ),
                  StatItem(
                    label: 'Tổng công',
                    value: Fmt.workUnits(totalUnits),
                    unit: 'công',
                    color: AppColors.present,
                    icon: Icons.check_rounded,
                  ),
                  StatItem(
                    label: 'Tổng tăng ca',
                    value: Fmt.otHours(totalOt),
                    color: AppColors.info,
                    icon: Icons.access_time_filled_rounded,
                  ),
                  StatItem(
                    label: 'Tổng quỹ lương',
                    value: Fmt.money(totalPay),
                    unit: 'đ',
                    color: AppColors.primaryDark,
                    icon: Icons.payments_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ViewSwitcher(
                index: _view,
                onChanged: (i) => setState(() => _view = i),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: _buildScrollArea(
            employees,
            summaries,
            period,
            totalUnits,
            totalOt,
            totalPay,
          ),
        ),
      ],
    );
  }

  Widget _buildScrollArea(
    List<Employee> employees,
    List<MonthlySummary> summaries,
    PayPeriod period,
    double totalUnits,
    int totalOt,
    double totalPay,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        if (employees.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(
              icon: Icons.insert_chart_outlined_rounded,
              title: 'Chưa có dữ liệu',
              message:
                  'Thêm nhân viên ở tab Cài đặt rồi chấm công để xem tổng hợp '
                  'tại đây.',
            ),
          )
        else if (_view == 0) ...[
          _SummaryTable(
            employees: employees,
            summaries: summaries,
            period: period,
            workHoursPerDay: _settings.workHoursPerDay,
          ),
          const SizedBox(height: 14),
          // "Đáng chú ý" nằm ngay dưới bảng lương: cùng là chuyện so sánh
          // giữa các nhân viên nên đọc liền một mạch.
          HighlightsCard(
            summaries: summaries,
            names: {for (final e in employees) e.id: e.name},
          ),
          // Thẻ "Chốt kỳ" chỉ nằm ở kiểu xem bảng lương - chỗ người dùng vừa
          // xem xong con số của từng người thì mới tới lúc xuất file.
          if (employees.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ExportCard(
              period: period,
              busy: _exporting,
              onExport: _export,
            ),
          ],
        ] else
          // Tab Biểu đồ chỉ có biểu đồ. Khối "Tổng công của kỳ / Tổng giờ
          // tăng ca / Tổng quỹ lương" từng nằm ở đây đã bỏ: cả ba con số đó
          // đã hiện sẵn ở `StatGrid` ngay đầu màn, lặp lại là thừa.
          PayrollTrendChart(
            payPeriodStartDay: _settings.payPeriodStartDay,
            year: period.anchor.year,
          ),
      ],
    );
  }
}

/// Thẻ chốt kỳ: nút tải bảng công ra file Excel.
class _ExportCard extends StatelessWidget {
  final PayPeriod period;
  final bool busy;
  final VoidCallback onExport;

  const _ExportCard({
    required this.period,
    required this.busy,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Chốt kỳ'),
          const SizedBox(height: 6),
          Text(
            'Xuất bảng chấm công và bảng lương của kỳ '
            '${period.fullRangeLabel} ra file Excel để lưu hoặc gửi đi.',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: busy ? null : onExport,
            icon: busy
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 20),
            label: Text(busy ? 'Đang tạo file...' : 'Tải bảng công (.xlsx)'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _ViewSwitcher({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _tab('Bảng lương', 0),
          _tab('Biểu đồ', 1),
        ],
      ),
    );
  }

  Widget _tab(String label, int value) {
    final selected = index == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bảng tổng hợp: # / Tên / Công / Nghỉ / OT / Lương.
class _SummaryTable extends StatelessWidget {
  final List<Employee> employees;
  final List<MonthlySummary> summaries;
  final PayPeriod period;
  final int workHoursPerDay;

  const _SummaryTable({
    required this.employees,
    required this.summaries,
    required this.period,
    required this.workHoursPerDay,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final s in summaries) s.employeeId: s};

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: SectionTitle('Danh sách nhân viên'),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppColors.background,
            child: const Row(
              children: [
                SizedBox(width: 22, child: _Head('#')),
                Expanded(flex: 4, child: _Head('Nhân viên')),
                SizedBox(width: 38, child: _Head('Công', center: true)),
                SizedBox(width: 34, child: _Head('Nghỉ', center: true)),
                SizedBox(width: 42, child: _Head('OT', center: true)),
                SizedBox(width: 78, child: _Head('Lương', right: true)),
                // Chừa chỗ cho mũi tên ở cuối mỗi hàng để các cột thẳng hàng.
                SizedBox(width: 18),
              ],
            ),
          ),
          for (var i = 0; i < employees.length; i++)
            _row(
              context,
              i,
              employees[i],
              byId[employees[i].id],
              last: i == employees.length - 1,
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    int index,
    Employee e,
    MonthlySummary? s, {
    required bool last,
  }) {
    final summary =
        s ??
        MonthlySummary(
          employeeId: e.id,
          totalWorkUnits: 0,
          absentDays: 0,
          overtimeMinutes: 0,
          dailySalary: e.dailySalary,
          otRate: e.otRate,
        );

    // Material trong suốt nằm trên nền trắng của AppCard: thiếu nó thì gợn
    // nước của InkWell bị nền che, chạm vào hàng trông như không có gì xảy ra.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => pushScreen(
          context,
          EmployeeMonthScreen(
            employee: e,
            period: period,
            workHoursPerDay: workHoursPerDay,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          // Dòng cuối không kẻ: vạch dưới người cuối cùng nhìn như bảng còn
          // dòng nữa mà bị cắt, trong khi thẻ đã hết ở đó.
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  Fmt.workUnits(summary.totalWorkUnits),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.present,
                  ),
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${summary.absentDays}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: summary.absentDays > 0
                        ? AppColors.absent
                        : AppColors.textMuted,
                  ),
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  Fmt.otHours(summary.overtimeMinutes),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: summary.overtimeMinutes > 0
                        ? AppColors.info
                        : AppColors.textMuted,
                  ),
                ),
              ),
              SizedBox(
                width: 78,
                child: Text(
                  Fmt.money(summary.totalPay),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              // Dấu cho biết chạm vào hàng là mở được chi tiết người này.
              const SizedBox(
                width: 18,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  final bool center;
  final bool right;
  const _Head(this.text, {this.center = false, this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center
          ? TextAlign.center
          : right
          ? TextAlign.right
          : TextAlign.left,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }
}
