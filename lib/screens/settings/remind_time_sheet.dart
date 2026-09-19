import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Bottom sheet chọn giờ nhắc chấm công cuối ngày - một bánh xe cuộn giờ:phút
/// thay vì hai dropdown tách rời, gõ vào là cuộn được ngay.
///
/// Trả về `(giờ, phút)`, hoặc null nếu người dùng bấm Huỷ.
Future<(int, int)?> showRemindTimeSheet(
  BuildContext context, {
  required int hour,
  required int minute,
}) {
  return showModalBottomSheet<(int, int)>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _RemindTimeSheet(hour: hour, minute: minute),
  );
}

class _RemindTimeSheet extends StatefulWidget {
  final int hour;
  final int minute;
  const _RemindTimeSheet({required this.hour, required this.minute});

  @override
  State<_RemindTimeSheet> createState() => _RemindTimeSheetState();
}

class _RemindTimeSheetState extends State<_RemindTimeSheet> {
  late int _hour = widget.hour;
  late int _minute = widget.minute.clamp(0, 59);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nhắc chấm công vào lúc',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 170,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: _hour,
                          ),
                          itemExtent: 40,
                          selectionOverlay: const SizedBox.shrink(),
                          onSelectedItemChanged: (i) =>
                              setState(() => _hour = i),
                          children: [
                            for (var h = 0; h < 24; h++)
                              Center(child: _wheelText('${h.toString().padLeft(2, '0')} giờ')),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: _minute,
                          ),
                          itemExtent: 40,
                          selectionOverlay: const SizedBox.shrink(),
                          onSelectedItemChanged: (i) =>
                              setState(() => _minute = i),
                          children: [
                            for (var m = 0; m < 60; m++)
                              Center(
                                child: _wheelText(
                                  '${m.toString().padLeft(2, '0')} phút',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop((_hour, _minute)),
                child: const Text('Xong'),
              ),
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

  Widget _wheelText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    );
  }
}
