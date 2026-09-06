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
  absent;

  String get label => switch (this) {
        AttendanceStatus.none => 'Chưa chấm',
        AttendanceStatus.present => 'Đi làm',
        AttendanceStatus.half => 'Nửa công',
        AttendanceStatus.absent => 'Nghỉ',
      };

  /// Mô tả ngắn hiện trong bảng chọn trạng thái.
  String get hint => switch (this) {
        AttendanceStatus.none => 'Xoá dữ liệu của ngày này',
        AttendanceStatus.present => 'Làm đủ ngày · 1 công',
        AttendanceStatus.half => 'Về giữa chừng · 0,5 công',
        AttendanceStatus.absent => 'Không đi làm · 0 công',
      };

  /// Số công tương ứng. Đây là nguồn duy nhất quyết định số công của
  /// một trạng thái - đừng tính lại ở chỗ khác.
  double get workUnits => switch (this) {
        AttendanceStatus.present => 1,
        AttendanceStatus.half => 0.5,
        AttendanceStatus.none || AttendanceStatus.absent => 0,
      };

  /// Ký hiệu trong file bảng công xuất ra Excel.
  String get exportMark => switch (this) {
        AttendanceStatus.present => 'X',
        AttendanceStatus.half => '1/2',
        AttendanceStatus.absent => 'N',
        AttendanceStatus.none => '',
      };

  String get code => switch (this) {
        AttendanceStatus.none => 'NONE',
        AttendanceStatus.present => 'PRESENT',
        AttendanceStatus.half => 'HALF',
        AttendanceStatus.absent => 'ABSENT',
      };

  static AttendanceStatus fromCode(String? code) => switch (code) {
        'PRESENT' => AttendanceStatus.present,
        'HALF' => AttendanceStatus.half,
        'ABSENT' => AttendanceStatus.absent,
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

  AttendanceRecord copyWith({
    AttendanceStatus? status,
    int? overtimeMinutes,
  }) {
    final s = status ?? this.status;
    return AttendanceRecord(
      employeeId: employeeId,
      workDate: workDate,
      month: month,
      status: s,
      workUnits: s.workUnits,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
    );
  }

  /// Dựng bản ghi mới cho một nhân viên trong một ngày.
  factory AttendanceRecord.forDay({
    required String employeeId,
    required DateTime day,
    required AttendanceStatus status,
    int overtimeMinutes = 0,
  }) {
    final d = DateTime(day.year, day.month, day.day);
    return AttendanceRecord(
      employeeId: employeeId,
      workDate:
          '${d.year}-${_p2(d.month)}-${_p2(d.day)}',
      month: '${d.year}-${_p2(d.month)}',
      status: status,
      workUnits: status.workUnits,
      overtimeMinutes: overtimeMinutes < 0 ? 0 : overtimeMinutes,
    );
  }

  static String _p2(int v) => v.toString().padLeft(2, '0');
}

/// Tổng hợp công - OT - lương của một nhân viên trong một tháng.
class MonthlySummary {
  final String employeeId;
  final double totalWorkUnits;
  final int absentDays;

  /// Số ngày chấm Nửa công.
  final int halfDays;

  final int overtimeMinutes;
  final double dailySalary;
  final double otRate;

  const MonthlySummary({
    required this.employeeId,
    required this.totalWorkUnits,
    required this.absentDays,
    required this.overtimeMinutes,
    required this.dailySalary,
    required this.otRate,
    this.halfDays = 0,
  });

  /// Số ngày đi làm đủ. Suy ra từ tổng công vì nửa công chỉ tính 0,5.
  int get presentDays => (totalWorkUnits - halfDays * 0.5).round();

  /// Số ngày đã chấm (đủ công + nửa công + nghỉ).
  int get markedDays => presentDays + halfDays + absentDays;

  /// Lương công = Tổng công × Lương/ngày
  double get basePay => totalWorkUnits * dailySalary;

  /// Tiền OT = Tổng giờ OT × Đơn giá OT/giờ
  double get otPay => (overtimeMinutes / 60.0) * otRate;

  /// Tổng lương = Lương công + Tiền OT
  double get totalPay => basePay + otPay;
}
