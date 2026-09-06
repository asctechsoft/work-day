import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/attendance_record.dart';
import '../../widgets/common.dart';

/// Kết quả người dùng chọn trong bảng chấm công của một nhân viên.
class AttendanceChoice {
  final AttendanceStatus status;
  final int overtimeMinutes;

  /// true = xoá hẳn bản ghi, đưa về "Chưa chấm".
  final bool clear;

  const AttendanceChoice({
    required this.status,
    required this.overtimeMinutes,
    this.clear = false,
  });

  const AttendanceChoice.clear()
      : status = AttendanceStatus.none,
        overtimeMinutes = 0,
        clear = true;
}

/// Bảng chọn đầy đủ cho một nhân viên: đủ công / nửa công / nghỉ / xoá chấm.
///
/// Chạm nhanh vào chip trạng thái ở danh sách vẫn chỉ đổi qua lại Đi làm và
/// Nghỉ cho nhanh tay. Bảng này dành cho các trường hợp còn lại.
Future<AttendanceChoice?> showStatusPicker(
  BuildContext context, {
  required String employeeName,
  required AttendanceStatus current,
  required int currentOvertime,
  required String dateLabel,
}) {
  return showModalBottomSheet<AttendanceChoice>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (_) => _StatusPickerSheet(
      employeeName: employeeName,
      current: current,
      currentOvertime: currentOvertime,
      dateLabel: dateLabel,
    ),
  );
}

class _StatusPickerSheet extends StatelessWidget {
  final String employeeName;
  final AttendanceStatus current;
  final int currentOvertime;
  final String dateLabel;

  const _StatusPickerSheet({
    required this.employeeName,
    required this.current,
    required this.currentOvertime,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              employeeName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              dateLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),

            _option(context, AttendanceStatus.present, AppColors.present,
                AppColors.presentSoft, Icons.check_circle_rounded),
            _option(context, AttendanceStatus.half, AppColors.info,
                AppColors.infoSoft, Icons.timelapse_rounded),
            _option(context, AttendanceStatus.absent, AppColors.absent,
                AppColors.absentSoft, Icons.cancel_rounded),

            if (current != AttendanceStatus.none) ...[
              const SizedBox(height: 4),
              const Divider(height: 20),
              _clearButton(context),
            ],

            const SizedBox(height: 6),
            SizedBox(
              height: 46,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
                child: const Text(
                  'Đóng',
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
    BuildContext context,
    AttendanceStatus status,
    Color color,
    Color background,
    IconData icon,
  ) {
    final selected = current == status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? background : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).pop(
            AttendanceChoice(
              status: status,
              overtimeMinutes: currentOvertime,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? color : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? color : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status.hint,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, size: 20, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _clearButton(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            Navigator.of(context).pop(const AttendanceChoice.clear()),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              const Icon(
                Icons.undo_rounded,
                size: 22,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bỏ chấm công',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentOvertime > 0
                          ? 'Về "Chưa chấm", xoá cả ${Fmt.otHours(currentOvertime)} tăng ca'
                          : 'Chấm nhầm thì đưa về "Chưa chấm"',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng giải thích cách chấm công - mở từ nút "?" trên thanh tiêu đề.
Future<void> showAttendanceHelp(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionTitle('Cách chấm công'),
            const SizedBox(height: 16),

            _helpRow(
              AppColors.present,
              AppColors.presentSoft,
              'Đi làm',
              'Làm đủ ngày. Tính 1 công.',
            ),
            _helpRow(
              AppColors.info,
              AppColors.infoSoft,
              'Nửa công',
              'Có đến làm nhưng về giữa chừng. Tính 0,5 công.',
            ),
            _helpRow(
              AppColors.absent,
              AppColors.absentSoft,
              'Nghỉ',
              'Không đi làm. Tính 0 công.',
            ),
            _helpRow(
              AppColors.textMuted,
              AppColors.background,
              'Chưa chấm',
              'Chưa có dữ liệu. Không tính công, không tính nghỉ.',
            ),

            const Divider(height: 30),
            const Text(
              'Thao tác',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            const _Bullet(
              'Chạm vào ô trạng thái để đổi nhanh giữa Đi làm và Nghỉ.',
            ),
            const _Bullet(
              'Chạm vào nút ⋯ cạnh tên nhân viên để chọn Nửa công hoặc bỏ '
              'chấm công nếu lỡ bấm nhầm.',
            ),
            const _Bullet(
              'Chạm vào ô giờ bên phải để nhập tăng ca. Tăng ca ghi riêng, '
              'không làm thay đổi số công.',
            ),
            const _Bullet(
              'Nút "Tất cả đi làm" chấm cả danh sách một lượt, sau đó chỉ '
              'sửa lại người nghỉ. Bấm nhầm thì chọn "Hoàn tác" ngay sau đó.',
            ),
            const _Bullet(
              'Chỉ chấm được cho hôm nay và các ngày đã qua. Ngày chưa tới '
              'thì phải đợi đúng ngày đó.',
            ),
            const _Bullet(
              'Chấm lại cùng một ngày là sửa đè lên dữ liệu cũ, không bao '
              'giờ cộng trùng.',
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _helpRow(Color color, Color background, String title, String desc) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              desc,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textBody,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle,
              size: 5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textBody,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
