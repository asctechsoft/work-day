import 'package:cloud_firestore/cloud_firestore.dart';

/// Hồ sơ nhân viên. Nhân viên chỉ là hồ sơ để chấm công,
/// không có tài khoản đăng nhập riêng.
class Employee {
  final String id;
  final String name;

  /// Mức lương một ngày công (VND).
  final double dailySalary;

  /// Đơn giá tăng ca cho mỗi giờ (VND). Mặc định 0 = không trả OT riêng.
  final double otRate;

  /// Đơn giá OT/giờ riêng cho Thứ 7 và Chủ nhật. Mặc định 0 = dùng chung
  /// [otRate] như ngày thường (đa số cơ sở không cần phân biệt).
  final double otRateWeekend;

  /// Đơn giá OT/giờ riêng cho ngày lễ (khai ở `AppSettings.holidayDates`).
  /// Mặc định 0 = dùng chung [otRate].
  final double otRateHoliday;

  final String phone;

  /// true = Đang làm, false = Đã nghỉ (vẫn giữ toàn bộ lịch sử công cũ).
  final bool active;

  final DateTime? createdAt;

  const Employee({
    required this.id,
    required this.name,
    required this.dailySalary,
    this.otRate = 0,
    this.otRateWeekend = 0,
    this.otRateHoliday = 0,
    this.phone = '',
    this.active = true,
    this.createdAt,
  });

  factory Employee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Employee(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      dailySalary: (d['dailySalary'] as num?)?.toDouble() ?? 0,
      otRate: (d['otRate'] as num?)?.toDouble() ?? 0,
      otRateWeekend: (d['otRateWeekend'] as num?)?.toDouble() ?? 0,
      otRateHoliday: (d['otRateHoliday'] as num?)?.toDouble() ?? 0,
      phone: (d['phone'] ?? '') as String,
      active: (d['active'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'nameLower': name.toLowerCase(),
        'dailySalary': dailySalary,
        'otRate': otRate,
        'otRateWeekend': otRateWeekend,
        'otRateHoliday': otRateHoliday,
        'phone': phone,
        'active': active,
      };

  /// Hai chữ cái đầu dùng cho avatar khi chưa có ảnh.
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters1();
    return '${parts[parts.length - 2].characters1()}${parts.last.characters1()}';
  }

  Employee copyWith({
    String? name,
    double? dailySalary,
    double? otRate,
    double? otRateWeekend,
    double? otRateHoliday,
    String? phone,
    bool? active,
  }) =>
      Employee(
        id: id,
        name: name ?? this.name,
        dailySalary: dailySalary ?? this.dailySalary,
        otRate: otRate ?? this.otRate,
        otRateWeekend: otRateWeekend ?? this.otRateWeekend,
        otRateHoliday: otRateHoliday ?? this.otRateHoliday,
        phone: phone ?? this.phone,
        active: active ?? this.active,
        createdAt: createdAt,
      );
}

extension on String {
  String characters1() => isEmpty ? '' : substring(0, 1).toUpperCase();
}
