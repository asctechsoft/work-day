import 'package:flutter/foundation.dart';

/// Kênh liên lạc nhỏ giữa các tab.
///
/// Dùng khi màn Chi tiết nhân viên bấm vào một ngày và muốn quay về
/// tab Chấm công của đúng ngày đó để sửa.
class AppEvents {
  AppEvents._();

  /// Ngày mà tab Chấm công cần nhảy tới.
  static final ValueNotifier<DateTime?> jumpToDate =
      ValueNotifier<DateTime?>(null);

  /// Yêu cầu chuyển tab từ một màn đang nằm ngoài HomeShell.
  /// 0: Chấm công, 1: Tổng quan, 2: Cài đặt.
  static final ValueNotifier<int?> requestTab = ValueNotifier<int?>(null);

  /// Mở tab Chấm công tại một ngày cụ thể.
  static void editAttendanceOn(DateTime day) {
    jumpToDate.value = DateTime(day.year, day.month, day.day);
    requestTab.value = 0;
  }
}
