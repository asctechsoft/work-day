import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/lunar.dart';
import '../../core/pay_period.dart';
import '../../core/theme.dart';
import '../../models/attendance_record.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';

/// Bảng chọn ngày chấm công.
///
/// Khác lịch thường ở hai chỗ, đều là yêu cầu của người dùng thật:
///
/// * Lưới vẽ theo **kỳ lương** chứ không theo tháng dương lịch. Cơ sở chốt
///   lương kiểu "28 tháng trước đến 27 tháng này" thì nhìn vào phải thấy đúng
///   dải ngày đó, không bị cắt làm đôi ở mốc mùng 1.
/// * Mỗi ngày mang **dấu tình trạng chấm công**: chấm đủ cả danh sách, mới
///   chấm được một phần, hay chưa chấm ngày nào.
///
/// Trả về ngày được chọn, hoặc null nếu người dùng bấm Huỷ.
Future<DateTime?> showAttendanceDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime lastDate,
  required int payPeriodStartDay,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _AttendanceDatePickerDialog(
      initialDate: initialDate,
      lastDate: lastDate,
      payPeriodStartDay: payPeriodStartDay,
    ),
  );
}

class _AttendanceDatePickerDialog extends StatefulWidget {
  const _AttendanceDatePickerDialog({
    required this.initialDate,
    required this.lastDate,
    required this.payPeriodStartDay,
  });

  final DateTime initialDate;
  final DateTime lastDate;
  final int payPeriodStartDay;

  @override
  State<_AttendanceDatePickerDialog> createState() =>
      _AttendanceDatePickerDialogState();
}

