import 'package:cloud_firestore/cloud_firestore.dart';

/// Trạng thái chấm công của một nhân viên trong một ngày.
enum AttendanceStatus {
  /// Chưa có dữ liệu chấm công.
  none,

  /// Đi làm cả ngày = 1 công.
  present,

  /// Có đến làm nhưng về giữa chừng = 0,5 công.
  half,

  /// Nghỉ = 0 công.
  absent,

  /// Làm không tròn nửa ngày (ví dụ 5-6 tiếng) - số công nhập tay theo giờ
  /// làm thực tế, không cố định như ba trạng thái trên. Số công thật của
  /// một bản ghi Tuỳ chỉnh nằm ở `AttendanceRecord.workUnits`, không nằm ở
  /// enum này (xem ghi chú ở `workUnits` bên dưới).
  custom;

  String get label => switch (this) {
        AttendanceStatus.none => 'Chưa chấm',
        AttendanceStatus.present => 'Đi làm',
        AttendanceStatus.half => 'Nửa công',
        AttendanceStatus.absent => 'Nghỉ',
        AttendanceStatus.custom => 'Tuỳ chỉnh',
      };

  /// Mô tả ngắn hiện trong bảng chọn trạng thái.
  String get hint => switch (this) {
        AttendanceStatus.none => 'Xoá dữ liệu của ngày này',
        AttendanceStatus.present => 'Làm đủ ngày · 1 công',
        AttendanceStatus.half => 'Về giữa chừng · 0,5 công',
        AttendanceStatus.absent => 'Không đi làm · 0 công',
        AttendanceStatus.custom => 'Làm không tròn nửa ngày · nhập theo giờ',
      };

  /// Số công tương ứng của ba trạng thái cố định - nguồn duy nhất quyết
  /// định số công của chúng, đừng tính lại ở chỗ khác.
  ///
  /// Riêng Tuỳ chỉnh không có số công cố định: giá trị thật nằm ở
  /// `AttendanceRecord.workUnits` do người dùng nhập (quy đổi từ số giờ
  /// làm), đọc trực tiếp ở đó - giá trị `0` trả về ở đây chỉ là mặc định an
  /// toàn, không được dùng để tính lương.
  double get workUnits => switch (this) {
        AttendanceStatus.present => 1,
        AttendanceStatus.half => 0.5,
        AttendanceStatus.none || AttendanceStatus.absent => 0,
        AttendanceStatus.custom => 0,
      };

  String get code => switch (this) {
        AttendanceStatus.none => 'NONE',
        AttendanceStatus.present => 'PRESENT',
        AttendanceStatus.half => 'HALF',
        AttendanceStatus.absent => 'ABSENT',
        AttendanceStatus.custom => 'CUSTOM',
      };

  static AttendanceStatus fromCode(String? code) => switch (code) {
        'PRESENT' => AttendanceStatus.present,
        'HALF' => AttendanceStatus.half,
        'ABSENT' => AttendanceStatus.absent,
        'CUSTOM' => AttendanceStatus.custom,
        _ => AttendanceStatus.none,
      };
}

/// Một bản ghi cho mỗi nhân viên / ngày.
/// Id của document luôn là "{employeeId}_{yyyy-MM-dd}" nên không thể
/// tạo trùng hai bản ghi cho cùng một ngày.
class AttendanceRecord {
  final String employeeId;

  /// yyyy-MM-dd
  final String workDate;

  /// yyyy-MM - lưu sẵn để truy vấn tổng hợp theo tháng.
  final String month;

  final AttendanceStatus status;

  /// 1 khi đi làm, 0 khi nghỉ.
  final double workUnits;

  /// Số phút tăng ca: 0, 30, 60, 90, 120... Không bao giờ âm.
  final int overtimeMinutes;

  const AttendanceRecord({
    required this.employeeId,
    required this.workDate,
    required this.month,
    required this.status,
    required this.workUnits,
    required this.overtimeMinutes,
  });

  static String docId(String employeeId, String dateKey) =>
      '${employeeId}_$dateKey';

  String get id => docId(employeeId, workDate);

