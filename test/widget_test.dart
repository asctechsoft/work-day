import 'package:flutter_test/flutter_test.dart';
import 'package:tick_go/core/formatters.dart';
import 'package:tick_go/core/pay_period.dart';
import 'package:tick_go/models/attendance_record.dart';
import 'package:tick_go/models/employee.dart';
import 'package:tick_go/services/data_service.dart';

void main() {
  group('Định dạng', () {
    test('tiền VND có dấu chấm ngăn cách nghìn', () {
      expect(Fmt.money(5200000), '5.200.000');
      expect(Fmt.money(300000), '300.000');
      expect(Fmt.money(0), '0');
      expect(Fmt.currency(7650000), '7.650.000đ');
    });

    test('giờ tăng ca hiển thị gọn', () {
      expect(Fmt.otHours(0), '0h');
      expect(Fmt.otHours(30), '0.5h');
      expect(Fmt.otHours(60), '1h');
      expect(Fmt.otHours(90), '1.5h');
      expect(Fmt.otHours(120), '2h');
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

    test('nhân viên chưa có bản ghi nào thì lương bằng 0', () {
      const hoa = Employee(id: 'hoa', name: 'Cô Hoa', dailySalary: 250000);
      final s = DataService.summarize([hoa], const []).single;

      expect(s.totalWorkUnits, 0);
      expect(s.absentDays, 0);
      expect(s.totalPay, 0);
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
}
