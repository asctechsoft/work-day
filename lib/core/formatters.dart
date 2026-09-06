import 'package:flutter/services.dart';

/// Các hàm định dạng dùng chung: tiền VND, ngày tháng tiếng Việt, giờ tăng ca.
class Fmt {
  static const _weekdays = <String>[
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật',
  ];

  static String pad2(int v) => v.toString().padLeft(2, '0');

  /// Khoá ngày dùng để lưu Firestore: yyyy-MM-dd
  static String dateKey(DateTime d) =>
      '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

  /// Khoá tháng dùng để lưu Firestore: yyyy-MM
  static String monthKey(DateTime d) => '${d.year}-${pad2(d.month)}';

  static DateTime parseDateKey(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// 06/09/2026
  static String date(DateTime d) => '${pad2(d.day)}/${pad2(d.month)}/${d.year}';

  /// 06/09
  static String dayMonth(DateTime d) => '${pad2(d.day)}/${pad2(d.month)}';

  /// Thứ 3, 06/09/2026
  static String fullDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${date(d)}';

  /// Tháng 09/2026
  static String month(DateTime d) => 'Tháng ${pad2(d.month)}/${d.year}';

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Số ngày của tháng chứa [d].
  static int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  /// 5200000 -> "5.200.000"
  static String money(num value) {
    final negative = value < 0;
    final digits = value.abs().round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return negative ? '-${buf.toString()}' : buf.toString();
  }

  /// 5200000 -> "5.200.000đ"
  static String currency(num value) => '${money(value)}đ';

  /// Rút gọn cho ô thống kê: 39600000 -> "39.600.000"
  static String moneyCompact(num value) {
    if (value >= 1000000000) {
      final v = value / 1000000000;
      return '${_trim(v)} tỷ';
    }
    if (value >= 1000000) {
      final v = value / 1000000;
      return '${_trim(v)} tr';
    }
    return money(value);
  }

  /// Một chữ số thập phân, dùng dấu phẩy theo cách viết tiếng Việt.
  static String _trim(double v) {
    final s = v.toStringAsFixed(1);
    final trimmed = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    return trimmed.replaceAll('.', ',');
  }

  /// 90 phút -> "1.5h"; 0 -> "0h"
  static String otHours(int minutes) {
    if (minutes <= 0) return '0h';
    final h = minutes / 60.0;
    final s = h.toStringAsFixed(1);
    return s.endsWith('.0') ? '${s.substring(0, s.length - 2)}h' : '${s}h';
  }

  /// Số giờ dạng số thực dùng để tính tiền.
  static double toHours(int minutes) => minutes / 60.0;

  /// "26" hoặc "25.5" cho số công.
  static String workUnits(num units) {
    final s = units.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}

/// Định dạng ô nhập tiền theo kiểu 1.000.000 khi người dùng gõ.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = Fmt.money(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Đọc số tiền từ chuỗi đã định dạng.
int parseMoney(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}
