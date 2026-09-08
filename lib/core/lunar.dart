import 'dart:math' as math;

/// Đổi ngày dương sang **âm lịch Việt Nam**.
///
/// Cài theo thuật toán của Hồ Ngọc Đức (dựa trên thuật toán thiên văn của
/// Jean Meeus), tính điểm sóc và kinh độ mặt trời rồi quy về **múi giờ +7** -
/// đúng múi giờ mà lịch in ở Việt Nam dùng. Vì cùng một điểm sóc rơi vào hai
/// ngày khác nhau ở hai múi giờ nên âm lịch Việt Nam và âm lịch Trung Quốc
/// thỉnh thoảng lệch nhau một ngày; đừng đổi `_timeZone` sang 8.
///
/// Viết tay thay vì thêm package: cả app cố ý không phụ thuộc thư viện lịch
/// nào (kể cả `intl`), và phần này chỉ cần đúng một phép đổi.
class LunarDate {
  final int day;
  final int month;
  final int year;

  /// Tháng này có phải tháng nhuận không (ví dụ "tháng 6 nhuận").
  final bool isLeapMonth;

  const LunarDate({
    required this.day,
    required this.month,
    required this.year,
    required this.isLeapMonth,
  });

  /// Nhãn ngắn vẽ dưới số ngày dương trong lịch.
  ///
  /// Ngày thường chỉ hiện số ngày ("24"); mùng 1 hiện cả tháng ("1/8") để
  /// người xem biết vừa sang tháng âm mới. Tháng nhuận thêm chữ "N".
  String get shortLabel =>
      day == 1 ? '1/$month${isLeapMonth ? 'N' : ''}' : '$day';

  /// "24/7 Bính Ngọ" - dùng ở thẻ ngày đang chọn.
  String get fullLabel {
    final leap = isLeapMonth ? ' nhuận' : '';
    return '$day/$month$leap $canChi';
  }

  /// Can chi của năm âm lịch, ví dụ "Bính Ngọ".
  String get canChi => '${_can[year % 10]} ${_chi[year % 12]}';

  static const _can = [
    'Canh',
    'Tân',
    'Nhâm',
    'Quý',
    'Giáp',
    'Ất',
    'Bính',
    'Đinh',
    'Mậu',
    'Kỷ',
  ];

  static const _chi = [
    'Thân',
    'Dậu',
    'Tuất',
    'Hợi',
    'Tý',
    'Sửu',
    'Dần',
    'Mão',
    'Thìn',
    'Tỵ',
    'Ngọ',
    'Mùi',
  ];

  /// Đổi một ngày dương lịch sang âm lịch.
  factory LunarDate.fromSolar(DateTime date) =>
      _convert(date.day, date.month, date.year);

  @override
  String toString() =>
      'LunarDate($day/$month/$year${isLeapMonth ? ' nhuận' : ''})';

  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      other.day == day &&
      other.month == month &&
      other.year == year &&
      other.isLeapMonth == isLeapMonth;

  @override
  int get hashCode => Object.hash(day, month, year, isLeapMonth);
}

// --------------------------------------------------------------- Thuật toán

/// Múi giờ dùng để quy đổi. Lịch Việt Nam tính theo giờ +7.
const double _timeZone = 7;

/// Chia lấy phần nguyên **làm tròn xuống** (không phải cắt về 0 như `~/`).
/// Các công thức bên dưới có chỗ ra số âm nên phải dùng floor mới đúng.
int _int(double v) => v.floor();

/// Số ngày Julius của một ngày dương lịch.
int _jdFromDate(int dd, int mm, int yy) {
  final a = _int((14 - mm) / 12);
  final y = yy + 4800 - a;
  final m = mm + 12 * a - 3;
  var jd = dd +
      _int((153 * m + 2) / 5) +
      365 * y +
      _int(y / 4) -
      _int(y / 100) +
      _int(y / 400) -
      32045;
  // Trước 15/10/1582 là lịch Julius, công thức khác.
  if (jd < 2299161) {
    jd = dd + _int((153 * m + 2) / 5) + 365 * y + _int(y / 4) - 32083;
  }
  return jd;
}

