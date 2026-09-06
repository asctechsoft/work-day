import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';
import 'common.dart';

/// Tab "Biểu đồ" của màn Tổng quan.
///
/// Cố tình KHÔNG vẽ mỗi nhân viên một thanh ngang. Lương trong một cơ sở
/// gần như bằng nhau (1,6tr - 2,1tr) nên 12 thanh dài xấp xỉ nhau vừa khó
/// nhìn vừa không nói lên điều gì - phần so sánh từng người đã có sẵn ở tab
/// "Danh sách nhân viên" dưới dạng bảng số.
///
/// Thay vào đó chỉ vẽ biểu đồ ở chỗ tỉ lệ thật sự có ý nghĩa (quỹ lương chia
/// làm gì, ngày công chia làm sao), còn lại trả lời thẳng bằng tên và số.
class SalaryChart extends StatelessWidget {
  final List<Employee> employees;
  final List<MonthlySummary> summaries;
  final String periodTitle;

  const SalaryChart({
    super.key,
    required this.employees,
    required this.summaries,
    required this.periodTitle,
  });

  @override
  Widget build(BuildContext context) {
    final names = {for (final e in employees) e.id: e.name};
    final worked = summaries.where((s) => s.markedDays > 0).toList();

    if (worked.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: EmptyState(
          icon: Icons.insights_rounded,
          title: 'Chưa có dữ liệu trong kỳ này',
          message: 'Hãy chấm công để app tổng hợp.',
        ),
      );
    }

    var basePay = 0.0;
    var otPay = 0.0;
    var presentDays = 0;
    var halfDays = 0;
    var absentDays = 0;
    for (final s in worked) {
      basePay += s.basePay;
      otPay += s.otPay;
      presentDays += s.presentDays;
      halfDays += s.halfDays;
      absentDays += s.absentDays;
    }

    return Column(
      children: [
        _PayrollCard(basePay: basePay, otPay: otPay),
        const SizedBox(height: 14),
        _WorkDaysCard(
          present: presentDays,
          half: halfDays,
          absent: absentDays,
        ),
        const SizedBox(height: 14),
        _HighlightsCard(summaries: worked, names: names),
      ],
    );
  }
}

// ---------------------------------------------------------------- Quỹ lương

/// Quỹ lương chia làm gì: lương công và tiền tăng ca.
class _PayrollCard extends StatelessWidget {
  final double basePay;
  final double otPay;
  const _PayrollCard({required this.basePay, required this.otPay});