class _AttendanceDatePickerDialogState
    extends State<_AttendanceDatePickerDialog> {
  // DateTime không có hằng số biên dịch nên phải dùng final, không dùng const.
  static final DateTime _minDate = DateTime(2020, 1, 1);

  final _data = DataService.instance;

  late DateTime _selectedDate;
  late PayPeriod _period;

  @override
  void initState() {
    super.initState();
    final clampedInitial = widget.initialDate.isAfter(widget.lastDate)
        ? widget.lastDate
        : widget.initialDate;
    _selectedDate = DateTime(
      clampedInitial.year,
      clampedInitial.month,
      clampedInitial.day,
    );
    _period = _periodContaining(_selectedDate);
  }

  int get _startDay => widget.payPeriodStartDay;

  /// Kỳ lương chứa ngày [day] - `PayPeriod.current` chính là phép đó, chỉ khác
  /// tên: nó dựng kỳ đang diễn ra tại một thời điểm cho trước.
  PayPeriod _periodContaining(DateTime day) =>
      PayPeriod.current(_startDay, now: day);

  DateTime get _today => DateTime(
        widget.lastDate.year,
        widget.lastDate.month,
        widget.lastDate.day,
      );

  bool get _canGoPrevPeriod => _period.start.isAfter(_minDate);

  /// Kỳ chứa hôm nay là kỳ cuối cùng có ý nghĩa - kỳ sau chưa có ngày nào
  /// chấm được.
  bool get _canGoNextPeriod => _period.end.isBefore(_today);

  void _changePeriod(int delta) {
    final next = _period.shift(delta, _startDay);
    if (next.start.isBefore(_minDate) || next.start.isAfter(_today)) return;

    setState(() {
      _period = next;
      // Kéo ngày đang chọn về trong kỳ mới để phần tóm tắt phía trên không
      // nói về một ngày nằm ngoài lưới đang xem.
      if (!next.contains(_selectedDate)) {
        _selectedDate = next.end.isAfter(_today) ? _today : next.end;
      }
    });
  }

  void _selectDay(DateTime day) {
    if (day.isAfter(_today) || day.isBefore(_minDate)) return;
    setState(() {
      _selectedDate = day;
      // Chạm vào ngày mờ ở đầu / cuối lưới (thuộc kỳ trước hoặc kỳ sau) thì
      // nhảy luôn sang kỳ đó, khỏi phải bấm nút ‹ › rồi dò lại.
      if (!_period.contains(day)) _period = _periodContaining(day);
    });
  }

  String _weekdayLabel(int weekday) => switch (weekday) {
        DateTime.monday => 'Thứ hai',
        DateTime.tuesday => 'Thứ ba',
        DateTime.wednesday => 'Thứ tư',
        DateTime.thursday => 'Thứ năm',
        DateTime.friday => 'Thứ sáu',
        DateTime.saturday => 'Thứ bảy',
        DateTime.sunday => 'Chủ nhật',
        _ => '',
      };

  String _shortDateLabel(DateTime date) =>
      '${_weekdayLabel(date.weekday)}, ${Fmt.pad2(date.day)}/${Fmt.pad2(date.month)}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        // Máy màn nhỏ hoặc người dùng để cỡ chữ lớn thì nội dung cao hơn màn
        // hình, phải cho cuộn chứ không để tràn.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn ngày chấm công',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                // Chỉ hai dòng: ngày dương và ngày âm. Bản đầu có tới bốn
                // dòng, trong đó "Thứ hai, 31/08/2026" và "Ngày 31 tháng 8,
                // 2026" nói đúng một điều - người dùng phản hồi là rối và
                // thừa. Câu "chỉ chọn được ngày hôm nay trở về trước" cũng bỏ:
                // ngày chưa tới đã để mờ và bấm không được rồi.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortDateLabel(_selectedDate),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.brightness_2_rounded,
                          size: 13,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            Fmt.lunarFull(_selectedDate),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _period.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        // Kỳ vắt qua hai tháng thì phải nói rõ khoảng ngày,
                        // nếu không người dùng tưởng "Kỳ 09" là tháng 9.
                        if (!_period.isCalendarMonth)
                          Text(
                            _period.rangeLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kỳ trước',
                    onPressed:
                        _canGoPrevPeriod ? () => _changePeriod(-1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Kỳ sau',
                    onPressed: _canGoNextPeriod ? () => _changePeriod(1) : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _CalendarBody(
                period: _period,
                selectedDate: _selectedDate,
                today: _today,
                onPickDay: _selectDay,
                data: _data,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedDate),
                    child: const Text('Chọn'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lưới ngày của một kỳ + phần đếm ngày đã chấm.
///
/// Tách riêng để chỉ phần này dựng lại khi dữ liệu công về, còn phần đầu bảng
/// (ngày đang chọn, nút chuyển kỳ) đứng yên.
class _CalendarBody extends StatelessWidget {
  final PayPeriod period;
  final DateTime selectedDate;
  final DateTime today;
  final ValueChanged<DateTime> onPickDay;
  final DataService data;

  const _CalendarBody({
    required this.period,
    required this.selectedDate,
    required this.today,
    required this.onPickDay,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Employee>>(
      stream: data.watchActiveEmployees(),
      builder: (context, empSnap) {
        final employeeCount = empSnap.data?.length ?? 0;

        return StreamBuilder<List<AttendanceRecord>>(
          stream: data.watchPeriod(period),
          builder: (context, recSnap) {
            // Mỗi ngày đếm được bao nhiêu bản ghi công.
            final counts = <String, int>{};
            for (final r in recSnap.data ?? const <AttendanceRecord>[]) {
              counts[r.workDate] = (counts[r.workDate] ?? 0) + 1;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _grid(context, counts, employeeCount),
                const SizedBox(height: 12),
                _legend(context, counts, employeeCount),
              ],
            );
          },
        );
      },
    );
  }

  Widget _grid(
    BuildContext context,
    Map<String, int> counts,
    int employeeCount,
  ) {
    final start = period.start;
    // Lưới bắt đầu từ thứ hai nên ngày đầu kỳ phải lùi vào đúng số ô trống.
    final offset = start.weekday - DateTime.monday;
    final dayCount = period.dayCount;

    return Column(
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.6,
          ),
          children: const [
            _WeekdayLabel('T2'),
            _WeekdayLabel('T3'),
            _WeekdayLabel('T4'),
            _WeekdayLabel('T5'),
            _WeekdayLabel('T6'),
            _WeekdayLabel('T7'),
            _WeekdayLabel('CN'),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Luôn 6 hàng như lịch giấy: chiều cao bảng không nhảy khi chuyển
          // kỳ, và kỳ nào cũng nhìn thấy vài ngày của kỳ kế tiếp (kỳ dài
          // nhất 31 ngày + lùi tối đa 6 ô vẫn nằm gọn trong 42 ô).
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final dayIndex = index - offset;
            // Ô đầu và ô cuối lưới rơi vào kỳ trước / kỳ sau. Vẫn vẽ chúng,
            // chỉ để mờ - ô trắng trơn làm người dùng tưởng lịch bị lỗi, mà
            // bấm vào đó là cách chuyển kỳ nhanh nhất.
            final isOutside = dayIndex < 0 || dayIndex >= dayCount;

            // Cộng ngày qua DateTime(...) chứ không qua Duration để không
            // lệch một tiếng ở các mốc đổi giờ. dayIndex âm vẫn ra đúng ngày
            // của tháng trước.
            final dayDate = DateTime(
              start.year,
              start.month,
              start.day + dayIndex,
            );
            // Ngoài kỳ thì `counts` không có dữ liệu, đừng vẽ dấu "chưa chấm"
            // cho chúng - sẽ thành nói sai về ngày mình không nắm.
            final marked = isOutside ? 0 : (counts[Fmt.dateKey(dayDate)] ?? 0);

            return _DayCell(
              date: dayDate,
              markedCount: marked,
              employeeCount: employeeCount,
              isSelected:
                  !isOutside && Fmt.isSameDay(dayDate, selectedDate),
              isToday: Fmt.isSameDay(dayDate, today),
              isFuture: dayDate.isAfter(today),
              isOutside: isOutside,
              onTap: () => onPickDay(dayDate),
            );
          },
        ),
      ],
    );
  }

  Widget _legend(
    BuildContext context,
    Map<String, int> counts,
    int employeeCount,
  ) {
    // Chỉ đếm ngày đã qua: ngày chưa tới mà tính vào "còn thiếu" thì kỳ nào
    // đang diễn ra cũng hiện một con số đáng lo mà không sửa được.
    var done = 0;
    var partial = 0;
    var passed = 0;
    for (var i = 0; i < period.dayCount; i++) {
      final d = DateTime(
        period.start.year,
        period.start.month,
        period.start.day + i,
      );
      if (d.isAfter(today)) continue;
      passed++;
      final c = counts[Fmt.dateKey(d)] ?? 0;
      if (c == 0) continue;
      if (employeeCount == 0 || c >= employeeCount) {
        done++;
      } else {
        partial++;
      }
    }

    final blank = passed - done - partial;

    // Một dòng vừa là chú giải màu vừa là số liệu: ô màu đứng ngay cạnh con
    // số nên không cần bảng chú giải riêng bên trên nữa. Bản đầu có bốn mục
    // chú giải cộng thêm một câu tổng kết -> người dùng phản hồi là rối.
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendItem(
          color: AppColors.presentMedium,
          borderColor: AppColors.present,
          label: '$done ngày chấm đủ',
        ),
        if (partial > 0)
          _LegendItem(
            color: AppColors.overtimeMedium,
            borderColor: AppColors.overtime,
            label: '$partial ngày chấm thiếu',
          ),
        if (blank > 0)
          _LegendItem(
            color: AppColors.surface,
            borderColor: AppColors.border,
            label: '$blank ngày chưa chấm',
          ),
      ],
    );
  }
}

