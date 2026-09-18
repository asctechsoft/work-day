import 'package:flutter_test/flutter_test.dart';
import 'package:tick_go/core/formatters.dart';
import 'package:tick_go/core/lunar.dart';
import 'package:tick_go/core/pay_period.dart';
import 'package:tick_go/models/attendance_record.dart';
import 'package:tick_go/models/employee.dart';
import 'package:tick_go/services/auth_service.dart';
import 'package:tick_go/services/data_service.dart';

void main() {
  group('Định dạng', () {
    test('tiền VND có dấu chấm ngăn cách nghìn', () {
      expect(Fmt.money(5200000), '5.200.000');
      expect(Fmt.money(300000), '300.000');
      expect(Fmt.money(0), '0');
      expect(Fmt.currency(7650000), '7.650.000đ');
    });

    test('giờ tăng ca hiển thị theo giờ + phút, không dùng giờ thập phân', () {
      expect(Fmt.otHours(0), '0h');
      expect(Fmt.otHours(25), '25p');
      expect(Fmt.otHours(30), '30p');
      expect(Fmt.otHours(59), '59p');
      expect(Fmt.otHours(60), '1h');
      expect(Fmt.otHours(90), '1h30');
      expect(Fmt.otHours(65), '1h05');
      expect(Fmt.otHours(120), '2h');
    });

    test('giờ tăng ca dạng thập phân chỉ dùng cho file xuất', () {
      expect(Fmt.otHoursDecimal(0), '0');
      expect(Fmt.otHoursDecimal(30), '0,5');
      expect(Fmt.otHoursDecimal(90), '1,5');
      expect(Fmt.otHoursDecimal(120), '2');
    });

    test(
        'giờ làm của công Tuỳ chỉnh hiện theo giờ (không phải số công), để '
        'không nhầm với ngày công', () {
      // 0,75 công trên chuẩn 8 giờ/ngày = 6 giờ.
      expect(Fmt.customWorkHours(0.75, 8), '6h');
      // 0,6875 công (5,5/8 giờ) - làm tròn về mốc 5 phút vẫn ra 5h30.
      expect(Fmt.customWorkHours(0.6875, 8), '5h30');
      expect(Fmt.customWorkHours(1, 8), '8h');
    });

    test('khoá ngày và khoá tháng', () {
      final d = DateTime(2026, 9, 6);
      expect(Fmt.dateKey(d), '2026-09-06');
      expect(Fmt.monthKey(d), '2026-09');
      expect(Fmt.parseDateKey('2026-09-06'), d);
    });
  });

  group('Quy tắc chấm công', () {
    test('Đi làm = 1 công, Nghỉ = 0 công', () {
      final base = AttendanceRecord(
        employeeId: 'e1',
        workDate: '2026-09-06',
        month: '2026-09',
        status: AttendanceStatus.none,
        workUnits: 0,
        overtimeMinutes: 0,
      );

      final present = base.copyWith(status: AttendanceStatus.present);
      expect(present.workUnits, 1);

      final absent = present.copyWith(status: AttendanceStatus.absent);
      expect(absent.workUnits, 0);
    });

    test('Nửa công = 0,5 công', () {
      expect(AttendanceStatus.present.workUnits, 1);
      expect(AttendanceStatus.half.workUnits, 0.5);
      expect(AttendanceStatus.absent.workUnits, 0);
      expect(AttendanceStatus.none.workUnits, 0);
    });

    test('trạng thái ghi xuống rồi đọc lại vẫn đúng', () {
      for (final s in AttendanceStatus.values) {
        expect(AttendanceStatus.fromCode(s.code), s);
      }
      // Dữ liệu cũ không có trường status thì coi như chưa chấm.
      expect(AttendanceStatus.fromCode(null), AttendanceStatus.none);
      expect(AttendanceStatus.fromCode('LA_GI_DO'), AttendanceStatus.none);
    });

    test('forDay dựng đúng khoá ngày, khoá tháng và số công', () {
      final r = AttendanceRecord.forDay(
        employeeId: 'e1',
        day: DateTime(2026, 9, 6, 22, 30),
        status: AttendanceStatus.half,
        overtimeMinutes: 90,
      );

      expect(r.workDate, '2026-09-06');
      expect(r.month, '2026-09');
      expect(r.workUnits, 0.5);
      expect(r.overtimeMinutes, 90);
      expect(r.id, 'e1_2026-09-06');
    });

    test('OT âm bị ép về 0', () {
      final r = AttendanceRecord.forDay(
        employeeId: 'e1',
        day: DateTime(2026, 9, 6),
        status: AttendanceStatus.present,
        overtimeMinutes: -30,
      );
      expect(r.overtimeMinutes, 0);
    });

    test('OT được lưu độc lập, đổi trạng thái không mất OT', () {
      final r = AttendanceRecord(
        employeeId: 'e1',
        workDate: '2026-09-06',
        month: '2026-09',
        status: AttendanceStatus.present,
        workUnits: 1,
        overtimeMinutes: 90,
      ).copyWith(status: AttendanceStatus.absent);

      expect(r.workUnits, 0);
      expect(r.overtimeMinutes, 90);
    });

    test(
        'Tuỳ chỉnh lấy đúng số công người dùng nhập, không theo số cố định '
        'của enum', () {
      // Làm 6 giờ trên tổng 8 giờ/ngày = 0,75 công - không phải 0 như
      // AttendanceStatus.custom.workUnits (giá trị đó chỉ là mặc định an
      // toàn, không được dùng để tính lương cho Tuỳ chỉnh).
      final r = AttendanceRecord.forDay(
        employeeId: 'e1',
        day: DateTime(2026, 9, 6),
        status: AttendanceStatus.custom,
        workUnits: 0.75,
      );
      expect(r.workUnits, 0.75);

      // Không truyền workUnits cho Tuỳ chỉnh thì mặc định 0, không crash.
      final noUnits = AttendanceRecord.forDay(
        employeeId: 'e1',
        day: DateTime(2026, 9, 6),
        status: AttendanceStatus.custom,
      );
      expect(noUnits.workUnits, 0);

      // copyWith giữ nguyên số công Tuỳ chỉnh khi không truyền workUnits mới
      // (ví dụ chỉ sửa OT) - không thì sửa OT sẽ vô tình xoá công đã nhập.
      final keptUnits = r.copyWith(overtimeMinutes: 60);
      expect(keptUnits.workUnits, 0.75);
      expect(keptUnits.overtimeMinutes, 60);

      // Ba trạng thái cố định bỏ qua workUnits được truyền vào.
      final present = r.copyWith(status: AttendanceStatus.present, workUnits: 0.75);
      expect(present.workUnits, 1);
    });

    test('một nhân viên chỉ có một bản ghi cho một ngày', () {
      expect(
        AttendanceRecord.docId('e1', '2026-09-06'),
        AttendanceRecord.docId('e1', '2026-09-06'),
      );
      expect(
        AttendanceRecord.docId('e1', '2026-09-06'),
        isNot(AttendanceRecord.docId('e2', '2026-09-06')),
      );
    });
  });

  group('Tổng hợp tháng và tính lương', () {
    AttendanceRecord rec(
      String id,
      String date,
      AttendanceStatus status,
      int ot,
    ) => AttendanceRecord(
      employeeId: id,
      workDate: date,
      month: '2026-09',
      status: status,
      workUnits: status.workUnits,
      overtimeMinutes: ot,
    );

    test('Lương công = tổng công × lương/ngày, cộng thêm tiền OT', () {
      const lan = Employee(
        id: 'lan',
        name: 'Cô Lan',
        dailySalary: 300000,
        otRate: 50000,
      );
      final records = [
        for (var d = 1; d <= 25; d++)
          rec('lan', '2026-09-${Fmt.pad2(d)}', AttendanceStatus.present, 0),
        rec('lan', '2026-09-26', AttendanceStatus.absent, 0),
        rec('lan', '2026-09-27', AttendanceStatus.present, 240),
      ];

      final s = DataService.summarize([lan], records).single;

      expect(s.totalWorkUnits, 26);
      expect(s.absentDays, 1);
      expect(s.overtimeMinutes, 240);
      expect(s.basePay, 26 * 300000);
      expect(s.otPay, 4 * 50000);
      expect(s.totalPay, 26 * 300000 + 4 * 50000);
    });

    test('đơn giá OT = 0 thì tổng lương chỉ bằng tổng công × lương/ngày', () {
      const mai = Employee(id: 'mai', name: 'Cô Mai', dailySalary: 200000);
      final records = [
        rec('mai', '2026-09-01', AttendanceStatus.present, 60),
        rec('mai', '2026-09-02', AttendanceStatus.present, 30),
      ];

      final s = DataService.summarize([mai], records).single;

      expect(s.overtimeMinutes, 90);
      expect(s.otPay, 0);
      expect(s.totalPay, 2 * 200000);
    });

    test('nửa công chỉ tính 0,5 công và không tính là ngày nghỉ', () {
      const mai = Employee(id: 'mai', name: 'Cô Mai', dailySalary: 200000);
      final records = [
        rec('mai', '2026-09-01', AttendanceStatus.present, 0),
        rec('mai', '2026-09-02', AttendanceStatus.half, 0),
        rec('mai', '2026-09-03', AttendanceStatus.half, 0),
        rec('mai', '2026-09-04', AttendanceStatus.absent, 0),
      ];

      final s = DataService.summarize([mai], records).single;

      // 1 + 0,5 + 0,5 + 0 = 2 công
      expect(s.totalWorkUnits, 2);
      // Chỉ ngày 04 mới là nghỉ, hai ngày nửa công không tính.
      expect(s.absentDays, 1);
      expect(s.halfDays, 2);
      expect(s.totalPay, 2 * 200000);
    });

    test('tách được số ngày đi làm đủ ra khỏi tổng công', () {
      const mai = Employee(id: 'mai', name: 'Cô Mai', dailySalary: 200000);
      final records = [
        rec('mai', '2026-09-01', AttendanceStatus.present, 0),
        rec('mai', '2026-09-02', AttendanceStatus.present, 0),
        rec('mai', '2026-09-03', AttendanceStatus.half, 0),
        rec('mai', '2026-09-04', AttendanceStatus.absent, 0),
      ];

      final s = DataService.summarize([mai], records).single;

      // 2 ngày đủ + 1 ngày nửa = 2,5 công
      expect(s.totalWorkUnits, 2.5);
      expect(s.presentDays, 2);
      expect(s.halfDays, 1);
      expect(s.absentDays, 1);
      expect(s.markedDays, 4);
    });

    test(
        'công Tuỳ chỉnh (làm 5-6 tiếng) cộng đúng vào tổng công và lương của '
        'ngày đó', () {
      const mai = Employee(id: 'mai', name: 'Cô Mai', dailySalary: 200000);
      final records = [
        rec('mai', '2026-09-01', AttendanceStatus.present, 0),
        AttendanceRecord(
          employeeId: 'mai',
          workDate: '2026-09-02',
          month: '2026-09',
          status: AttendanceStatus.custom,
          // Làm 6/8 giờ = 0,75 công - không phải 0,5 (Nửa công) hay 1 (Đi
          // làm), đúng luật "làm 5-6 tiếng thì lương chỉnh theo giờ công đó".
          workUnits: 0.75,
          overtimeMinutes: 0,
        ),
      ];

      final s = DataService.summarize([mai], records).single;

      expect(s.totalWorkUnits, 1.75);
      expect(s.customDays, 1);
      expect(s.presentDays, 1);
      expect(s.markedDays, 2);
      expect(s.basePay, 1.75 * 200000);
    });

    test('nhân viên chưa có bản ghi nào thì lương bằng 0', () {
      const hoa = Employee(id: 'hoa', name: 'Cô Hoa', dailySalary: 250000);
      final s = DataService.summarize([hoa], const []).single;

      expect(s.totalWorkUnits, 0);
      expect(s.absentDays, 0);
      expect(s.totalPay, 0);
    });
  });

  group('Quỹ lương theo quý / theo năm', () {
    const lan = Employee(
      id: 'lan',
      name: 'Cô Lan',
      dailySalary: 300000,
      otRate: 50000,
    );
    // Người đã nghỉ việc nhưng vẫn còn công trong kỳ cũ.
    const cu = Employee(
      id: 'cu',
      name: 'Cô Cũ',
      dailySalary: 200000,
      active: false,
    );

    AttendanceRecord rec(String id, String date, int ot) => AttendanceRecord(
      employeeId: id,
      workDate: date,
      month: date.substring(0, 7),
      status: AttendanceStatus.present,
      workUnits: 1,
      overtimeMinutes: ot,
    );

    test('kỳ thuộc quý nào - tính theo tháng chốt kỳ', () {
      // Kỳ trùng tháng dương lịch.
      expect(PayPeriod.of(DateTime(2026, 1), 1).quarter, 1);
      expect(PayPeriod.of(DateTime(2026, 3), 1).quarter, 1);
      expect(PayPeriod.of(DateTime(2026, 4), 1).quarter, 2);
      expect(PayPeriod.of(DateTime(2026, 9), 1).quarter, 3);
      expect(PayPeriod.of(DateTime(2026, 12), 1).quarter, 4);

      // Kỳ vắt hai tháng vẫn thuộc quý của tháng chốt: 26/08 - 25/09 là quý 3.
      final p = PayPeriod.of(DateTime(2026, 9), 26);
      expect(p.start, DateTime(2026, 8, 26));
      expect(p.quarter, 3);
      // 26/09 - 25/10 chốt trong tháng 10 nên đã sang quý 4.
      expect(PayPeriod.of(DateTime(2026, 10), 26).quarter, 4);
    });

    test('tổng quỹ lương của một nhóm bản ghi gộp cả người đã nghỉ việc', () {
      final records = [
        rec('lan', '2026-09-01', 0),
        rec('lan', '2026-09-02', 60),
        rec('cu', '2026-09-01', 0),
      ];

      final total = DataService.totalPayrollOf([lan, cu], records);

      // Lan: 2 công x 300.000 + 1h x 50.000 = 650.000
      // Cô Cũ đã nghỉ việc nhưng có công nên vẫn tính: 1 x 200.000
      expect(total, 650000 + 200000);
    });

    test('quỹ lương của một quý là tổng ba kỳ trong quý đó', () {
      final byMonth = {
        7: [rec('lan', '2026-07-01', 0), rec('lan', '2026-07-02', 0)],
        8: [rec('lan', '2026-08-01', 0)],
        9: [rec('lan', '2026-09-01', 120)],
      };

      var quarterTotal = 0.0;
      for (final month in [7, 8, 9]) {
        final p = PayPeriod.of(DateTime(2026, month), 1);
        expect(p.quarter, 3);
        quarterTotal += DataService.totalPayrollOf([lan], byMonth[month]!);
      }

      // 4 công x 300.000 + 2h x 50.000
      expect(quarterTotal, 4 * 300000 + 2 * 50000);
    });

    test('kỳ không có bản ghi nào thì quỹ lương bằng 0', () {
      expect(DataService.totalPayrollOf([lan], const []), 0);
    });
  });

  group('Âm lịch', () {
    // Mốc kiểm chứng lấy từ lịch in: mùng 1 Tết các năm, rằm Trung thu và
    // hai năm có tháng nhuận. Sai một ngày là hỏng cả cột âm lịch trong lịch
    // chọn ngày, nên phải khoá bằng test.
    test('mùng 1 Tết các năm rơi đúng ngày dương', () {
      void tet(DateTime solar, int year, String canChi) {
        final l = LunarDate.fromSolar(solar);
        expect(l.day, 1, reason: '$solar');
        expect(l.month, 1, reason: '$solar');
        expect(l.year, year, reason: '$solar');
        expect(l.isLeapMonth, isFalse, reason: '$solar');
        expect(l.canChi, canChi, reason: '$solar');
      }

      tet(DateTime(2023, 1, 22), 2023, 'Quý Mão');
      tet(DateTime(2024, 2, 10), 2024, 'Giáp Thìn');
      tet(DateTime(2025, 1, 29), 2025, 'Ất Tỵ');
      tet(DateTime(2026, 2, 17), 2026, 'Bính Ngọ');
    });

    test('rằm Trung thu 2024 là 17/09 dương', () {
      final l = LunarDate.fromSolar(DateTime(2024, 9, 17));
      expect(l.day, 15);
      expect(l.month, 8);
    });

    test('nhận ra tháng nhuận', () {
      // Ất Tỵ 2025 nhuận tháng 6, Quý Mão 2023 nhuận tháng 2.
      final l2025 = LunarDate.fromSolar(DateTime(2025, 8, 1));
      expect(l2025.month, 6);
      expect(l2025.isLeapMonth, isTrue);

      final l2023 = LunarDate.fromSolar(DateTime(2023, 3, 25));
      expect(l2023.month, 2);
      expect(l2023.isLeapMonth, isTrue);
    });

    test('nhãn ngắn chỉ hiện tháng ở mùng 1', () {
      // 17/02/2026 là mùng 1 tháng giêng.
      expect(Fmt.lunarShort(DateTime(2026, 2, 17)), '1/1');
      expect(Fmt.lunarShort(DateTime(2026, 2, 18)), '2');
      // Ngày đầu tháng 6 nhuận Ất Tỵ: 25/07/2025.
      expect(Fmt.lunarShort(DateTime(2025, 7, 25)), '1/6N');
    });
  });

  group('Nhân viên', () {
    test('chữ cái đầu dùng cho avatar', () {
      expect(
        const Employee(id: '1', name: 'Cô Lan', dailySalary: 0).initials,
        'CL',
      );
      expect(
        const Employee(id: '2', name: 'Nguyễn Thị Mai', dailySalary: 0).initials,
        'TM',
      );
      expect(const Employee(id: '3', name: 'Mai', dailySalary: 0).initials, 'M');
    });
  });

  group('Ô nhập tiền', () {
    test('đọc lại số từ chuỗi đã định dạng', () {
      expect(parseMoney('5.200.000'), 5200000);
      expect(parseMoney('200.000đ'), 200000);
      expect(parseMoney(''), 0);
    });
  });

  group('Kỳ lương', () {
    test('ngày bắt đầu = 1 thì kỳ trùng đúng tháng dương lịch', () {
      final p = PayPeriod.of(DateTime(2026, 9), 1);

      expect(p.start, DateTime(2026, 9, 1));
      expect(p.end, DateTime(2026, 9, 30));
      expect(p.dayCount, 30);
      expect(p.isCalendarMonth, isTrue);
    });

    test('tháng 2 lấy đúng số ngày', () {
      expect(PayPeriod.of(DateTime(2026, 2), 1).end, DateTime(2026, 2, 28));
      expect(PayPeriod.of(DateTime(2028, 2), 1).end, DateTime(2028, 2, 29));
    });

    test('ngày bắt đầu = 26 thì kỳ chạy từ 26 tháng trước đến 25 tháng này', () {
      final p = PayPeriod.of(DateTime(2026, 9), 26);

      expect(p.start, DateTime(2026, 8, 26));
      expect(p.end, DateTime(2026, 9, 25));
      expect(p.dayCount, 31);
      expect(p.isCalendarMonth, isFalse);
      expect(p.rangeLabel, '26/08 - 25/09/2026');
    });

    test('kỳ tháng 1 lùi về tháng 12 năm trước', () {
      final p = PayPeriod.of(DateTime(2026, 1), 26);

      expect(p.start, DateTime(2025, 12, 26));
      expect(p.end, DateTime(2026, 1, 25));
    });

    test('kỳ đang diễn ra bám theo ngày chốt', () {
      // Chưa tới ngày chốt -> vẫn thuộc kỳ chốt trong tháng này.
      final before = PayPeriod.current(26, now: DateTime(2026, 9, 6));
      expect(before.start, DateTime(2026, 8, 26));
      expect(before.end, DateTime(2026, 9, 25));
      expect(before.contains(DateTime(2026, 9, 6)), isTrue);

      // Đã qua ngày chốt -> sang kỳ mới.
      final after = PayPeriod.current(26, now: DateTime(2026, 9, 27));
      expect(after.start, DateTime(2026, 9, 26));
      expect(after.end, DateTime(2026, 10, 25));
      expect(after.contains(DateTime(2026, 9, 27)), isTrue);
    });

    test('kỳ chứa một ngày bất kỳ - lịch chọn ngày dựa vào phép này', () {
      // Lịch ở tab Chấm công vẽ lưới theo kỳ, nên với mọi ngày trong kỳ nó
      // phải dựng ra đúng một kỳ duy nhất chứa ngày đó.
      for (final day in [
        DateTime(2026, 8, 28),
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 27),
      ]) {
        final p = PayPeriod.current(28, now: day);
        expect(p.start, DateTime(2026, 8, 28), reason: '$day');
        expect(p.end, DateTime(2026, 9, 27), reason: '$day');
        expect(p.contains(day), isTrue, reason: '$day');
      }

      // Ngày ngay trước mốc chốt thuộc kỳ liền trước.
      final prev = PayPeriod.current(28, now: DateTime(2026, 8, 27));
      expect(prev.start, DateTime(2026, 7, 28));
      expect(prev.end, DateTime(2026, 8, 27));

      // startDay = 1 thì kỳ trùng tháng dương lịch.
      final calendar = PayPeriod.current(1, now: DateTime(2026, 9, 15));
      expect(calendar.start, DateTime(2026, 9, 1));
      expect(calendar.end, DateTime(2026, 9, 30));
    });

    test('contains chặn đúng hai đầu mút', () {
      final p = PayPeriod.of(DateTime(2026, 9), 26);

      expect(p.contains(DateTime(2026, 8, 25)), isFalse);
      expect(p.contains(DateTime(2026, 8, 26)), isTrue);
      expect(p.contains(DateTime(2026, 9, 25)), isTrue);
      expect(p.contains(DateTime(2026, 9, 26)), isFalse);
    });

    test('days liệt kê đủ từng ngày trong kỳ', () {
      final p = PayPeriod.of(DateTime(2026, 9), 26);
      final days = p.days;

      expect(days.length, p.dayCount);
      expect(days.first, p.start);
      expect(days.last, p.end);
    });

    test('khoá ngày dùng cho query Firestore so sánh được bằng chuỗi', () {
      final p = PayPeriod.of(DateTime(2026, 9), 26);

      expect(p.startKey, '2026-08-26');
      expect(p.endKey, '2026-09-25');
      // Chuỗi yyyy-MM-dd so sánh theo thứ tự từ điển đúng bằng so sánh ngày.
      expect('2026-09-01'.compareTo(p.startKey) > 0, isTrue);
      expect('2026-09-01'.compareTo(p.endKey) < 0, isTrue);
    });

    test('shift chuyển sang kỳ trước / kỳ sau', () {
      final p = PayPeriod.of(DateTime(2026, 9), 26);

      expect(p.shift(-1, 26).end, DateTime(2026, 8, 25));
      expect(p.shift(1, 26).end, DateTime(2026, 10, 25));
    });
  });

  group('Cộng công theo kỳ vắt qua hai tháng', () {
    test('tổng công lấy đủ ngày của cả hai tháng trong kỳ', () {
      const lan = Employee(
        id: 'lan',
        name: 'Cô Lan',
        dailySalary: 300000,
        otRate: 50000,
      );
      // Kỳ 26/08 - 25/09: 4 ngày cuối tháng 8 + 2 ngày đầu tháng 9.
      final records = [
        for (final d in ['2026-08-27', '2026-08-28', '2026-08-29', '2026-08-30'])
          AttendanceRecord(
            employeeId: 'lan',
            workDate: d,
            month: '2026-08',
            status: AttendanceStatus.present,
            workUnits: 1,
            overtimeMinutes: 0,
          ),
        for (final d in ['2026-09-01', '2026-09-02'])
          AttendanceRecord(
            employeeId: 'lan',
            workDate: d,
            month: '2026-09',
            status: AttendanceStatus.present,
            workUnits: 1,
            overtimeMinutes: 60,
          ),
      ];

      final s = DataService.summarize([lan], records).single;

      expect(s.totalWorkUnits, 6);
      expect(s.overtimeMinutes, 120);
      expect(s.totalPay, 6 * 300000 + 2 * 50000);
    });
  });

  // Bản nhiều cơ sở: mỗi tài khoản chủ = một cơ sở, companyId = uid.
  group('Tài khoản và cơ sở', () {
    test('email thật giữ nguyên, tên tài khoản ngắn mới ghép hậu tố', () {
      // Đăng ký bản mới bắt buộc email thật để gửi được mail đặt lại mật khẩu.
      expect(
        AuthService.normalizeAccount('  Chu@Gmail.com '),
        'Chu@Gmail.com',
      );
      // Tài khoản kiểu cũ (không có @) vẫn phải đăng nhập được.
      expect(AuthService.normalizeAccount('admin'), 'admin@tickgo.app');
    });

    test('displayAccount chỉ bỏ hậu tố nội bộ, email thật để nguyên', () {
      expect(AuthService.displayAccount('admin@tickgo.app'), 'admin');
      expect(AuthService.displayAccount('chu@gmail.com'), 'chu@gmail.com');
    });

    test('chỉ role "super" mới là tài khoản tổng', () {
      expect(AuthService.isSuperAccount({'role': 'super'}), isTrue);
      expect(AuthService.isSuperAccount({'role': 'owner'}), isFalse);
      expect(AuthService.isSuperAccount({}), isFalse);
      // Không có role thì là chủ cơ sở thường - đây là trường hợp phổ biến nhất.
      expect(AuthService.isSuperAccount({'companyId': 'abc'}), isFalse);
    });
  });
}
