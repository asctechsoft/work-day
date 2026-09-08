import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/pay_period.dart';
import '../core/theme.dart';
import '../models/attendance_record.dart';
import '../services/data_service.dart';
import 'common.dart';

/// Một điểm / một cột của biểu đồ: quỹ lương của một tháng, quý hoặc năm.
class _Bucket {
  /// Nhãn ngắn vẽ dưới trục ("1", "Q1", "2026").
  final String label;

  /// Tên đầy đủ dùng khi hiện thông báo lúc chạm vào ("Tháng 8/2026").
  final String fullLabel;

  /// Dòng phụ dưới nhãn ở chế độ quý / năm.
  final String subLabel;
  final double total;

  /// Khoảng này đang diễn ra - con số còn tăng tiếp, phải nói rõ chứ không
  /// người dùng tưởng quỹ lương tự nhiên tụt hẳn.
  final bool ongoing;

  /// Khoảng chưa tới - không vẽ điểm, vì 0đ ở đây không có nghĩa là "không
  /// tốn lương" mà là "chưa đến lúc".
  final bool future;

  const _Bucket({
    required this.label,
    required this.fullLabel,
    required this.subLabel,
    required this.total,
    required this.ongoing,
    required this.future,
  });
}

enum _TrendMode { month, quarter, year }

/// Biểu đồ quỹ lương theo **tháng**, **quý** và **năm**.
///
/// Khác thẻ "Đáng chú ý" (chỉ nói về kỳ đang xem), thẻ này đọc thẳng nhiều kỳ
/// liên tiếp từ Firestore để so sánh theo thời gian.
///
/// Vẫn theo nguyên tắc ở §5.1 của CLAUDE.md: hình vẽ chỉ để thấy **hình dáng
/// thay đổi**, còn con số tiền luôn phải đọc được - chế độ quý/năm viết số
/// ngay dưới cột, chế độ tháng thì chạm vào chấm để hiện số của tháng đó.
class PayrollTrendChart extends StatefulWidget {
  /// Ngày chốt kỳ lương (1..28) - quỹ lương gom theo kỳ, không theo tháng
  /// dương lịch.
  final int payPeriodStartDay;

  /// Năm đang xem, lấy từ kỳ đang chọn ở tab Tổng quan.
  final int year;

  const PayrollTrendChart({
    super.key,
    required this.payPeriodStartDay,
    required this.year,
  });

  @override
  State<PayrollTrendChart> createState() => _PayrollTrendChartState();
}

class _PayrollTrendChartState extends State<PayrollTrendChart> {
  /// Số năm gần nhất vẽ ở chế độ "Năm".
  static const _yearCount = 3;

  final _data = DataService.instance;

  _TrendMode _mode = _TrendMode.month;
  Future<List<_Bucket>>? _future;