/// Một ô ngày trong lưới.
class _DayCell extends StatelessWidget {
  final DateTime date;
  final int markedCount;
  final int employeeCount;
  final bool isSelected;
  final bool isToday;
  final bool isFuture;

  /// Ngày thuộc kỳ trước / kỳ sau: vẽ mờ, chạm vào thì nhảy sang kỳ đó.
  final bool isOutside;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.markedCount,
    required this.employeeCount,
    required this.isSelected,
    required this.isToday,
    required this.isFuture,
    required this.isOutside,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // employeeCount == 0 nghĩa là danh sách nhân viên chưa về; lúc đó cứ coi
    // ngày có bản ghi là chấm đủ, đỡ nháy một lượt màu cam rồi mới đổi lại.
    final isFull = markedCount > 0 &&
        (employeeCount == 0 || markedCount >= employeeCount);
    final isPartial = markedCount > 0 && !isFull;

    // Ô ngày chỉ rộng chừng 45px nên chỉ tô nền thôi là không đủ nhận ra -
    // người dùng phản hồi "chấm đủ / chấm thiếu nhìn không rõ". Mỗi tình
    // trạng vì vậy được đánh dấu bằng cả ba thứ: nền đậm vừa, viền cùng màu
    // và màu chữ.
    final Color background;
    final Color textColor;
    final Color borderColor;
    if (isOutside) {
      // Ngày của kỳ bên cạnh: chỉ để chữ mờ, không tô dấu tình trạng nào -
      // dữ liệu công của kỳ đó chưa đọc nên không được nói gì về nó.
      background = Colors.transparent;
      textColor = AppColors.textMuted;
      borderColor = Colors.transparent;
    } else if (isSelected) {
      background = AppColors.primary;
      textColor = Colors.white;
      borderColor = AppColors.primary;
    } else if (isFuture) {
      background = Colors.transparent;
      textColor = AppColors.textMuted;
      borderColor = Colors.transparent;
    } else if (isFull) {
      background = AppColors.presentMedium;
      textColor = AppColors.primaryDark;
      borderColor = AppColors.present;
    } else if (isPartial) {
      background = AppColors.overtimeMedium;
      textColor = AppColors.overtime;
      borderColor = AppColors.overtime;
    } else {
      // Ngày đã qua mà chưa chấm: để trống hẳn, chỉ một viền xám mờ cho biết
      // đây vẫn là ngày bấm được.
      background = Colors.transparent;
      textColor = AppColors.textDark;
      borderColor = AppColors.border;
    }

