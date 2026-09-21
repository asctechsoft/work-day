import 'package:cloud_firestore/cloud_firestore.dart';

/// Thiết lập chung của app (một bản ghi duy nhất: settings/app).
class AppSettings {
  final String orgName;
  final String currency;

  /// Các mốc OT nhanh tính bằng phút, mặc định 30/60/90/120.
  final List<int> otPresets;

  /// Số giờ một ngày làm việc. Dùng để gợi ý đơn giá OT, và để quy đổi số
  /// giờ đã làm ra số công khi chấm công Tuỳ chỉnh (§0.4 CLAUDE.md).
  final int workHoursPerDay;

  /// Lương/ngày mặc định khi thêm nhân viên mới.
  final double defaultDailySalary;

  /// Đơn giá OT/giờ mặc định khi thêm nhân viên mới.
  final double defaultOtRate;

  /// Ngày bắt đầu kỳ lương (1..28).
  /// 1 = chốt đúng tháng dương lịch.
  /// 26 = kỳ lương chạy từ ngày 26 tháng trước đến ngày 25 tháng này.
  final int payPeriodStartDay;

  /// Có nhắc chấm công cuối ngày không - xem `services/notification_service.dart`.
  final bool remindEnabled;

  /// Giờ nhắc (0..23), mặc định 18h.
  final int remindHour;

  /// Phút nhắc (0..59, làm tròn về mốc 5 phút ở UI), mặc định 0.
  final int remindMinute;

  /// Danh sách ngày lễ (yyyy-MM-dd) được trả OT theo đơn giá riêng
  /// (`Employee.otRateHoliday`). Nhập tay ở Cài đặt vì app không có sẵn
  /// lịch ngày lễ - danh sách ngày lễ mỗi năm một khác, kể cả lễ âm lịch.
  final List<String> holidayDates;

  /// Hệ số nhân lương công của ngày lễ (2 = gấp đôi, 3 = gấp ba...).
  /// Mặc định 1 = không nhân. Áp dụng cho **cả cơ sở**, không phải riêng
  /// từng nhân viên - khác `Employee.otRateHoliday` (chỉ áp cho phần tăng
  /// ca, xem `MonthlySummary.basePay`/`otPay`).
  final double holidayPayMultiplier;

  const AppSettings({
    this.orgName = 'WorkDay',
    this.currency = 'VND',
    this.otPresets = const [30, 60, 90, 120],
    this.workHoursPerDay = 8,
    this.defaultDailySalary = 200000,
    this.defaultOtRate = 50000,
    this.payPeriodStartDay = 1,
    this.remindEnabled = true,
    this.remindHour = 18,
    this.remindMinute = 0,
    this.holidayDates = const [],
    this.holidayPayMultiplier = 1,
  });

  factory AppSettings.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const AppSettings();
    final presets = (d['otPresets'] as List?)
        ?.map((e) => (e as num).toInt())
        .where((e) => e > 0)
        .toList();
    return AppSettings(
      orgName: (d['orgName'] ?? 'WorkDay') as String,
      currency: (d['currency'] ?? 'VND') as String,
      otPresets: (presets == null || presets.isEmpty)
          ? const [30, 60, 90, 120]
          : presets,
      workHoursPerDay: (d['workHoursPerDay'] as num?)?.toInt() ?? 8,
      defaultDailySalary:
          (d['defaultDailySalary'] as num?)?.toDouble() ?? 200000,
      defaultOtRate: (d['defaultOtRate'] as num?)?.toDouble() ?? 50000,
      payPeriodStartDay:
          ((d['payPeriodStartDay'] as num?)?.toInt() ?? 1).clamp(1, 28),
      remindEnabled: (d['remindEnabled'] as bool?) ?? true,
      remindHour: ((d['remindHour'] as num?)?.toInt() ?? 18).clamp(0, 23),
      remindMinute: ((d['remindMinute'] as num?)?.toInt() ?? 0).clamp(0, 59),
      holidayDates: (d['holidayDates'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      holidayPayMultiplier:
          ((d['holidayPayMultiplier'] as num?)?.toDouble() ?? 1).clamp(1, 10),
    );
  }

  Map<String, dynamic> toMap() => {
        'orgName': orgName,
        'currency': currency,
        'otPresets': otPresets,
        'workHoursPerDay': workHoursPerDay,
        'defaultDailySalary': defaultDailySalary,
        'defaultOtRate': defaultOtRate,
        'payPeriodStartDay': payPeriodStartDay,
        'remindEnabled': remindEnabled,
        'remindHour': remindHour,
        'remindMinute': remindMinute,
        'holidayDates': holidayDates,
        'holidayPayMultiplier': holidayPayMultiplier,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AppSettings copyWith({
    String? orgName,
    String? currency,
    List<int>? otPresets,
    int? workHoursPerDay,
    double? defaultDailySalary,
    double? defaultOtRate,
    int? payPeriodStartDay,
    bool? remindEnabled,
    int? remindHour,
    int? remindMinute,
    List<String>? holidayDates,
    double? holidayPayMultiplier,
  }) =>
      AppSettings(
        orgName: orgName ?? this.orgName,
        currency: currency ?? this.currency,
        otPresets: otPresets ?? this.otPresets,
        workHoursPerDay: workHoursPerDay ?? this.workHoursPerDay,
        defaultDailySalary: defaultDailySalary ?? this.defaultDailySalary,
        defaultOtRate: defaultOtRate ?? this.defaultOtRate,
        payPeriodStartDay: payPeriodStartDay ?? this.payPeriodStartDay,
        remindEnabled: remindEnabled ?? this.remindEnabled,
        remindHour: remindHour ?? this.remindHour,
        remindMinute: remindMinute ?? this.remindMinute,
        holidayDates: holidayDates ?? this.holidayDates,
        holidayPayMultiplier: holidayPayMultiplier ?? this.holidayPayMultiplier,
      );
}
