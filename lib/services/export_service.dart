import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/formatters.dart';
import '../core/pay_period.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';

/// Xuất bảng chấm công + bảng lương của một kỳ ra file Excel (.xlsx)
/// rồi mở khay chia sẻ để người dùng lưu về máy, gửi Zalo hoặc lên Drive.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  static const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// Cột của bảng ngày: Ngày | Thứ | Trạng thái | Công | OT (giờ).
  /// Chỉ 5 cột hẹp - vừa khổ A4 dọc, không phải bảng ngang mỗi ngày một cột
  /// như bản trước (người dùng phản hồi 18/09/2026: bảng ngang "dài", "mất"
  /// khi in). Đổi lại: mỗi nhân viên một khối riêng, xếp dọc từ trên xuống.
  static const _colDate = 0;
  static const _colWeekday = 1;
  static const _colStatus = 2;
  static const _colUnits = 3;
  static const _colOt = 4;

  /// Dựng file và trả về đường dẫn đã lưu.
  ///
  /// [holidayDates] (`AppSettings.holidayDates`) quyết định ngày nào trong kỳ
  /// được tính OT theo đơn giá ngày lễ (`Employee.otRateHoliday`) thay vì
  /// đơn giá thường/cuối tuần - cùng cách chọn đơn giá như `DataService.summarize`.
  Future<String> exportPeriod({
    required PayPeriod period,
    required List<Employee> employees,
    required List<AttendanceRecord> records,
    required String orgName,
    required int workHoursPerDay,
    Set<String> holidayDates = const {},
    double holidayPayMultiplier = 1,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Bảng công';
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];

    final days = period.days;
    final byEmployeeDay = <String, AttendanceRecord>{
      for (final r in records) '${r.employeeId}_${r.workDate}': r,
    };

    var row = 0;

    // ---------------------------------------------------------- Phần đầu
    _put(sheet, _colDate, row++, TextCellValue(orgName), _titleStyle);
    _put(
      sheet,
      _colDate,
      row++,
      TextCellValue('BẢNG CHẤM CÔNG & TÍNH LƯƠNG'),
      _titleStyle,
    );
    _put(
      sheet,
      _colDate,
      row++,
      TextCellValue('Kỳ lương: ${period.fullRangeLabel}'),
      _subtitleStyle,
    );
    final now = DateTime.now();
    _put(
      sheet,
      _colDate,
      row++,
      TextCellValue(
        'Xuất lúc: ${Fmt.date(now)} ${Fmt.pad2(now.hour)}:${Fmt.pad2(now.minute)}',
      ),
      _subtitleStyle,
    );
    row++;

    var grandUnits = 0.0;
    var grandAbsent = 0;
    var grandOtMinutes = 0;
    var grandBasePay = 0.0;
    var grandOtPay = 0.0;

    // -------------------------------------------------- Từng khối nhân viên
    for (var i = 0; i < employees.length; i++) {
      final e = employees[i];

      _put(
        sheet,
        _colDate,
        row++,
        TextCellValue('${i + 1}. ${e.name}'),
        _sectionStyle,
      );
      _putLabelMoney(sheet, row++, 'Lương/ngày', e.dailySalary);
      _putLabelMoney(sheet, row++, 'Đơn giá OT/giờ (ngày thường)', e.otRate);
      // Hai dòng đơn giá cuối tuần/lễ chỉ hiện khi cơ sở thật sự đặt riêng -
      // đa số nhân viên dùng chung một đơn giá, thêm hai dòng luôn hiện là
      // thừa (cùng nguyên tắc "chỉ vẽ khi khác biệt" ở §5.1 CLAUDE.md).
      if (e.otRateWeekend > 0) {
        _putLabelMoney(
          sheet,
          row++,
          'Đơn giá OT/giờ (Thứ 7, CN)',
          e.otRateWeekend,
        );
      }
      if (e.otRateHoliday > 0) {
        _putLabelMoney(
          sheet,
          row++,
          'Đơn giá OT/giờ (ngày lễ)',
          e.otRateHoliday,
        );
      }

      _put(sheet, _colDate, row, TextCellValue('Ngày'), _headStyle);
      _put(sheet, _colWeekday, row, TextCellValue('Thứ'), _headStyle);
      _put(sheet, _colStatus, row, TextCellValue('Trạng thái'), _headStyle);
      _put(sheet, _colUnits, row, TextCellValue('Công'), _headStyle);
      _put(sheet, _colOt, row, TextCellValue('OT (giờ)'), _headStyle);
      row++;

      var units = 0.0;
      var unitsHoliday = 0.0;
      var absent = 0;
      var otMinutes = 0;
      var otNormal = 0;
      var otWeekend = 0;
      var otHoliday = 0;

      for (final d in days) {
        final dateKey = Fmt.dateKey(d);
        final r = byEmployeeDay['${e.id}_$dateKey'];
        // Cuối tuần hoặc ngày lễ đều đánh dấu chung một kiểu ô: đây chỉ là
        // gợi ý trực quan, đơn giá thật áp dụng theo từng loại đã tính riêng
        // ở dưới (otNormal/otWeekend/otHoliday).
        final isWeekend =
            d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
        final isSpecial = isWeekend || holidayDates.contains(dateKey);

        _put(
          sheet,
          _colDate,
          row,
          TextCellValue(Fmt.dayMonth(d)),
          isSpecial ? _weekendStyle : _cellCenter,
        );
        _put(
          sheet,
          _colWeekday,
          row,
          TextCellValue(_weekdayShort[d.weekday - 1]),
          isSpecial ? _weekendStyle : _cellCenter,
        );

        if (r == null) {
          _put(sheet, _colStatus, row, TextCellValue('Chưa chấm'), _cellLeft);
          _put(sheet, _colUnits, row, null, _cellCenter);
          _put(sheet, _colOt, row, null, _cellCenter);
          row++;
          continue;
        }

        units += r.workUnits;
        if (holidayDates.contains(dateKey)) unitsHoliday += r.workUnits;
        if (r.status == AttendanceStatus.absent) absent++;
        otMinutes += r.overtimeMinutes;
        switch (r.otDayKind(holidayDates)) {
          case OtDayKind.normal:
            otNormal += r.overtimeMinutes;
          case OtDayKind.weekend:
            otWeekend += r.overtimeMinutes;
          case OtDayKind.holiday:
            otHoliday += r.overtimeMinutes;
        }

        _put(
          sheet,
          _colStatus,
          row,
          TextCellValue(_statusLabel(r, workHoursPerDay)),
          _dayStyle(r.status),
        );
        _put(
          sheet,
          _colUnits,
          row,
          DoubleCellValue(r.workUnits),
          _dayStyle(r.status),
        );
        _put(
          sheet,
          _colOt,
          row,
          r.overtimeMinutes > 0
              ? DoubleCellValue(r.overtimeMinutes / 60.0)
              : null,
          _cellCenter,
        );
        row++;
      }

      final basePay = (units - unitsHoliday) * e.dailySalary +
          unitsHoliday * e.dailySalary * holidayPayMultiplier;
      final otPay = (otNormal / 60.0) * e.otRate +
          (otWeekend / 60.0) * (e.otRateWeekend > 0 ? e.otRateWeekend : e.otRate) +
          (otHoliday / 60.0) * (e.otRateHoliday > 0 ? e.otRateHoliday : e.otRate);

      _put(sheet, _colStatus, row, TextCellValue('TỔNG'), _totalCountStyle);
      _put(
        sheet,
        _colUnits,
        row,
        DoubleCellValue(units),
        _totalCountStyle,
      );
      _put(
        sheet,
        _colOt,
        row,
        DoubleCellValue(otMinutes / 60.0),
        _totalCountStyle,
      );
      row++;

      _putLabelNumber(sheet, row++, 'Số ngày nghỉ', absent.toDouble());
      _putLabelMoney(sheet, row++, 'Lương công', basePay);
      // Chỉ hiện khi có công rơi vào ngày lễ và cơ sở có đặt hệ số nhân -
      // để người xem biết vì sao "Lương công" không đơn giản bằng
      // Tổng công × Lương/ngày.
      if (unitsHoliday > 0 && holidayPayMultiplier > 1) {
        _putLabelNumber(
          sheet,
          row++,
          'Trong đó công ngày lễ (x${Fmt.workUnits(holidayPayMultiplier)})',
          unitsHoliday,
        );
      }
      _putLabelMoney(sheet, row++, 'Tiền OT', otPay);
      _putLabelMoney(
        sheet,
        row++,
        'TỔNG LƯƠNG',
        basePay + otPay,
        bold: true,
      );
      row++; // dòng trống ngăn cách hai khối nhân viên

      grandUnits += units;
      if (absent > 0) grandAbsent += absent;
      grandOtMinutes += otMinutes;
      grandBasePay += basePay;
      grandOtPay += otPay;
    }

    // ---------------------------------------------------------- Tổng cơ sở
    _put(
      sheet,
      _colDate,
      row++,
      TextCellValue('TỔNG CỘNG TOÀN BỘ CƠ SỞ'),
      _sectionStyle,
    );
    _putLabelNumber(sheet, row++, 'Tổng công', grandUnits);
    _putLabelNumber(sheet, row++, 'Tổng nghỉ (ngày)', grandAbsent.toDouble());
    _putLabelNumber(sheet, row++, 'Tổng OT (giờ)', grandOtMinutes / 60.0);
    _putLabelMoney(sheet, row++, 'Lương công', grandBasePay);
    _putLabelMoney(sheet, row++, 'Tiền OT', grandOtPay);
    _putLabelMoney(
      sheet,
      row++,
      'TỔNG QUỸ LƯƠNG',
      grandBasePay + grandOtPay,
      bold: true,
    );
    row++;

    // ---------------------------------------------------------- Chú thích
    _put(
      sheet,
      _colDate,
      row++,
      TextCellValue(
        'Ghi chú: cột Công là số công thực (1 = đi làm, 0,5 = nửa công, số '
        'khác = Tuỳ chỉnh). Tuỳ chỉnh viết kèm số giờ đã làm ở cột Trạng thái.',
      ),
      _subtitleStyle,
    );
    _put(
      sheet,
      _colDate,
      row++,
      TextCellValue(
        'Tổng lương = Tổng công × Lương/ngày + Tổng giờ OT × Đơn giá OT',
      ),
      _subtitleStyle,
    );

    // ---------------------------------------------------------- Độ rộng cột
    // Cột Ngày/Thứ còn dùng chung làm cột "nhãn/số tiền" ở các dòng tổng hợp
    // (Lương/ngày, TỔNG LƯƠNG...) nên phải đủ rộng cho cả hai vai trò đó,
    // không chỉ vừa "01/09" hay "CN".
    sheet.setColumnWidth(_colDate, 18);
    sheet.setColumnWidth(_colWeekday, 14);
    sheet.setColumnWidth(_colStatus, 22);
    sheet.setColumnWidth(_colUnits, 9);
    sheet.setColumnWidth(_colOt, 10);

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Không dựng được file Excel.');
    }

    final dir = await getTemporaryDirectory();
    final name =
        'Bang-cong_${Fmt.pad2(period.anchor.month)}-${period.anchor.year}.xlsx';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Xuất rồi mở khay chia sẻ của hệ điều hành.
  Future<void> exportAndShare({
    required PayPeriod period,
    required List<Employee> employees,
    required List<AttendanceRecord> records,
    required String orgName,
    required int workHoursPerDay,
    Set<String> holidayDates = const {},
    double holidayPayMultiplier = 1,
  }) async {
    final path = await exportPeriod(
      period: period,
      employees: employees,
      records: records,
      orgName: orgName,
      workHoursPerDay: workHoursPerDay,
      holidayDates: holidayDates,
      holidayPayMultiplier: holidayPayMultiplier,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: _xlsxMime)],
        subject: 'Bảng công ${period.title} - $orgName',
        text: 'Bảng chấm công & tính lương kỳ ${period.fullRangeLabel}',
      ),
    );
  }

  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Chữ hiện ở cột Trạng thái. Tuỳ chỉnh viết kèm số giờ đã làm
  /// (ví dụ "Tuỳ chỉnh (6h)") vì mỗi ngày một số khác nhau.
  static String _statusLabel(AttendanceRecord r, int workHoursPerDay) {
    if (r.status != AttendanceStatus.custom) return r.status.label;
    final hours = Fmt.customWorkHours(r.workUnits, workHoursPerDay);
    return '${r.status.label} ($hours)';
  }

  static CellStyle _dayStyle(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => _cellPresent,
        AttendanceStatus.half => _cellHalf,
        AttendanceStatus.absent => _cellAbsent,
        AttendanceStatus.custom => _cellCustom,
        AttendanceStatus.none => _cellCenter,
      };

  static void _put(
    Sheet sheet,
    int col,
    int row,
    CellValue? value,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value;
    cell.cellStyle = style;
  }

  /// Một dòng "nhãn: số tiền" - nhãn ở cột Ngày, số tiền ở cột Thứ. Số tiền
  /// luôn là ô số thật (`DoubleCellValue`), không phải chuỗi, để còn
  /// cộng/lọc/sửa công thức trong Excel được (đừng đổi sang `TextCellValue`).
  static void _putLabelMoney(
    Sheet sheet,
    int row,
    String label,
    double amount, {
    bool bold = false,
  }) {
    _put(
      sheet,
      _colDate,
      row,
      TextCellValue(label),
      bold ? _cellLeftBold : _cellLeft,
    );
    _put(
      sheet,
      _colWeekday,
      row,
      DoubleCellValue(amount),
      bold ? _cellMoneyBold : _cellMoney,
    );
  }

  /// Giống [_putLabelMoney] nhưng cho số thường (công, giờ) - không định
  /// dạng tiền.
  static void _putLabelNumber(
    Sheet sheet,
    int row,
    String label,
    double value,
  ) {
    _put(sheet, _colDate, row, TextCellValue(label), _cellLeft);
    _put(sheet, _colWeekday, row, DoubleCellValue(value), _cellCenter);
  }

  // ------------------------------------------------------------- Kiểu ô

  static final _titleStyle = CellStyle(bold: true, fontSize: 13);

  static final _subtitleStyle = CellStyle(fontSize: 10, italic: true);

  static final _headStyle = CellStyle(
    bold: true,
    fontSize: 10,
    backgroundColorHex: ExcelColor.fromHexString('#D6EFE6'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
  );

  /// Banner đầu mỗi khối - tên nhân viên và dòng "TỔNG CỘNG TOÀN BỘ CƠ SỞ".
  static final _sectionStyle = CellStyle(
    bold: true,
    fontSize: 12,
    backgroundColorHex: ExcelColor.fromHexString('#D6EFE6'),
  );

  static final _weekendStyle = CellStyle(
    fontSize: 9,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    fontColorHex: ExcelColor.fromHexString('#E0484D'),
  );

  static final _cellCenter = CellStyle(
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Center,
  );

  static final _cellLeft = CellStyle(fontSize: 10);

  static final _cellLeftBold = CellStyle(fontSize: 10, bold: true);

  static final _cellPresent = CellStyle(
    fontSize: 10,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    fontColorHex: ExcelColor.fromHexString('#1F9D6D'),
  );

  static final _cellHalf = CellStyle(
    fontSize: 10,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    fontColorHex: ExcelColor.fromHexString('#2F80ED'),
  );

  static final _cellAbsent = CellStyle(
    fontSize: 10,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    fontColorHex: ExcelColor.fromHexString('#E0484D'),
  );

  static final _cellCustom = CellStyle(
    fontSize: 10,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    fontColorHex: ExcelColor.fromHexString('#7C5CFC'),
  );

  static final _cellMoney = CellStyle(
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Right,
    numberFormat: const CustomNumericNumFormat(formatCode: '#,##0'),
  );

  static final _cellMoneyBold = CellStyle(
    fontSize: 10,
    bold: true,
    horizontalAlign: HorizontalAlign.Right,
    numberFormat: const CustomNumericNumFormat(formatCode: '#,##0'),
  );

  /// Dòng "TỔNG" của bảng ngày trong mỗi khối nhân viên - số công/giờ OT,
  /// không phải tiền nên không dùng định dạng `#,##0` (mất chữ số thập phân
  /// của công tuỳ chỉnh, ví dụ 0,625).
  static final _totalCountStyle = CellStyle(
    bold: true,
    fontSize: 11,
    backgroundColorHex: ExcelColor.fromHexString('#EDF3F8'),
    horizontalAlign: HorizontalAlign.Center,
  );
}