/// Thời điểm sóc (trăng mới) lần thứ [k] tính từ 1/1/1900, theo ngày Julius.
double _newMoon(int k) {
  final t = k / 1236.85; // thế kỷ Julius tính từ 1900-01-0.5
  final t2 = t * t;
  final t3 = t2 * t;
  const dr = math.pi / 180;

  var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
  jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);

  // Cận điểm trung bình của mặt trời / mặt trăng và độ vĩ của mặt trăng.
  final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;

  var c1 = (0.1734 - 0.000393 * t) * math.sin(m * dr) +
      0.0021 * math.sin(2 * dr * m);
  c1 = c1 - 0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(dr * 2 * mpr);
  c1 = c1 - 0.0004 * math.sin(dr * 3 * mpr);
  c1 = c1 + 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr));
  c1 = c1 - 0.0074 * math.sin(dr * (m - mpr)) + 0.0004 * math.sin(dr * (2 * f + m));
  c1 = c1 - 0.0004 * math.sin(dr * (2 * f - m)) - 0.0006 * math.sin(dr * (2 * f + mpr));
  c1 = c1 + 0.0010 * math.sin(dr * (2 * f - mpr)) + 0.0005 * math.sin(dr * (2 * mpr + m));

  final double deltat;
  if (t < -11) {
    deltat = 0.001 +
        0.000839 * t +
        0.0002261 * t2 -
        0.00000845 * t3 -
        0.000000081 * t * t3;
  } else {
    deltat = -0.000278 + 0.000265 * t + 0.000262 * t2;
  }

  return jd1 + c1 - deltat;
}

/// Kinh độ mặt trời tại thời điểm [jdn] (radian).
double _sunLongitude(double jdn) {
  final t = (jdn - 2451545.0) / 36525;
  final t2 = t * t;
  const dr = math.pi / 180;

  final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;

  var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
  dl = dl +
      (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) +
      0.000290 * math.sin(dr * 3 * m);

  var l = (l0 + dl) * dr;
  l = l - math.pi * 2 * _int(l / (math.pi * 2));
  return l;
}

/// Kinh độ mặt trời quy về 12 cung (0..11) tại nửa đêm địa phương.
int _getSunLongitude(int dayNumber) =>
    _int(_sunLongitude(dayNumber - 0.5 - _timeZone / 24) / math.pi * 6);

/// Ngày (Julius) chứa điểm sóc thứ [k], theo giờ địa phương.
int _getNewMoonDay(int k) => _int(_newMoon(k) + 0.5 + _timeZone / 24);

/// Ngày bắt đầu tháng 11 âm lịch của năm dương [yy] - mốc để dò tháng nhuận.
int _getLunarMonth11(int yy) {
  final off = _jdFromDate(31, 12, yy) - 2415021;
  final k = _int(off / 29.530588853);
  var nm = _getNewMoonDay(k);
  if (_getSunLongitude(nm) >= 9) {
    nm = _getNewMoonDay(k - 1);
  }
  return nm;
}

/// Tháng nhuận nằm cách tháng 11 âm bao nhiêu tháng.
int _getLeapMonthOffset(int a11) {
  final k = _int((a11 - 2415021.076998695) / 29.530588853 + 0.5);
  var last = 0;
  var i = 1; // bắt đầu từ tháng ngay sau tháng 11 âm
  var arc = _getSunLongitude(_getNewMoonDay(k + i));
  do {
    last = arc;
    i++;
    arc = _getSunLongitude(_getNewMoonDay(k + i));
  } while (arc != last && i < 14);
  return i - 1;
}

LunarDate _convert(int dd, int mm, int yy) {
  final dayNumber = _jdFromDate(dd, mm, yy);
  final k = _int((dayNumber - 2415021.076998695) / 29.530588853);

  var monthStart = _getNewMoonDay(k + 1);
  if (monthStart > dayNumber) {
    monthStart = _getNewMoonDay(k);
  }

  var a11 = _getLunarMonth11(yy);
  var b11 = a11;
  int lunarYear;
  if (a11 >= monthStart) {
    lunarYear = yy;
    a11 = _getLunarMonth11(yy - 1);
  } else {
    lunarYear = yy + 1;
    b11 = _getLunarMonth11(yy + 1);
  }

  final lunarDay = dayNumber - monthStart + 1;
  final diff = _int((monthStart - a11) / 29);
  var lunarLeap = false;
  var lunarMonth = diff + 11;

  // Năm âm dài hơn 365 ngày nghĩa là năm đó có tháng nhuận.
  if (b11 - a11 > 365) {
    final leapMonthDiff = _getLeapMonthOffset(a11);
    if (diff >= leapMonthDiff) {
      lunarMonth = diff + 10;
      if (diff == leapMonthDiff) lunarLeap = true;
    }
  }

  if (lunarMonth > 12) lunarMonth -= 12;
  if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;

  return LunarDate(
    day: lunarDay,
    month: lunarMonth,
    year: lunarYear,
    isLeapMonth: lunarLeap,
  );
}
