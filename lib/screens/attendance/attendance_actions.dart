import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/app_settings.dart';
import '../../models/attendance_record.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';
import 'ot_picker_sheet.dart';
import 'status_picker_sheet.dart';

/// Các thao tác chấm công của một ngày, dùng chung cho tab Chấm công và
/// màn tìm kiếm nhân viên - hai chỗ phải hành xử giống hệt nhau.
class AttendanceActions {
  final DataService data;
  final DateTime date;
  final AppSettings settings;

  const AttendanceActions({
    required this.data,
    required this.date,
    required this.settings,
  });

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Ngày chưa tới thì không cho chấm - phải đợi đúng sang ngày đó.
  bool get isFuture => date.isAfter(_today);

  bool _guardEditable(BuildContext context) {
    if (!isFuture) return true;
    showToast(
      context,
      'Ngày này chưa tới, phải đợi đúng ngày mới chấm được',
      error: true,
    );
    return false;
  }

  /// Chạm nhanh vào chip trạng thái: đổi qua lại Đi làm và Nghỉ.
  /// Các trường hợp còn lại (nửa công, bỏ chấm) nằm trong bảng chọn đầy đủ.
  Future<void> toggleStatus(
    BuildContext context,
    Employee e,
    AttendanceRecord? current,
  ) async {
    if (!_guardEditable(context)) return;
    final next = switch (current?.status) {
      AttendanceStatus.present ||
      AttendanceStatus.half =>
        AttendanceStatus.absent,
      _ => AttendanceStatus.present,
    };
    await write(
      context,
      e,
      status: next,
      overtimeMinutes: current?.overtimeMinutes ?? 0,
    );
  }

  /// Chạm vào dòng: mở bảng đủ 4 lựa chọn.
  Future<void> pickStatus(
    BuildContext context,
    Employee e,
    AttendanceRecord? current,
  ) async {
    if (!_guardEditable(context)) return;
    final choice = await showStatusPicker(
      context,
      employeeName: e.name,
      current: current?.status ?? AttendanceStatus.none,
      currentOvertime: current?.overtimeMinutes ?? 0,
      dateLabel: Fmt.fullDate(date),
    );
    if (choice == null || !context.mounted) return;

    if (choice.clear) {
      try {
        await data.clearRecord(e.id, Fmt.dateKey(date));
        if (context.mounted) {
          showToast(context, 'Đã bỏ chấm công của ${e.name}');
        }
      } catch (err) {
        if (context.mounted) {
          showToast(context, 'Không xoá được: $err', error: true);
        }
      }
      return;
    }

    await write(
      context,
      e,
      status: choice.status,
      overtimeMinutes: choice.overtimeMinutes,
    );
  }

  Future<void> editOvertime(
    BuildContext context,
    Employee e,
    AttendanceRecord? current,
  ) async {
    if (!_guardEditable(context)) return;
    final minutes = await showOtPicker(
      context,
      employeeName: e.name,
      currentMinutes: current?.overtimeMinutes ?? 0,
      presets: settings.otPresets,
    );
    if (minutes == null || !context.mounted) return;
    await write(
      context,
      e,
      // Nhập OT cho người chưa chấm thì mặc định coi như đã đi làm;
      // ai đã có trạng thái thì giữ nguyên trạng thái đó.
      status:
          current?.status == null || current!.status == AttendanceStatus.none
              ? AttendanceStatus.present
              : current.status,
      overtimeMinutes: minutes,
    );
  }

  Future<void> write(
    BuildContext context,
    Employee e, {
    required AttendanceStatus status,
    required int overtimeMinutes,
  }) async {
    try {
      await data.saveRecord(
        AttendanceRecord.forDay(
          employeeId: e.id,
          day: date,
          status: status,
          overtimeMinutes: overtimeMinutes,
        ),
      );
    } catch (err) {
      if (context.mounted) {
        showToast(context, 'Không lưu được: $err', error: true);
      }
    }
  }
}
