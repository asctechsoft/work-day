import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/attendance_record.dart';
import '../../models/employee.dart';
import '../../widgets/common.dart';

/// Một dòng chấm công: tên + chip trạng thái + chip OT.
///
/// Chạm chip trạng thái = đổi nhanh Đi làm / Nghỉ.
/// Chạm vào dòng hoặc nút mũi tên cuối dòng = mở bảng đủ 4 lựa chọn
/// (kể cả nửa công và bỏ chấm).
class AttendanceRow extends StatelessWidget {
  /// Số thứ tự hiển thị (bắt đầu từ 1), để người dùng dễ dò theo bảng giấy.
  final int index;
  final Employee employee;
  final AttendanceRecord? record;
  final bool locked;
  final VoidCallback onToggleStatus;
  final VoidCallback onEditOvertime;
  final VoidCallback onPickStatus;

  const AttendanceRow({
    super.key,
    required this.index,
    required this.employee,
    required this.record,
    required this.locked,
    required this.onToggleStatus,
    required this.onEditOvertime,
    required this.onPickStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = record?.status ?? AttendanceStatus.none;
    final ot = record?.overtimeMinutes ?? 0;

    final (statusColor, statusBg) = switch (status) {
      AttendanceStatus.present => (AppColors.present, AppColors.presentSoft),
      AttendanceStatus.half => (AppColors.info, AppColors.infoSoft),
      AttendanceStatus.absent => (AppColors.absent, AppColors.absentSoft),
      AttendanceStatus.none => (AppColors.textMuted, AppColors.background),
    };

    final radius = BorderRadius.circular(14);

    return Opacity(
      opacity: locked ? 0.55 : 1,
      // Chạm bất cứ chỗ nào trên dòng (số thứ tự, avatar, tên, khoảng trống)
      // đều mở bảng chọn. Hai chip và nút mũi tên có Material riêng nên vẫn
      // giữ được thao tác riêng của chúng.
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: locked ? null : onPickStatus,
          borderRadius: radius,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 6, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '$index',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      EmployeeAvatar(initials: employee.initials, size: 38),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          employee.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TagChip(
                text: status.label,
                color: statusColor,
                background: statusBg,
                onTap: locked ? null : onToggleStatus,
                minWidth: 62,
              ),
              const SizedBox(width: 6),
              TagChip(
                text: Fmt.otHours(ot),
                color: ot > 0 ? AppColors.overtime : AppColors.textMuted,
                background:
                    ot > 0 ? AppColors.overtimeSoft : AppColors.background,
                onTap: locked ? null : onEditOvertime,
                minWidth: 46,
              ),
              const SizedBox(width: 2),
              // Nút mở bảng chọn đầy đủ (nửa công / bỏ chấm), nằm cuối dòng.
              IconButton(
                onPressed: locked ? null : onPickStatus,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                iconSize: 22,
                color: AppColors.textMuted,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                tooltip: 'Thêm lựa chọn',
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
