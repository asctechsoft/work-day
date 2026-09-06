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
import '../../widgets/salary_chart.dart';
import 'employee_month_screen.dart';

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
  int _view = 0; // 0 = danh sách, 1 = biểu đồ
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
                subLabel: period.isCalendarMonth ? null : period.rangeLabel,
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
              const SizedBox(height: 12),
              StatRow(
                children: [
                  StatTile(
                    value: '${employees.length}',
                    label: 'Tổng nhân viên',
                  ),
                  StatTile(
                    value: Fmt.workUnits(totalUnits),
                    label: 'Tổng công',
                    color: AppColors.present,
                  ),
                  StatTile(
                    value: Fmt.otHours(totalOt),
                    label: 'Tổng OT',
                    color: AppColors.info,
                  ),
                  StatTile(
                    value: Fmt.moneyCompact(totalPay),
                    label: 'Tổng quỹ lương',
                    color: AppColors.primaryDark,
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
        else if (_view == 0)
          _SummaryTable(
            employees: employees,
            summaries: summaries,
            period: period,
          )
        else
          SalaryChart(
            employees: employees,
            summaries: summaries,
            periodTitle: period.title,
          ),

        if (employees.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                _totalLine('Tổng công của kỳ', Fmt.workUnits(totalUnits)),
                const Divider(height: 20),
                _totalLine('Tổng giờ tăng ca', Fmt.otHours(totalOt)),
                const Divider(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tổng quỹ lương',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      Fmt.currency(totalPay),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ExportCard(
            period: period,
            busy: _exporting,
            onExport: _export,
          ),
        ],
      ],
    );
  }

  Widget _totalLine(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: AppColors.textBody)),
      ),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    ],
  );
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
          _tab('Danh sách nhân viên', 0),
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

  const _SummaryTable({
    required this.employees,
    required this.summaries,
    required this.period,
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
              ],
            ),
          ),
          for (var i = 0; i < employees.length; i++)
            _row(context, i, employees[i], byId[employees[i].id]),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    int index,
    Employee e,
    MonthlySummary? s,
  ) {
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

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeeMonthScreen(employee: e, period: period),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
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
          ],
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