  /// Điểm đang được chạm ở chế độ tháng.
  int? _selected;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(PayrollTrendChart old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year ||
        old.payPeriodStartDay != widget.payPeriodStartDay) {
      setState(() {
        _selected = null;
        _future = _load();
      });
    }
  }

  void _setMode(_TrendMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _selected = null;
      _future = _load();
    });
  }

  /// Các tháng chốt kỳ cần tính, theo chế độ đang chọn.
  List<DateTime> get _anchors {
    if (_mode == _TrendMode.year) {
      final firstYear = widget.year - _yearCount + 1;
      return [
        for (var y = firstYear; y <= widget.year; y++)
          for (var m = 1; m <= 12; m++) DateTime(y, m),
      ];
    }
    return [for (var m = 1; m <= 12; m++) DateTime(widget.year, m)];
  }

  Future<List<_Bucket>> _load() async {
    final startDay = widget.payPeriodStartDay;
    final anchors = _anchors;
    final periods = [for (final a in anchors) PayPeriod.of(a, startDay)];

    // Đọc trọn một lần cả khoảng rồi chia nhóm ở client: rẻ hơn nhiều so với
    // gọi Firestore một lần cho mỗi kỳ.
    final records = await _data.getRecordsBetween(
      periods.first.start,
      periods.last.end,
    );
    final all = await _data.getAllEmployees();

    // Gom bản ghi về từng kỳ. Kỳ có thể vắt qua hai tháng nên phải so ngày,
    // không dùng được trường `month`.
    final byPeriod = <int, List<AttendanceRecord>>{};
    for (final r in records) {
      final day = Fmt.parseDateKey(r.workDate);
      for (var i = 0; i < periods.length; i++) {
        if (periods[i].contains(day)) {
          (byPeriod[i] ??= []).add(r);
          break;
        }
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Tiền lương của từng kỳ.
    final totals = <double>[];
    final ongoing = <bool>[];
    final future = <bool>[];
    for (var i = 0; i < periods.length; i++) {
      final p = periods[i];
      // Người đã nghỉ nhưng có công trong kỳ vẫn phải tính vào quỹ lương.
      totals.add(
        DataService.totalPayrollOf(all, byPeriod[i] ?? const []),
      );
      ongoing.add(p.contains(today));
      future.add(p.start.isAfter(today));
    }

    if (_mode == _TrendMode.month) {
      return [
        for (var i = 0; i < periods.length; i++)
          _Bucket(
            label: '${anchors[i].month}',
            fullLabel: 'Kỳ tháng ${anchors[i].month}/${anchors[i].year}'
                ' (${periods[i].rangeLabel})',
            subLabel: '',
            total: totals[i],
            ongoing: ongoing[i],
            future: future[i],
          ),
      ];
    }

    // Quý và năm: gộp các kỳ lại theo khoá.
    final sum = <String, double>{};
    final anyOngoing = <String>{};
    final allFuture = <String, bool>{};
    for (var i = 0; i < periods.length; i++) {
      final key = _mode == _TrendMode.quarter
          ? 'Q${periods[i].quarter}'
          : '${anchors[i].year}';
      sum[key] = (sum[key] ?? 0) + totals[i];
      if (ongoing[i]) anyOngoing.add(key);
      allFuture[key] = (allFuture[key] ?? true) && future[i];
    }

    if (_mode == _TrendMode.quarter) {
      return [
        for (var q = 1; q <= 4; q++)
          _Bucket(
            label: 'Q$q',
            fullLabel: 'Quý $q năm ${widget.year}',
            subLabel: 'Tháng ${(q - 1) * 3 + 1}-${q * 3}',
            total: sum['Q$q'] ?? 0,
            ongoing: anyOngoing.contains('Q$q'),
            future: allFuture['Q$q'] ?? false,
          ),
      ];
    }

    return [
      for (var y = widget.year - _yearCount + 1; y <= widget.year; y++)
        _Bucket(
          label: '$y',
          fullLabel: 'Năm $y',
          subLabel: 'Cả năm',
          total: sum['$y'] ?? 0,
          ongoing: anyOngoing.contains('$y'),
          future: allFuture['$y'] ?? false,
        ),
    ];
  }

  void _onPickPoint(int index, _Bucket b) {
    setState(() => _selected = index);
    showToast(
      context,
      '${b.fullLabel}: ${Fmt.currency(b.total)}'
      '${b.ongoing ? ' (đang diễn ra)' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Quỹ lương theo thời gian'),
          const SizedBox(height: 10),
          Row(
            children: [
              _ModeButton(
                label: 'Tháng',
                selected: _mode == _TrendMode.month,
                onTap: () => _setMode(_TrendMode.month),
              ),
              const SizedBox(width: 6),
              _ModeButton(
                label: 'Quý',
                selected: _mode == _TrendMode.quarter,
                onTap: () => _setMode(_TrendMode.quarter),
              ),
              const SizedBox(width: 6),
              _ModeButton(
                label: 'Năm',
                selected: _mode == _TrendMode.year,
                onTap: () => _setMode(_TrendMode.year),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            switch (_mode) {
              _TrendMode.month =>
                'Mười hai kỳ lương của năm ${widget.year}. '
                    'Chạm vào một chấm để xem quỹ lương kỳ đó.',
              _TrendMode.quarter =>
                'Bốn quý của năm ${widget.year}, gộp theo kỳ lương.',
              _TrendMode.year => '$_yearCount năm gần nhất, gộp theo kỳ lương.',
            },
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<_Bucket>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (snap.hasError) {
                return SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      'Không đọc được dữ liệu: ${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.absent,
                      ),
                    ),
                  ),
                );
              }

              final buckets = snap.data ?? const <_Bucket>[];
              final max = buckets.fold<double>(
                0,
                (m, b) => b.total > m ? b.total : m,
              );
              if (max <= 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Chưa có dữ liệu công trong khoảng thời gian này.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }

              if (_mode == _TrendMode.month) {
                return _AreaChart(
                  buckets: buckets,
                  max: max,
                  selected: _selected,
                  onPick: _onPickPoint,
                );
              }
              return _Columns(buckets: buckets, max: max);
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Quỹ lương của kỳ cũ được tính lại theo mức lương hiện tại của '
            'từng người - app không lưu lịch sử thay đổi lương.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Biểu đồ miền

/// Biểu đồ miền 12 tháng: đường nối các điểm, tô nhạt phần dưới đường.
///
/// Dùng miền thay vì 12 cột vì cột hẹp quá không viết nổi số tiền dưới chân;
/// đổi lại **phải chạm được vào từng chấm** để đọc con số, nếu không thì lại
/// rơi vào lỗi cũ ở §5.1 - hình đẹp mà không tra được số.
class _AreaChart extends StatelessWidget {
  final List<_Bucket> buckets;
  final double max;
  final int? selected;
  final void Function(int index, _Bucket bucket) onPick;

  const _AreaChart({
    required this.buckets,
    required this.max,
    required this.selected,
    required this.onPick,
  });

  static const _height = 150.0;

  /// Chỉ vẽ tới kỳ đang diễn ra - tháng chưa tới mà kéo đường về 0 thì nhìn
  /// như quỹ lương tụt xuống đáy.
  List<int> get _visibleIndexes => [
        for (var i = 0; i < buckets.length; i++)
          if (!buckets[i].future) i,
      ];

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndexes;
    if (visible.isEmpty) {
      return const SizedBox(
        height: _height,
        child: Center(
          child: Text(
            'Năm này chưa tới, chưa có dữ liệu.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: _height,
          child: LayoutBuilder(
            builder: (context, c) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  // Chia đều thành từng ô rồi bắt theo ô: chấm chỉ to vài px,
                  // bắt buộc chạm trúng chấm thì người dùng bấm mãi không
                  // được. Cách chia này cũng khớp đúng với hàng nhãn tháng
                  // bên dưới (mỗi nhãn một Expanded).
                  final slot = (d.localPosition.dx /
                          (c.maxWidth / visible.length))
                      .floor()
                      .clamp(0, visible.length - 1);
                  final index = visible[slot];
                  onPick(index, buckets[index]);
                },
                child: CustomPaint(
                  size: Size(c.maxWidth, _height),
                  painter: _AreaPainter(
                    values: [for (final i in visible) buckets[i].total],
                    max: max,
                    selectedSlot: selected == null
                        ? null
                        : visible.indexOf(selected!),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // Nhãn trục ngang: số tháng, canh đúng vị trí từng điểm.
        Row(
          children: [
            for (final i in visible)
              Expanded(
                child: Text(
                  buckets[i].label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == selected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: i == selected
                        ? AppColors.primaryDark
                        : AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Con số của điểm đang chọn, hoặc lời nhắc cách xem.
        if (selected != null && !buckets[selected!].future)
          _SelectedLine(bucket: buckets[selected!])
        else
          const Text(
            'Chạm vào một chấm để xem quỹ lương của kỳ đó.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

/// Dòng hiện số tiền của điểm vừa chạm, nằm ngay dưới biểu đồ.
class _SelectedLine extends StatelessWidget {
  final _Bucket bucket;

  const _SelectedLine({required this.bucket});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              bucket.fullLabel,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            Fmt.currency(bucket.total),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<double> values;
  final double max;
  final int? selectedSlot;

  _AreaPainter({
    required this.values,
    required this.max,
    required this.selectedSlot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || max <= 0) return;

    const topPad = 10.0;
    final chartHeight = size.height - topPad;

    // Trục dọc luôn bắt đầu từ 0 (§5.1: không "phóng to phần chênh lệch").
    double yOf(double v) => topPad + chartHeight * (1 - (v / max));
    // Mỗi điểm nằm giữa ô của nó để khớp với hàng nhãn tháng bên dưới (mỗi
    // nhãn một Expanded), chứ không kéo từ mép này sang mép kia.
    double xOf(int i) => size.width * (i + 0.5) / values.length;

    // Ba đường lưới ngang cho dễ ước lượng độ cao.
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topPad + chartHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final points = [
      for (var i = 0; i < values.length; i++) Offset(xOf(i), yOf(values[i])),
    ];

    // Miền: đường gấp khúc rồi đóng xuống đáy. Kéo phẳng ra hai mép để miền
    // không bị hụt hai đầu (điểm đầu / cuối nằm giữa ô của nó, không ở mép).
    final area = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, points.first.dy);
    for (final p in points) {
      area.lineTo(p.dx, p.dy);
    }
    area
      ..lineTo(size.width, points.last.dy)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.presentMedium, AppColors.primarySoft],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Đường viền trên của miền, cũng kéo phẳng ra hai mép cho khớp.
    final line = Path()..moveTo(0, points.first.dy);
    for (final p in points) {
      line.lineTo(p.dx, p.dy);
    }
    line.lineTo(size.width, points.last.dy);
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    // Chấm tại từng điểm - đây chính là chỗ chạm để xem số.
    final dotFill = Paint()..color = Colors.white;
    final dotEdge = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < points.length; i++) {
      final isSelected = i == selectedSlot;
      if (isSelected) {
        // Đường dóng xuống trục cho biết đang đứng ở điểm nào.
        canvas.drawLine(
          Offset(points[i].dx, points[i].dy),
          Offset(points[i].dx, size.height),
          Paint()
            ..color = AppColors.primary
            ..strokeWidth = 1.2,
        );
      }
      final r = isSelected ? 6.0 : 3.6;
      canvas.drawCircle(points[i], r, dotFill);
      canvas.drawCircle(points[i], r, dotEdge);
    }
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.max != max ||
      old.selectedSlot != selectedSlot ||
      !identical(old.values, values);
}

// ------------------------------------------------------------- Cột quý / năm

/// Dãy cột dọc + số tiền viết đủ dưới mỗi cột.
class _Columns extends StatelessWidget {
  final List<_Bucket> buckets;
  final double max;

  const _Columns({required this.buckets, required this.max});

  /// Chiều cao phần thân cột.
  static const _barHeight = 118.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final b in buckets)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cột luôn bắt đầu từ 0 - đừng "phóng to phần chênh lệch"
                  // bằng cách cắt trục, người dùng sẽ tưởng quý này gấp mấy
                  // lần quý kia (xem §5.1).
                  SizedBox(
                    height: _barHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: max <= 0
                            ? 0
                            : (b.total / max).clamp(0.02, 1).toDouble(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: b.ongoing
                                ? AppColors.presentMedium
                                : AppColors.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    b.subLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Con số mới là thứ đọc được chính xác; cột chỉ để thấy
                  // hình dáng thay đổi.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Fmt.money(b.total),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: b.total > 0
                            ? AppColors.primaryDark
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (b.ongoing)
                    const Text(
                      'đang diễn ra',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.present,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textBody,
            ),
          ),
        ),
      ),
    );
  }
}