    final lunar = LunarDate.fromSolar(date);
    // Mùng 1 âm là mốc người dùng hay dò nhất nên tô đậm hơn ngày thường.
    final isLunarFirst = lunar.day == 1;
    final Color lunarColor;
    if (isSelected) {
      lunarColor = Colors.white70;
    } else if (isFuture || isOutside) {
      lunarColor = AppColors.textMuted;
    } else if (isLunarFirst) {
      lunarColor = AppColors.primaryDark;
    } else {
      lunarColor = AppColors.textMuted;
    }

    // Ngày của kỳ bên cạnh vẽ mờ hẳn đi để không tranh chỗ với kỳ đang xem,
    // nhưng vẫn đọc được và vẫn bấm được.
    return Opacity(
      opacity: isOutside ? 0.42 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isFuture ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              // Hôm nay vẽ viền dày hơn để vẫn nổi lên giữa các ô cùng màu.
              border: Border.all(
                color: isToday && !isSelected && !isOutside
                    ? AppColors.primary
                    : borderColor,
                width: isToday && !isSelected && !isOutside ? 2.2 : 1.2,
              ),
            ),
            // Ô chỉ cao chừng 48px mà phải chứa tới ba dòng chữ; cỡ chữ hệ
            // thống để lớn thì FittedBox thu nhỏ lại thay vì để tràn.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      height: 1.1,
                      fontWeight: isSelected || (isToday && !isOutside)
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  // Ngày âm lịch - cơ sở tính công theo lịch âm nên phải thấy
                  // được ngay trên lưới, không bắt bấm vào từng ngày mới hiện.
                  Text(
                    lunar.shortLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9.5,
                      height: 1.1,
                      color: lunarColor,
                      fontWeight:
                          isLunarFirst ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final String label;

  const _LegendItem({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1.2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textBody,
                fontSize: 11.5,
              ),
        ),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
