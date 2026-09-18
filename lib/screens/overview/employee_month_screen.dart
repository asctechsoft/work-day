import 'package:flutter/material.dart';

import '../../core/app_events.dart';
import '../../core/formatters.dart';
import '../../core/pay_period.dart';
import '../../core/theme.dart';
import '../../models/attendance_record.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';

/// Chi tiết một nhân viên theo kỳ lương: tổng công, OT, cách tính lương
/// và lịch sử chấm công từng ngày.
class EmployeeMonthScreen extends StatefulWidget {
  final Employee employee;
  final PayPeriod period;

  /// Quy đổi công Tuỳ chỉnh ra giờ khi hiện lịch sử từng ngày.
  final int workHoursPerDay;

  const EmployeeMonthScreen({
    super.key,
    required this.employee,
    required this.period,
    required this.workHoursPerDay,
  });

  @override
  State<EmployeeMonthScreen> createState() => _EmployeeMonthScreenState();
}

class _EmployeeMonthScreenState extends State<EmployeeMonthScreen> {
  final _data = DataService.instance;
  late PayPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = widget.period;
  }

  void _shiftMonth(int months) {
    setState(
      () => _period = _period.shift(months, _period.start.day),
    );
  }

  /// Bấm vào một ngày để quay về màn Chấm công và sửa dữ liệu.
  void _editDay(DateTime day) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    AppEvents.editAttendanceOn(day);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết nhân viên')),
      body: StreamBuilder<List<AttendanceRecord>>(
        stream: _data.watchEmployeePeriod(e.id, _period),
        builder: (context, snap) {
          final records = snap.data ?? const <AttendanceRecord>[];

          var units = 0.0;
          var absent = 0;
          var ot = 0;
          for (final r in records) {
            units += r.workUnits;
            if (r.status == AttendanceStatus.absent) absent++;
            ot += r.overtimeMinutes;
          }

          final summary = MonthlySummary(
            employeeId: e.id,
            totalWorkUnits: units,
            absentDays: absent,
            overtimeMinutes: ot,
            dailySalary: e.dailySalary,
            otRate: e.otRate,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                children: [
                  EmployeeAvatar(initials: e.initials, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.active ? 'Nhân viên' : 'Đã nghỉ',
                          style: TextStyle(
                            fontSize: 13,
                            color: e.active
                                ? AppColors.textMuted
                                : AppColors.absent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              PeriodSelector(
                label: _period.title,
                // Cùng cách hiện như tab Tổng quan: luôn nói rõ kỳ này tính
                // công từ ngày nào đến ngày nào.
                subLabel: 'Tính công ${_period.rangeLabel}',
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
              const SizedBox(height: 14),

              StatRow(
                children: [
                  StatTile(
                    value: Fmt.workUnits(units),
                    label: 'Công',
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
                    value: Fmt.otHours(ot),
                    label: 'Tăng ca',
                    color: AppColors.info,
                    icon: Icons.access_time_filled_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Tính lương'),
                    const SizedBox(height: 14),
                    _payLine(
                      'Lương cơ bản',
                      '${Fmt.workUnits(units)} công × '
                          '${Fmt.money(e.dailySalary)}',
                      summary.basePay,
                    ),
                    const SizedBox(height: 10),
                    _payLine(
                      'Tăng ca',
                      e.otRate <= 0
                          ? 'Không tính tiền tăng ca'
                          : '${Fmt.otHours(ot)} × ${Fmt.money(e.otRate)}',
                      summary.otPay,
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tổng lương',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Text(
                          Fmt.currency(summary.totalPay),
                          style: const TextStyle(
                            fontSize: 18,
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

              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Lịch sử chấm công'),
                    const SizedBox(height: 6),
                    if (records.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Kỳ này chưa có dữ liệu chấm công.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      for (final r in records) _dayRow(r),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Chạm vào một ngày để sửa lại chấm công',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _payLine(String label, String detail, double amount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          Fmt.currency(amount),
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _dayRow(AttendanceRecord r) {
    final day = Fmt.parseDateKey(r.workDate);
    final statusColor = switch (r.status) {
      AttendanceStatus.present => AppColors.present,
      AttendanceStatus.half => AppColors.info,
      AttendanceStatus.absent => AppColors.absent,
      AttendanceStatus.custom => AppColors.custom,
      AttendanceStatus.none => AppColors.textMuted,
    };
    final statusLabel = r.status == AttendanceStatus.custom
        ? '${r.status.label} · ${Fmt.customWorkHours(r.workUnits, widget.workHoursPerDay)}'
        : r.status.label;

    return InkWell(
      onTap: () => _editDay(day),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: Text(
                Fmt.dayMonth(day),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Expanded(
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            if (r.overtimeMinutes > 0)
              TagChip(
                text: '+${Fmt.otHours(r.overtimeMinutes)} OT',
                color: AppColors.overtime,
                background: AppColors.overtimeSoft,
              ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
