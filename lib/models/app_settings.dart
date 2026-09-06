import 'package:cloud_firestore/cloud_firestore.dart';

/// Thiết lập chung của app (một bản ghi duy nhất: settings/app).
class AppSettings {
  final String orgName;
  final String currency;

  /// Các mốc OT nhanh tính bằng phút, mặc định 30/60/90/120.
  final List<int> otPresets;

  /// Số giờ một ngày làm việc - chỉ dùng để gợi ý đơn giá OT.
  final int workHoursPerDay;

  /// Lương/ngày mặc định khi thêm nhân viên mới.
  final double defaultDailySalary;

  /// Đơn giá OT/giờ mặc định khi thêm nhân viên mới.
  final double defaultOtRate;

  /// Ngày bắt đầu kỳ lương (1..28).
  /// 1 = chốt đúng tháng dương lịch.
  /// 26 = kỳ lương chạy từ ngày 26 tháng trước đến ngày 25 tháng này.
  final int payPeriodStartDay;

  const AppSettings({
    this.orgName = 'WorkDay',
    this.currency = 'VND',
    this.otPresets = const [30, 60, 90, 120],
    this.workHoursPerDay = 8,
    this.defaultDailySalary = 200000,
    this.defaultOtRate = 50000,
    this.payPeriodStartDay = 1,
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
  }) =>
      AppSettings(
        orgName: orgName ?? this.orgName,
        currency: currency ?? this.currency,
        otPresets: otPresets ?? this.otPresets,
        workHoursPerDay: workHoursPerDay ?? this.workHoursPerDay,
        defaultDailySalary: defaultDailySalary ?? this.defaultDailySalary,
        defaultOtRate: defaultOtRate ?? this.defaultOtRate,
        payPeriodStartDay: payPeriodStartDay ?? this.payPeriodStartDay,
      );
}
