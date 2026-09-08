import 'package:flutter/material.dart';

import '../../core/pay_period.dart';
import '../../core/theme.dart';

/// Bảng chọn kỳ lương ở tab Tổng quan.
///
/// Trước đây chỉ có hai nút ‹ › nên muốn xem kỳ cách đây nửa năm phải bấm sáu
/// lần, mà nhìn vào cũng không biết kỳ đang xem chạy từ ngày nào tới ngày nào.
/// Bảng này liệt kê thẳng từng kỳ kèm khoảng ngày để chọn một phát là xong.
///
/// Trả về `anchor` (tháng chốt) của kỳ được chọn, hoặc null nếu bấm Huỷ.
Future<DateTime?> showPeriodPicker(
  BuildContext context, {
  required PayPeriod current,
  required int startDay,
  int monthsBack = 24,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _PeriodPickerSheet(
      current: current,
      startDay: startDay,
      monthsBack: monthsBack,
    ),
  );
}

class _PeriodPickerSheet extends StatelessWidget {
  final PayPeriod current;
  final int startDay;
  final int monthsBack;

  const _PeriodPickerSheet({
    required this.current,
    required this.startDay,
    required this.monthsBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final currentPeriod = PayPeriod.current(startDay, now: today);

    // Từ kỳ đang diễn ra lùi dần về trước; kỳ chưa bắt đầu thì không liệt kê,
    // xem một kỳ chưa tới ngày nào cũng chỉ ra bảng rỗng.
    final periods = [
      for (var i = 0; i < monthsBack; i++) currentPeriod.shift(-i, startDay),
    ];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn kỳ lương',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  startDay == 1
                      ? 'Kỳ lương đang tính theo tháng dương lịch. Đổi ngày '
                          'chốt kỳ ở Cài đặt > Thiết lập chung.'
                      : 'Kỳ lương chốt vào ngày ${startDay - 1} hằng tháng, '
                          'tính từ ngày $startDay của tháng trước.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              shrinkWrap: true,
              itemCount: periods.length,
              itemBuilder: (context, i) {
                final p = periods[i];
                return _PeriodRow(
                  period: p,
                  selected: p == current,
                  isCurrent: i == 0,
                  onTap: () => Navigator.of(context).pop(p.anchor),
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text(
                      'Huỷ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(currentPeriod.anchor),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('Về kỳ này'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final PayPeriod period;
  final bool selected;

  /// Kỳ đang diễn ra - đánh dấu để người dùng khỏi nhầm với kỳ đã chốt xong.
  final bool isCurrent;
  final VoidCallback onTap;

  const _PeriodRow({
    required this.period,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              period.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? AppColors.primaryDark
                                    : AppColors.textDark,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.presentSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Đang diễn ra',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.present,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Khoảng ngày là thứ người dùng cần nhất: "công của
                      // tháng đó tính từ ngày nào đến ngày nào".
                      Text(
                        period.fullRangeLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
