import 'formatters.dart';

/// Một kỳ lương: khoảng ngày mà app cộng công và tính lương.
///
/// Nhiều cơ sở không chốt lương theo đúng tháng dương lịch mà theo kiểu
/// "từ ngày 26 tháng trước đến ngày 25 tháng này". [AppSettings.payPeriodStartDay]
/// quyết định ngày bắt đầu đó:
///
/// * `startDay = 1`  -> kỳ trùng đúng tháng dương lịch (01/09 - 30/09).
/// * `startDay = 26` -> kỳ của tháng 09 là 26/08 - 25/09.
///
/// Kỳ luôn *kết thúc* trong tháng được chọn, nên "Kỳ tháng 09" là kỳ mà
/// người dùng chốt sổ trong tháng 09.
class PayPeriod {
  /// Tháng được chọn trên thanh điều hướng (ngày luôn là 1).
  final DateTime anchor;

  /// Ngày đầu tiên được tính công (đã chuẩn hoá về 0 giờ).
  final DateTime start;

  /// Ngày cuối cùng được tính công.
  final DateTime end;

  const PayPeriod({
    required this.anchor,
    required this.start,
    required this.end,
  });

  /// Dựng kỳ lương cho tháng [anchor] theo ngày bắt đầu [startDay] (1..28).
  factory PayPeriod.of(DateTime anchor, int startDay) {
    final month = DateTime(anchor.year, anchor.month);
    final day = startDay.clamp(1, 28);

    if (day == 1) {
      return PayPeriod(
        anchor: month,
        start: month,
        end: DateTime(month.year, month.month, Fmt.daysInMonth(month)),
      );
    }

    return PayPeriod(
      anchor: month,
      start: DateTime(month.year, month.month - 1, day),
      end: DateTime(month.year, month.month, day - 1),
    );
  }

  /// Kỳ lương đang diễn ra tại thời điểm [now].
  factory PayPeriod.current(int startDay, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final day = startDay.clamp(1, 28);
    // Đã qua ngày bắt đầu thì kỳ hiện tại sẽ chốt vào tháng sau.
    final anchor = (day > 1 && today.day >= day)
        ? DateTime(today.year, today.month + 1)
        : DateTime(today.year, today.month);
    return PayPeriod.of(anchor, day);
  }

  PayPeriod shift(int months, int startDay) =>
      PayPeriod.of(DateTime(anchor.year, anchor.month + months), startDay);

  String get startKey => Fmt.dateKey(start);
  String get endKey => Fmt.dateKey(end);

  /// Kỳ có trùng đúng tháng dương lịch không.
  bool get isCalendarMonth => start.day == 1;

  /// "Tháng 09/2026" hoặc "Kỳ 09/2026".
  String get title => isCalendarMonth ? Fmt.month(anchor) : 'Kỳ ${Fmt.pad2(anchor.month)}/${anchor.year}';

  /// "26/08 - 25/09/2026" - luôn hiện rõ khoảng ngày để khỏi hiểu nhầm.
  String get rangeLabel =>
      '${Fmt.dayMonth(start)} - ${Fmt.dayMonth(end)}/${end.year}';

  /// Nhãn đầy đủ dùng trong file xuất ra.
  String get fullRangeLabel => '${Fmt.date(start)} - ${Fmt.date(end)}';

  /// Quý (1..4) mà kỳ này thuộc về, tính theo tháng chốt kỳ.
  ///
  /// Kỳ 26/08 - 25/09 thuộc quý 3 vì nó chốt trong tháng 9 - cùng quy ước với
  /// [title]: kỳ luôn thuộc về tháng mà nó kết thúc.
  int get quarter => ((anchor.month - 1) ~/ 3) + 1;

  /// Số ngày trong kỳ.
  int get dayCount => end.difference(start).inDays + 1;

  /// Danh sách từng ngày trong kỳ, dùng để dựng các cột của bảng công.
  List<DateTime> get days => [
        for (var i = 0; i < dayCount; i++)
          DateTime(start.year, start.month, start.day + i),
      ];

  bool contains(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  @override
  bool operator ==(Object other) =>
      other is PayPeriod && other.startKey == startKey && other.endKey == endKey;

  @override
  int get hashCode => Object.hash(startKey, endKey);
}
