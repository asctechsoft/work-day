import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';

/// Bottom sheet chọn số giờ tăng ca: 0.5h / 1h / 1.5h / 2h / Nhập khác.
///
/// Trả về số phút OT, hoặc null nếu người dùng bấm Huỷ.
Future<int?> showOtPicker(
  BuildContext context, {
  required String employeeName,
  required int currentMinutes,
  required List<int> presets,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (ctx) => _OtPickerSheet(
      employeeName: employeeName,
      currentMinutes: currentMinutes,
      presets: presets,
    ),
  );
}

class _OtPickerSheet extends StatelessWidget {
  final String employeeName;
  final int currentMinutes;
  final List<int> presets;

  const _OtPickerSheet({
    required this.employeeName,
    required this.currentMinutes,
    required this.presets,
  });

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
              'Chọn giờ tăng ca',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              employeeName,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 16),

            _option(
              context,
              label: 'Không tăng ca (0h)',
              value: 0,
              selected: currentMinutes == 0,
            ),
            for (final m in presets)
              _option(
                context,
                label: Fmt.otHours(m).replaceAll('h', ' giờ'),
                value: m,
                selected: currentMinutes == m,
              ),

            const SizedBox(height: 4),
            _CustomButton(
              currentMinutes: currentMinutes,
              onPicked: (m) => Navigator.of(context).pop(m),
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

  Widget _option(
    BuildContext context, {
    required String label,
    required int value,
    required bool selected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).pop(value),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primaryDark : AppColors.textDark,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomButton extends StatelessWidget {
  final int currentMinutes;
  final ValueChanged<int> onPicked;
  const _CustomButton({required this.currentMinutes, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final minutes = await _askCustom(context, currentMinutes);
          if (minutes != null) onPicked(minutes);
        },
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: const Text(
            'Nhập khác',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Future<int?> _askCustom(BuildContext context, int current) {
    final controller = TextEditingController(
      text: current > 0 ? (current / 60).toStringAsFixed(1) : '',
    );
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Nhập giờ tăng ca',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            hintText: 'Ví dụ: 2.5',
            suffixText: 'giờ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              final raw = controller.text.trim().replaceAll(',', '.');
              final hours = double.tryParse(raw);
              if (hours == null || hours < 0) {
                Navigator.of(ctx).pop();
                return;
              }
              // Làm tròn về mốc 5 phút, tối đa 24 giờ.
              final minutes = (hours * 60).round().clamp(0, 24 * 60);
              Navigator.of(ctx).pop((minutes / 5).round() * 5);
            },
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }
}
