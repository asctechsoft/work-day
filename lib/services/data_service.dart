import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formatters.dart';
import '../core/pay_period.dart';
import '../models/app_review.dart';
import '../models/app_settings.dart';
import '../models/attendance_record.dart';
import '../models/company.dart';
import '../models/employee.dart';

/// Toàn bộ truy cập Firestore của app.
///
/// Mỗi cơ sở (một khách hàng) là một nhánh riêng, `companyId` **chính là uid
/// Firebase của chủ cơ sở**:
///   companies/{companyId}/employees/{id}
///   companies/{companyId}/attendance/{employeeId}_{yyyy-MM-dd}
///   companies/{companyId}/settings/app
///   users/{uid}
///
/// Cách ly giữa các cơ sở là do **cấu trúc** chứ không do câu query: mọi
/// truy cập đều đi qua [_root] nên không có cách nào quên lọc rồi lộ dữ liệu
/// cơ sở khác. Xem `firestore.rules`.
class DataService {
  DataService._(this.companyId);

  /// Dịch vụ của cơ sở đang đăng nhập. `companyId` do [AuthGate] gán ngay sau
  /// khi đăng nhập và xoá về `null` khi đăng xuất.
  static final DataService instance = DataService._(null);

  /// Dịch vụ trỏ vào **một cơ sở khác** - chỉ dùng cho tài khoản tổng xem
  /// báo cáo của khách. Rules chỉ cho tài khoản tổng đọc, mọi lệnh ghi qua
  /// đây sẽ bị Firestore từ chối.
  factory DataService.forCompany(String companyId) =>
      DataService._(companyId);

  /// Cơ sở đang mở. Gán `null` khi đăng xuất để phiên sau không còn trỏ vào
  /// cơ sở cũ.
  String? companyId;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Gốc dữ liệu của cơ sở đang mở.
  ///
  /// Chưa gán `companyId` mà đã đọc/ghi là lỗi lập trình - ném luôn cho thấy,
  /// thà chết ở đây còn hơn ghi dữ liệu vào sai cơ sở.
  DocumentReference<Map<String, dynamic>> get _root {
    final id = companyId;
    if (id == null) {
      throw StateError(
        'DataService chưa có companyId. Phải gán sau khi đăng nhập '
        '(xem AuthGate) hoặc dùng DataService.forCompany(id).',
      );
    }
    return _db.collection('companies').doc(id);
  }

  CollectionReference<Map<String, dynamic>> get _employees =>
      _root.collection('employees');
  CollectionReference<Map<String, dynamic>> get _attendance =>
      _root.collection('attendance');
  DocumentReference<Map<String, dynamic>> get _settings =>
      _root.collection('settings').doc('app');

  // ------------------------------------------------------------------ Cơ sở

