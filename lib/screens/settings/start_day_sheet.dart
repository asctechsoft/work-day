import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Bottom sheet chọn ngày bắt đầu kỳ lương (1..28) - lưới ô ngày như một
/// tháng, thay cho dropdown cũ để chạm chọn trực quan hơn.
///
/// Chạm vào một ô là chọn luôn và đóng bảng, không cần nút xác nhận riêng.
/// Trả về ngày đã chọn, hoặc null nếu người dùng bấm Huỷ.
Future<int?> showStartDaySheet(
  BuildContext context, {
  required int selected,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _StartDaySheet(selected: selected),
  );
}

class _StartDaySheet extends StatelessWidget {
  final int selected;
  const _StartDaySheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bắt đầu từ ngày',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ngày trong tháng mà kỳ lương bắt đầu. Chọn 1 nếu chốt đúng '
              'theo tháng dương lịch.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // 28 ô vừa đúng 4 hàng x 7 cột, giới hạn 1..28 để không vướng
            // tháng 2 và tháng ít hơn 31 ngày (xem PayPeriod).
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 28,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = day == selected;
                return Material(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.of(context).pop(day),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Huỷ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