  factory AttendanceRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AttendanceRecord(
      employeeId: (d['employeeId'] ?? '') as String,
      workDate: (d['workDate'] ?? '') as String,
      month: (d['month'] ?? '') as String,
      status: AttendanceStatus.fromCode(d['status'] as String?),
      workUnits: (d['workUnits'] as num?)?.toDouble() ?? 0,
      overtimeMinutes: (d['overtimeMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'workDate': workDate,
        'month': month,
        'status': status.code,
        'workUnits': workUnits,
        'overtimeMinutes': overtimeMinutes < 0 ? 0 : overtimeMinutes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// [workUnits] chỉ có tác dụng khi [status] (hoặc trạng thái hiện tại nếu
  /// không đổi) là Tuỳ chỉnh - ba trạng thái còn lại luôn lấy đúng số công
  /// cố định của chúng, bất kể có truyền gì vào đây.
  AttendanceRecord copyWith({
    AttendanceStatus? status,
    int? overtimeMinutes,
    double? workUnits,
  }) {
    final s = status ?? this.status;
    return AttendanceRecord(
      employeeId: employeeId,
      workDate: workDate,
      month: month,
      status: s,
      workUnits:
          s == AttendanceStatus.custom ? (workUnits ?? this.workUnits) : s.workUnits,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
    );
  }

  /// Dựng bản ghi mới cho một nhân viên trong một ngày.
  ///
  /// [workUnits] bắt buộc phải truyền khi [status] là Tuỳ chỉnh (số công quy
  /// đổi từ số giờ làm thực tế) - ba trạng thái còn lại tự lấy số công cố
  /// định của mình, bỏ qua tham số này.
  factory AttendanceRecord.forDay({
    required String employeeId,
    required DateTime day,
    required AttendanceStatus status,
    int overtimeMinutes = 0,
    double? workUnits,
  }) {
    final d = DateTime(day.year, day.month, day.day);
    return AttendanceRecord(
      employeeId: employeeId,
      workDate:
          '${d.year}-${_p2(d.month)}-${_p2(d.day)}',
      month: '${d.year}-${_p2(d.month)}',
      status: status,
      workUnits:
          status == AttendanceStatus.custom ? (workUnits ?? 0) : status.workUnits,
      overtimeMinutes: overtimeMinutes < 0 ? 0 : overtimeMinutes,
    );
  }

  static String _p2(int v) => v.toString().padLeft(2, '0');

  /// Phân loại ngày để chọn đơn giá OT: ngày lễ được ưu tiên hơn cuối tuần
  /// (một ngày lễ rơi đúng Thứ 7/CN vẫn tính là ngày lễ).
  OtDayKind otDayKind(Set<String> holidayDates) {
    if (holidayDates.contains(workDate)) return OtDayKind.holiday;
    final weekday = DateTime.parse(workDate).weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return OtDayKind.weekend;
    }
    return OtDayKind.normal;
  }
}

/// Loại ngày dùng để chọn đơn giá OT áp dụng cho phút tăng ca của ngày đó.
enum OtDayKind {
  /// Ngày thường - dùng `Employee.otRate`.
  normal,

  /// Thứ 7 / Chủ nhật - dùng `Employee.otRateWeekend` nếu > 0, không thì
  /// dùng `otRate` (xem [MonthlySummary.otPay]).
  weekend,

  /// Ngày lễ khai trong `AppSettings.holidayDates` - dùng
  /// `Employee.otRateHoliday` nếu > 0, không thì dùng `otRate`.
  holiday,
}

/// Tổng hợp công - OT - lương của một nhân viên trong một tháng.
class MonthlySummary {
  final String employeeId;
  final double totalWorkUnits;
  final int absentDays;

  /// Số ngày chấm Nửa công.
  final int halfDays;

  /// Số ngày chấm Tuỳ chỉnh (làm không tròn nửa ngày).
  final int customDays;

  /// Số ngày đi làm đủ (Đi làm = 1 công).
  final int presentDays;

  /// Số phút OT của ngày thường - trả theo [otRate].
  final int overtimeMinutesNormal;

  /// Số phút OT rơi vào Thứ 7 / Chủ nhật - trả theo [otRateWeekend] nếu > 0,
  /// không thì trả theo [otRate] như ngày thường.
  final int overtimeMinutesWeekend;

  /// Số phút OT rơi vào ngày lễ (`AppSettings.holidayDates`) - trả theo
  /// [otRateHoliday] nếu > 0, không thì trả theo [otRate].
  final int overtimeMinutesHoliday;

  final double dailySalary;
  final double otRate;

  /// Đơn giá OT/giờ riêng cho cuối tuần. 0 = dùng chung [otRate] - đây là
  /// ngoại lệ bổ sung 19/09/2026 cho nghiệp vụ OT cuối tuần/ngày lễ trả cao
  /// hơn ngày thường, cùng dạng ngoại lệ đã mở ở §0.4/§0.2 CLAUDE.md.
  final double otRateWeekend;

  /// Đơn giá OT/giờ riêng cho ngày lễ. 0 = dùng chung [otRate].
  final double otRateHoliday;

  /// Số công rơi vào ngày lễ (`AppSettings.holidayDates`) - phần này của
  /// [basePay] được nhân thêm [holidayPayMultiplier], phần công còn lại tính
  /// bình thường.
  final double workUnitsHoliday;

  /// Hệ số nhân lương công của ngày lễ - ví dụ 2 = lương công ngày lễ gấp
  /// đôi ngày thường. Mặc định 1 = không nhân, tính như ngày thường. Đây là
  /// ngoại lệ bổ sung 21/09/2026, người dùng yêu cầu sau khi hỏi cách tính
  /// tiền ngày lễ - **khác** đơn giá OT ngày lễ ([otRateHoliday]): hệ số này
  /// nhân vào lương công (`basePay`), còn [otRateHoliday] chỉ áp cho phần
  /// tăng ca, hai thứ cộng lại mới ra tổng lương của một ngày lễ có tăng ca.
  final double holidayPayMultiplier;

  const MonthlySummary({
    required this.employeeId,
    required this.totalWorkUnits,
    required this.absentDays,
    required this.dailySalary,
    required this.otRate,
    this.overtimeMinutesNormal = 0,
    this.overtimeMinutesWeekend = 0,
    this.overtimeMinutesHoliday = 0,
    this.otRateWeekend = 0,
    this.otRateHoliday = 0,
    this.workUnitsHoliday = 0,
    this.holidayPayMultiplier = 1,
    this.halfDays = 0,
    this.customDays = 0,
    this.presentDays = 0,
  });

  /// Số ngày đã chấm (đủ công + nửa công + tuỳ chỉnh + nghỉ).
  int get markedDays => presentDays + halfDays + customDays + absentDays;

  /// Tổng số phút OT của cả kỳ, bất kể ngày thường/cuối tuần/lễ.
  int get overtimeMinutes =>
      overtimeMinutesNormal + overtimeMinutesWeekend + overtimeMinutesHoliday;

  /// Đơn giá thật sự áp dụng cho OT cuối tuần: về đơn giá thường nếu cơ sở
  /// không đặt riêng - đọc trực tiếp ở đây, đừng suy ra 0 = "không trả".
  double get effectiveOtRateWeekend => otRateWeekend > 0 ? otRateWeekend : otRate;

  /// Đơn giá thật sự áp dụng cho OT ngày lễ, cùng quy tắc như trên.
  double get effectiveOtRateHoliday => otRateHoliday > 0 ? otRateHoliday : otRate;

  /// Lương công = Tổng công × Lương/ngày, riêng phần công rơi vào ngày lễ
  /// được nhân thêm [holidayPayMultiplier].
  double get basePay =>
      (totalWorkUnits - workUnitsHoliday) * dailySalary +
      workUnitsHoliday * dailySalary * holidayPayMultiplier;

  /// Tiền OT = cộng riêng từng loại ngày vì mỗi loại có thể có đơn giá khác
  /// nhau (§0.5 CLAUDE.md: OT lưu riêng với công, không đổi cách này).
  double get otPay =>
      (overtimeMinutesNormal / 60.0) * otRate +
      (overtimeMinutesWeekend / 60.0) * effectiveOtRateWeekend +
      (overtimeMinutesHoliday / 60.0) * effectiveOtRateHoliday;

  /// Tổng lương = Lương công + Tiền OT
  double get totalPay => basePay + otPay;
}