  /// Tạo một cơ sở mới cùng thiết lập mặc định và hồ sơ người dùng.
  ///
  /// Ba document ghi trong **cùng một batch**: hoặc có đủ, hoặc không có gì.
  /// Nửa vời (có cơ sở mà thiếu `settings/app`) thì app vẫn vào được nhưng
  /// hiện dữ liệu rỗng mà người dùng không hiểu vì sao.
  ///
  /// [companyId] phải đúng bằng uid vừa tạo, nếu không rules sẽ chặn.
  Future<void> createCompany({
    required String companyId,
    required String orgName,
    required String account,
  }) async {
    final company = _db.collection('companies').doc(companyId);
    final batch = _db.batch();
    batch.set(company, {
      'orgName': orgName,
      'ownerAccount': account,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      company.collection('settings').doc('app'),
      AppSettings(orgName: orgName).toMap(),
    );
    batch.set(_db.collection('users').doc(companyId), {
      'account': account,
      'displayName': orgName,
      'companyId': companyId,
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // --------------------------------------------------------------- Đánh giá

  /// Lưu một lượt đánh giá app của cơ sở đang đăng nhập.
  ///
  /// Nằm trong `companies/{cid}/reviews` chứ không phải một collection riêng ở
  /// gốc: nhánh con của cơ sở đã được `firestore.rules` cho phép sẵn (chủ ghi
  /// được, tài khoản tổng đọc được) nên **không phải sửa và Publish lại rules**.
  ///
  /// Mỗi lượt gửi là một document mới, không ghi đè lượt trước - đọc lại thấy
  /// được cả quá trình khách đổi ý, mà cũng không cần chống trùng như bản ghi
  /// công.
  Future<void> saveReview({
    required int stars,
    required String comment,
    required String appVersion,
  }) => _root.collection('reviews').add({
    'stars': stars.clamp(1, 5),
    'comment': comment.trim(),
    'appVersion': appVersion,
    'createdAt': FieldValue.serverTimestamp(),
  });

  /// Lượt đánh giá gần nhất của cơ sở, `null` nếu chưa có.
  ///
  /// `orderBy` + `limit` trên đúng một trường nên không đòi composite index.
  Future<AppReview?> latestReview() async {
    final snap = await _root
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AppReview.fromDoc(snap.docs.first);
  }

  /// Toàn bộ cơ sở - chỉ tài khoản tổng đọc được (rules chặn người thường).
  ///
  /// Sắp xếp ở client cho khỏi phụ thuộc `orderBy`: cơ sở nào thiếu `orgName`
  /// thì `orderBy` sẽ bỏ qua luôn, mà đó chính là cơ sở đang có vấn đề.
  Stream<List<Company>> watchCompanies() =>
      _db.collection('companies').snapshots().map((snap) {
        final list = snap.docs.map(Company.fromDoc).toList();
        list.sort((a, b) => _vnCompare(a.orgName, b.orgName));
        return list;
      });

  // ---------------------------------------------------------------- Nhân viên

  /// Danh sách nhân viên đang làm - dùng cho màn Chấm công và Tổng quan.
  Stream<List<Employee>> watchActiveEmployees() => _employees
      .where('active', isEqualTo: true)
      .snapshots()
      .map(_mapEmployees);

  /// Toàn bộ nhân viên kể cả người đã nghỉ - dùng cho màn Quản lý nhân viên.
  Stream<List<Employee>> watchAllEmployees() =>
      _employees.snapshots().map(_mapEmployees);

  List<Employee> _mapEmployees(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs.map(Employee.fromDoc).toList();
    list.sort((a, b) => _vnCompare(a.name, b.name));
    return list;
  }

  Future<Employee?> getEmployee(String id) async {
    final doc = await _employees.doc(id).get();
    return doc.exists ? Employee.fromDoc(doc) : null;
  }

  /// Toàn bộ nhân viên, đọc một lần - dùng khi xuất file.
  Future<List<Employee>> getAllEmployees() async =>
      _mapEmployees(await _employees.get());

  Future<String> addEmployee(Employee e) async {
    final ref = await _employees.add({
      ...e.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateEmployee(Employee e) =>
      _employees.doc(e.id).set(e.toMap(), SetOptions(merge: true));

  Future<void> setEmployeeActive(String id, bool active) =>
      _employees.doc(id).set({'active': active}, SetOptions(merge: true));

  /// Xoá hồ sơ nhân viên. Chỉ dùng khi nhập nhầm - nếu người đó đã có công
  /// thì nên chuyển sang "Đã nghỉ" để giữ lịch sử.
  Future<void> deleteEmployee(String id) => _employees.doc(id).delete();

  Future<int> countAttendanceOf(String employeeId) async {
    final snap =
        await _attendance.where('employeeId', isEqualTo: employeeId).count().get();
    return snap.count ?? 0;
  }

  // --------------------------------------------------------------- Chấm công

  /// Công của một ngày, trả về map employeeId -> bản ghi.
  Stream<Map<String, AttendanceRecord>> watchDay(DateTime day) {
    final key = Fmt.dateKey(day);
    return _attendance.where('workDate', isEqualTo: key).snapshots().map(
          (snap) => {
            for (final doc in snap.docs)
              (doc.data()['employeeId'] ?? '') as String:
                  AttendanceRecord.fromDoc(doc),
          },
        );
  }

  /// Lưu / cập nhật công của một nhân viên trong một ngày.
  /// Luôn ghi đè lên đúng document cũ nên không bao giờ cộng trùng.
  Future<void> saveRecord(AttendanceRecord record) => _attendance
      .doc(record.id)
      .set(record.toMap(), SetOptions(merge: true));

  /// Xoá bản ghi của một ngày (đưa về trạng thái "Chưa chấm").
  Future<void> clearRecord(String employeeId, String dateKey) =>
      _attendance.doc(AttendanceRecord.docId(employeeId, dateKey)).delete();

  /// "Tất cả đi làm": gán 1 công cho toàn bộ danh sách trong một lần ghi.
  /// Giờ OT đã nhập trước đó được giữ nguyên.
  Future<void> markAllPresent({
    required DateTime day,
    required List<Employee> employees,
    required Map<String, AttendanceRecord> existing,
  }) async {
    final dateKey = Fmt.dateKey(day);
    await _commitInBatches(employees.length, (batch, i) {
      final e = employees[i];
      batch.set(
        _attendance.doc(AttendanceRecord.docId(e.id, dateKey)),
        AttendanceRecord.forDay(
          employeeId: e.id,
          day: day,
          status: AttendanceStatus.present,
          overtimeMinutes: existing[e.id]?.overtimeMinutes ?? 0,
        ).toMap(),
        SetOptions(merge: true),
      );
    });
  }

  /// Trả bảng chấm công của một ngày về đúng trạng thái [previous].
  ///
  /// Dùng cho nút "Hoàn tác" sau khi lỡ bấm "Tất cả đi làm": ai trước đó chưa
  /// chấm thì xoá hẳn bản ghi, ai đã có thì ghi lại y như cũ.
  Future<void> restoreDay({
    required DateTime day,
    required List<Employee> employees,
    required Map<String, AttendanceRecord> previous,
  }) async {
    final dateKey = Fmt.dateKey(day);
    await _commitInBatches(employees.length, (batch, i) {
      final e = employees[i];
      final ref = _attendance.doc(AttendanceRecord.docId(e.id, dateKey));
      final old = previous[e.id];
      if (old == null) {
        batch.delete(ref);
      } else {
        batch.set(ref, old.toMap());
      }
    });
  }

  /// Gom thao tác vào các batch tối đa 450 lệnh (Firestore giới hạn 500).
  Future<void> _commitInBatches(
    int count,
    void Function(WriteBatch batch, int index) write,
  ) async {
    var batch = _db.batch();
    var ops = 0;
    for (var i = 0; i < count; i++) {
      write(batch, i);
      ops++;
      if (ops == 450) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }

  // ---------------------------------------------------------- Tổng hợp tháng

  /// Toàn bộ bản ghi công trong một kỳ lương.
  ///
  /// Kỳ lương có thể vắt qua hai tháng dương lịch (ví dụ 26/08 - 25/09) nên
  /// phải lọc theo khoảng ngày. `workDate` là chuỗi yyyy-MM-dd nên so sánh
  /// chuỗi cũng chính là so sánh ngày. Chỉ dùng range trên một trường duy
  /// nhất nên Firestore không đòi composite index.
  Stream<List<AttendanceRecord>> watchPeriod(PayPeriod period) => _attendance
      .where('workDate', isGreaterThanOrEqualTo: period.startKey)
      .where('workDate', isLessThanOrEqualTo: period.endKey)
      .snapshots()
      .map((s) => s.docs.map(AttendanceRecord.fromDoc).toList());

  /// Bản ghi công của một kỳ, đọc một lần - dùng khi xuất file.
  Future<List<AttendanceRecord>> getPeriod(PayPeriod period) async {
    final snap = await _attendance
        .where('workDate', isGreaterThanOrEqualTo: period.startKey)
        .where('workDate', isLessThanOrEqualTo: period.endKey)
        .get();
    return snap.docs.map(AttendanceRecord.fromDoc).toList();
  }

  /// Bản ghi công trong một khoảng ngày bất kỳ, đọc một lần.
  ///
  /// Dùng cho biểu đồ quỹ lương theo quý / theo năm: cần gộp nhiều kỳ liên
  /// tiếp nên đọc trọn khoảng rồi chia nhóm ở client. Vẫn chỉ là range trên
  /// đúng một trường `workDate` nên không đòi composite index.
  Future<List<AttendanceRecord>> getRecordsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final snap = await _attendance
        .where('workDate', isGreaterThanOrEqualTo: Fmt.dateKey(start))
        .where('workDate', isLessThanOrEqualTo: Fmt.dateKey(end))
        .get();
    return snap.docs.map(AttendanceRecord.fromDoc).toList();
  }

  /// Bản ghi công của một nhân viên trong một kỳ, mới nhất lên đầu.
  ///
  /// Lọc nhân viên ở phía client thay vì thêm điều kiện `employeeId` vào query
  /// để khỏi phải tạo composite index trên Firebase Console.
  Stream<List<AttendanceRecord>> watchEmployeePeriod(
    String employeeId,
    PayPeriod period,
  ) =>
      watchPeriod(period).map((all) {
        final list = all.where((r) => r.employeeId == employeeId).toList();
        list.sort((a, b) => b.workDate.compareTo(a.workDate));
        return list;
      });

  /// Danh sách nhân viên cần có mặt trong bảng công của một kỳ.
  ///
  /// Gồm người đang làm, cộng thêm người đã nghỉ nhưng vẫn có công trong kỳ đó
  /// - nếu bỏ sót thì bảng lương của kỳ cũ sẽ thiếu người và sai tổng quỹ lương.
  static List<Employee> employeesForExport(
    List<Employee> all,
    List<AttendanceRecord> records,
  ) {
    final worked = records.map((r) => r.employeeId).toSet();
    final list =
        all.where((e) => e.active || worked.contains(e.id)).toList();
    list.sort((a, b) => _vnCompare(a.name, b.name));
    return list;
  }

  /// Tổng hợp công - OT - lương theo từng nhân viên.
  /// Lương luôn được tính lại từ dữ liệu công nên không cần "chốt bảng lương".
  ///
  /// [holidayDates] (`AppSettings.holidayDates`) quyết định phút OT của ngày
  /// nào được trả theo đơn giá ngày lễ thay vì đơn giá thường/cuối tuần, và
  /// công của ngày nào được nhân [holidayPayMultiplier].
  static List<MonthlySummary> summarize(
    List<Employee> employees,
    List<AttendanceRecord> records, {
    Set<String> holidayDates = const {},
    double holidayPayMultiplier = 1,
  }) {
    final byEmployee = <String, List<AttendanceRecord>>{};
    for (final r in records) {
      (byEmployee[r.employeeId] ??= []).add(r);
    }
    return employees.map((e) {
      final rs = byEmployee[e.id] ?? const <AttendanceRecord>[];
      var units = 0.0;
      var unitsHoliday = 0.0;
      var present = 0;
      var absent = 0;
      var half = 0;
      var custom = 0;
      var otNormal = 0;
      var otWeekend = 0;
      var otHoliday = 0;
      for (final r in rs) {
        units += r.workUnits;
        if (holidayDates.contains(r.workDate)) unitsHoliday += r.workUnits;
        if (r.status == AttendanceStatus.present) present++;
        if (r.status == AttendanceStatus.absent) absent++;
        if (r.status == AttendanceStatus.half) half++;
        if (r.status == AttendanceStatus.custom) custom++;
        switch (r.otDayKind(holidayDates)) {
          case OtDayKind.normal:
            otNormal += r.overtimeMinutes;
          case OtDayKind.weekend:
            otWeekend += r.overtimeMinutes;
          case OtDayKind.holiday:
            otHoliday += r.overtimeMinutes;
        }
      }
      return MonthlySummary(
        employeeId: e.id,
        totalWorkUnits: units,
        presentDays: present,
        absentDays: absent,
        halfDays: half,
        customDays: custom,
        overtimeMinutesNormal: otNormal,
        overtimeMinutesWeekend: otWeekend,
        overtimeMinutesHoliday: otHoliday,
        dailySalary: e.dailySalary,
        otRate: e.otRate,
        otRateWeekend: e.otRateWeekend,
        otRateHoliday: e.otRateHoliday,
        workUnitsHoliday: unitsHoliday,
        holidayPayMultiplier: holidayPayMultiplier,
      );
    }).toList();
  }

  /// Tổng quỹ lương của một nhóm bản ghi công.
  ///
  /// Dùng cho biểu đồ quỹ lương theo quý / năm: mỗi kỳ gọi một lần rồi cộng
  /// dồn. Tự gộp cả người đã nghỉ mà còn công trong nhóm đó (luật §0.7).
  static double totalPayrollOf(
    List<Employee> all,
    List<AttendanceRecord> records, {
    Set<String> holidayDates = const {},
    double holidayPayMultiplier = 1,
  }) {
    var total = 0.0;
    for (final s in summarize(
      employeesForExport(all, records),
      records,
      holidayDates: holidayDates,
      holidayPayMultiplier: holidayPayMultiplier,
    )) {
      total += s.totalPay;
    }
    return total;
  }

  // ------------------------------------------------------------- Thiết lập

  Stream<AppSettings> watchSettings() =>
      _settings.snapshots().map((s) => AppSettings.fromMap(s.data()));

  Future<AppSettings> getSettings() async {
    final s = await _settings.get();
    return AppSettings.fromMap(s.data());
  }

  Future<void> saveSettings(AppSettings s) =>
      _settings.set(s.toMap(), SetOptions(merge: true));
}

/// So sánh tên tiếng Việt có dấu để sắp xếp danh sách cho tự nhiên.
int _vnCompare(String a, String b) {
  final r = _deaccent(a).compareTo(_deaccent(b));
  return r != 0 ? r : a.compareTo(b);
}

const _accents = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
    'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _plain = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
    'ooooooooooooooooouuuuuuuuuuuyyyyyd';

String _deaccent(String input) {
  final s = input.toLowerCase();
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final i = _accents.indexOf(ch);
    buf.write(i >= 0 ? _plain[i] : ch);
  }
  return buf.toString();
}