  @override
  Widget build(BuildContext context) {
    final total = basePay + otPay;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Quỹ lương chia làm gì'),
          const SizedBox(height: 12),
          Text(
            Fmt.currency(total),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          _StackedBar(
            segments: [
              _Seg(basePay, AppColors.primary),
              _Seg(otPay, AppColors.overtime),
            ],
          ),
          const SizedBox(height: 14),
          _LegendLine(
            color: AppColors.primary,
            label: 'Lương công',
            value: Fmt.currency(basePay),
            percent: _percent(basePay, total),
          ),
          const SizedBox(height: 10),
          _LegendLine(
            color: AppColors.overtime,
            label: 'Tiền tăng ca',
            value: Fmt.currency(otPay),
            percent: _percent(otPay, total),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Ngày công

/// Ngày công chia làm sao: đi làm đủ / nửa công / nghỉ.
class _WorkDaysCard extends StatelessWidget {
  final int present;
  final int half;
  final int absent;

  const _WorkDaysCard({
    required this.present,
    required this.half,
    required this.absent,
  });

  @override
  Widget build(BuildContext context) {
    final marked = present + half + absent;
    final units = present + half * 0.5;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Ngày công trong kỳ'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Fmt.workUnits(units),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.present,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'công  ·  đã chấm $marked ngày',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StackedBar(
            segments: [
              _Seg(present.toDouble(), AppColors.present),
              _Seg(half.toDouble(), AppColors.info),
              _Seg(absent.toDouble(), AppColors.absent),
            ],
          ),
          const SizedBox(height: 14),
          _LegendLine(
            color: AppColors.present,
            label: 'Đi làm đủ ngày',
            value: '$present ngày',
            percent: _percent(present.toDouble(), marked.toDouble()),
          ),
          const SizedBox(height: 10),
          _LegendLine(
            color: AppColors.info,
            label: 'Nửa công',
            value: '$half ngày',
            percent: _percent(half.toDouble(), marked.toDouble()),
          ),
          const SizedBox(height: 10),
          _LegendLine(
            color: AppColors.absent,
            label: 'Nghỉ',
            value: '$absent ngày',
            percent: _percent(absent.toDouble(), marked.toDouble()),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Đáng chú ý

/// Trả lời thẳng bằng tên và số, không bắt người dùng đo độ dài thanh.
class _HighlightsCard extends StatelessWidget {
  final List<MonthlySummary> summaries;
  final Map<String, String> names;

  const _HighlightsCard({required this.summaries, required this.names});

  @override
  Widget build(BuildContext context) {
    final byPay = [...summaries]
      ..sort((a, b) => b.totalPay.compareTo(a.totalPay));
    final byAbsent = summaries.where((s) => s.absentDays > 0).toList()
      ..sort((a, b) => b.absentDays.compareTo(a.absentDays));
    final byOt = summaries.where((s) => s.overtimeMinutes > 0).toList()
      ..sort((a, b) => b.overtimeMinutes.compareTo(a.overtimeMinutes));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Đáng chú ý'),
          const SizedBox(height: 6),

          _Highlight(
            icon: Icons.arrow_upward_rounded,
            color: AppColors.primaryDark,
            label: 'Lương cao nhất',
            name: names[byPay.first.employeeId] ?? '',
            value: Fmt.currency(byPay.first.totalPay),
          ),
          _Highlight(
            icon: Icons.arrow_downward_rounded,
            color: AppColors.textMuted,
            label: 'Lương thấp nhất',
            name: names[byPay.last.employeeId] ?? '',
            value: Fmt.currency(byPay.last.totalPay),
          ),
          _Highlight(
            icon: Icons.event_busy_rounded,
            color: AppColors.absent,
            label: 'Nghỉ nhiều nhất',
            name: byAbsent.isEmpty
                ? null
                : names[byAbsent.first.employeeId] ?? '',
            value: byAbsent.isEmpty
                ? 'Cả kỳ không ai nghỉ'
                : '${byAbsent.first.absentDays} ngày',
            extra: byAbsent.length > 1
                ? 'và ${byAbsent.length - 1} người khác có nghỉ'
                : null,
          ),
          _Highlight(
            icon: Icons.more_time_rounded,
            color: AppColors.overtime,
            label: 'Tăng ca nhiều nhất',
            name: byOt.isEmpty ? null : names[byOt.first.employeeId] ?? '',
            value: byOt.isEmpty
                ? 'Cả kỳ không có tăng ca'
                : Fmt.otHours(byOt.first.overtimeMinutes),
            extra: byOt.length > 1
                ? 'và ${byOt.length - 1} người khác có tăng ca'
                : null,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? name;
  final String value;
  final String? extra;
  final bool last;

  const _Highlight({
    required this.icon,
    required this.color,
    required this.label,
    required this.name,
    required this.value,
    this.extra,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name ?? value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: name == null
                        ? AppColors.textMuted
                        : AppColors.textDark,
                  ),
                ),
                if (extra != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    extra!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (name != null) ...[
            const SizedBox(width: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Thành phần

class _Seg {
  final double value;
  final Color color;
  const _Seg(this.value, this.color);
}

/// Một thanh ngang duy nhất chia theo tỉ lệ - đây là chỗ biểu đồ thực sự
/// có ích, vì các phần chênh nhau rõ rệt.
class _StackedBar extends StatelessWidget {
  final List<_Seg> segments;
  const _StackedBar({required this.segments});

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        height: 14,
        child: total <= 0
            ? const ColoredBox(color: AppColors.background)
            : Row(
                children: [
                  for (final s in segments)
                    // Quy về phần nghìn để flex luôn là số nguyên nhỏ,
                    // tránh tràn số khi lấy thẳng số tiền làm flex.
                    if (s.value > 0)
                      Expanded(
                        flex: (s.value / total * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: s.color),
                      ),
                ],
              ),
      ),
    );
  }
}

/// Một dòng chú giải: chấm màu, nhãn, số phần trăm, giá trị.
class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final String percent;

  const _LegendLine({
    required this.color,
    required this.label,
    required this.value,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textBody),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            percent,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

String _percent(double value, double total) {
  if (total <= 0) return '0%';
  final p = value / total * 100;
  if (p > 0 && p < 1) return '<1%';
  return '${p.round()}%';
}
