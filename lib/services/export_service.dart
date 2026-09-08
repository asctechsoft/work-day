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

  /// Dựng file và trả về đường dẫn đã lưu.
  Future<String> exportPeriod({
    required PayPeriod period,
    required List<Employee> employees,
    required List<AttendanceRecord> records,
    required String orgName,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Bảng công';
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];

    final days = period.days;
    // Cột: STT | Nhân viên | các ngày... | 8 cột tổng hợp
    const colIndex = 0;
    const colName = 1;
    final firstDayCol = 2;
    final colWork = firstDayCol + days.length;
    final colHalf = colWork + 1;
    final colAbsent = colHalf + 1;
    final colOt = colAbsent + 1;
    final colDaily = colOt + 1;
    final colOtRate = colDaily + 1;
    final colBasePay = colOtRate + 1;
    final colOtPay = colBasePay + 1;
    final colTotal = colOtPay + 1;

    // ---------------------------------------------------------- Phần đầu
    _put(sheet, colIndex, 0, TextCellValue(orgName), _titleStyle);
    _put(
      sheet,
      colIndex,
      1,
      TextCellValue('BẢNG CHẤM CÔNG & TÍNH LƯƠNG'),
      _titleStyle,
    );
    _put(
      sheet,
      colIndex,
      2,
      TextCellValue('Kỳ lương: ${period.fullRangeLabel}'),
      _subtitleStyle,
    );
    final now = DateTime.now();
    _put(
      sheet,
      colIndex,
      3,
      TextCellValue(
        'Xuất lúc: ${Fmt.date(now)} ${Fmt.pad2(now.hour)}:${Fmt.pad2(now.minute)}',
      ),
      _subtitleStyle,
    );

    // ---------------------------------------------------------- Tiêu đề bảng
    const rowWeekday = 5;
    const rowHeader = 6;
    const firstDataRow = 7;

    _put(sheet, colIndex, rowHeader, TextCellValue('STT'), _headStyle);
    _put(sheet, colName, rowHeader, TextCellValue('Nhân viên'), _headStyle);

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final weekend = d.weekday == DateTime.sunday;
      _put(
        sheet,
        firstDayCol + i,
        rowWeekday,
        TextCellValue(_weekdayShort[d.weekday - 1]),
        weekend ? _weekendStyle : _weekdayStyle,
      );
      _put(
        sheet,
        firstDayCol + i,
        rowHeader,
        IntCellValue(d.day),
        weekend ? _weekendHeadStyle : _headStyle,
      );
    }

    const summaryHeads = [
      'Tổng công',
      'Nửa ngày',
      'Nghỉ',
      'Tổng OT (giờ)',
      'Lương/ngày',
      'Đơn giá OT',
      'Lương công',
      'Tiền OT',
      'TỔNG LƯƠNG',
    ];
    for (var i = 0; i < summaryHeads.length; i++) {
      _put(
        sheet,
        colWork + i,
        rowHeader,
        TextCellValue(summaryHeads[i]),
        _headStyle,
      );
    }

    // ---------------------------------------------------------- Dữ liệu
    final byEmployeeDay = <String, AttendanceRecord>{
      for (final r in records) '${r.employeeId}_${r.workDate}': r,
    };

    var totalUnits = 0.0;
    var totalHalf = 0;
    var totalAbsent = 0;
    var totalOtMinutes = 0;
    var totalBase = 0.0;
    var totalOtPay = 0.0;
    var grandTotal = 0.0;

    for (var i = 0; i < employees.length; i++) {
      final e = employees[i];
      final row = firstDataRow + i;

      _put(sheet, colIndex, row, IntCellValue(i + 1), _cellCenter);
      _put(sheet, colName, row, TextCellValue(e.name), _cellLeft);

      var units = 0.0;
      var half = 0;
      var absent = 0;
      var otMinutes = 0;

      for (var d = 0; d < days.length; d++) {
        final r = byEmployeeDay['${e.id}_${Fmt.dateKey(days[d])}'];
        if (r == null) {
          _put(sheet, firstDayCol + d, row, null, _cellCenter);
          continue;
        }
        units += r.workUnits;
        if (r.status == AttendanceStatus.half) half++;
        if (r.status == AttendanceStatus.absent) absent++;
        otMinutes += r.overtimeMinutes;

        _put(
          sheet,
          firstDayCol + d,
          row,
          TextCellValue(_dayMark(r)),
          _dayStyle(r.status),
        );
      }

      final basePay = units * e.dailySalary;
      final otPay = (otMinutes / 60.0) * e.otRate;

      _put(sheet, colWork, row, DoubleCellValue(units), _cellCenter);
      _put(sheet, colHalf, row, IntCellValue(half), _cellCenter);
      _put(sheet, colAbsent, row, IntCellValue(absent), _cellCenter);
      _put(
        sheet,
        colOt,
        row,
        DoubleCellValue(otMinutes / 60.0),
        _cellCenter,
      );
      _put(sheet, colDaily, row, DoubleCellValue(e.dailySalary), _cellMoney);
      _put(sheet, colOtRate, row, DoubleCellValue(e.otRate), _cellMoney);
      _put(sheet, colBasePay, row, DoubleCellValue(basePay), _cellMoney);
      _put(sheet, colOtPay, row, DoubleCellValue(otPay), _cellMoney);
      _put(
        sheet,
        colTotal,
        row,
        DoubleCellValue(basePay + otPay),
        _cellMoneyBold,
      );

      totalUnits += units;
      totalHalf += half;
      totalAbsent += absent;
      totalOtMinutes += otMinutes;
      totalBase += basePay;
      totalOtPay += otPay;
      grandTotal += basePay + otPay;
    }

    // ---------------------------------------------------------- Dòng tổng
    final totalRow = firstDataRow + employees.length;
    _put(sheet, colName, totalRow, TextCellValue('TỔNG CỘNG'), _totalStyle);
    _put(sheet, colWork, totalRow, DoubleCellValue(totalUnits), _totalStyle);
    _put(sheet, colHalf, totalRow, IntCellValue(totalHalf), _totalStyle);
    _put(sheet, colAbsent, totalRow, IntCellValue(totalAbsent), _totalStyle);
    _put(
      sheet,
      colOt,
      totalRow,
      DoubleCellValue(totalOtMinutes / 60.0),
      _totalStyle,
    );
    _put(sheet, colBasePay, totalRow, DoubleCellValue(totalBase), _totalStyle);
    _put(sheet, colOtPay, totalRow, DoubleCellValue(totalOtPay), _totalStyle);
    _put(sheet, colTotal, totalRow, DoubleCellValue(grandTotal), _totalStyle);

    // ---------------------------------------------------------- Chú thích
    _put(
      sheet,
      colIndex,
      totalRow + 2,
      TextCellValue(
        'Ghi chú:  X = đi làm (1 công)   ·   1/2 = nửa công (0,5 công)   ·   '
        'N = nghỉ (0 công)   ·   ô trống = chưa chấm   ·   '
        '"+số" phía sau = số giờ tăng ca (ví dụ X+1,5)',
      ),
      _subtitleStyle,
    );
    _put(
      sheet,
      colIndex,
      totalRow + 3,
      TextCellValue(
        'Tổng lương = Tổng công × Lương/ngày + Tổng giờ OT × Đơn giá OT',
      ),
      _subtitleStyle,
    );

    // ---------------------------------------------------------- Độ rộng cột
    sheet.setColumnWidth(colIndex, 5);
    sheet.setColumnWidth(colName, 22);
    for (var i = 0; i < days.length; i++) {
      sheet.setColumnWidth(firstDayCol + i, 4.6);
    }
    sheet.setColumnWidth(colWork, 10);
    sheet.setColumnWidth(colHalf, 9);
    sheet.setColumnWidth(colAbsent, 7);
    sheet.setColumnWidth(colOt, 13);
    sheet.setColumnWidth(colDaily, 13);
    sheet.setColumnWidth(colOtRate, 12);
    sheet.setColumnWidth(colBasePay, 14);
    sheet.setColumnWidth(colOtPay, 12);
    sheet.setColumnWidth(colTotal, 15);

    // Giữ cố định phần tên nhân viên khi cuộn ngang qua các cột ngày.
    sheet.setColumnAutoFit(colName);

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
  }) async {
    final path = await exportPeriod(
      period: period,
      employees: employees,
      records: records,
      orgName: orgName,
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

  /// Ký hiệu trong ô của một ngày.
  /// X = đi làm, 1/2 = nửa công, N = nghỉ; "+số" là số giờ tăng ca.
  static String _dayMark(AttendanceRecord r) {
    final base = r.status.exportMark;
    if (r.overtimeMinutes <= 0) return base;
    final hours = Fmt.otHoursDecimal(r.overtimeMinutes);
    return '$base+$hours';
  }

  static CellStyle _dayStyle(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => _cellPresent,
        AttendanceStatus.half => _cellHalf,
        AttendanceStatus.absent => _cellAbsent,
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

  static final _weekendHeadStyle = CellStyle(
    bold: true,
    fontSize: 10,
    backgroundColorHex: ExcelColor.fromHexString('#FBDDDD'),
    horizontalAlign: HorizontalAlign.Center,
  );

  static final _weekdayStyle = CellStyle(
    fontSize: 9,
    horizontalAlign: HorizontalAlign.Center,
    fontColorHex: ExcelColor.fromHexString('#8A97A8'),
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

  static final _totalStyle = CellStyle(
    bold: true,
    fontSize: 11,
    backgroundColorHex: ExcelColor.fromHexString('#EDF3F8'),
    horizontalAlign: HorizontalAlign.Right,
    numberFormat: const CustomNumericNumFormat(formatCode: '#,##0'),
  );
}
