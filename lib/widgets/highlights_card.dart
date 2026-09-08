import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/attendance_record.dart';
import 'common.dart';

/// Thẻ "Đáng chú ý" ở tab Danh sách nhân viên của màn Tổng quan.
///
/// Trả lời thẳng bốn câu hỏi hay gặp nhất bằng **tên người và con số**:
/// ai lương cao nhất / thấp nhất, ai nghỉ nhiều nhất, ai tăng ca nhiều nhất.
///
/// Từng nằm chung với hai thẻ vẽ thanh tỉ lệ ("Quỹ lương chia làm gì" và
/// "Ngày công trong kỳ") ở tab Biểu đồ. Người dùng bỏ hai thẻ đó vì thừa -
/// mấy con số ấy đã có sẵn ở hàng thống kê đầu màn - và chuyển thẻ này sang
/// nằm ngay dưới bảng lương, đúng chỗ đang so sánh giữa các nhân viên.
/// Xem §5.1 của CLAUDE.md trước khi thêm biểu đồ mới.
class HighlightsCard extends StatelessWidget {
  final List<MonthlySummary> summaries;
  final Map<String, String> names;

  const HighlightsCard({
    super.key,
    required this.summaries,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    // Chỉ xét người thực sự có công trong kỳ; ai chưa chấm ngày nào mà lọt vào
    // đây thì luôn đứng hạng "lương thấp nhất" với 0đ, chẳng nói lên gì.
    final worked = summaries.where((s) => s.markedDays > 0).toList();
    // Chưa chấm ngày nào thì không có gì để "đáng chú ý" - bảng lương ngay
    // trên đã nói đủ.
    if (worked.isEmpty) return const SizedBox.shrink();

    final byPay = [...worked]
      ..sort((a, b) => b.totalPay.compareTo(a.totalPay));
    final byAbsent = worked.where((s) => s.absentDays > 0).toList()
      ..sort((a, b) => b.absentDays.compareTo(a.absentDays));
    final byOt = worked.where((s) => s.overtimeMinutes > 0).toList()
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
