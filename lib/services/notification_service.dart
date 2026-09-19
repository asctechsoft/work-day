import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/firebase_env.dart';
import '../core/formatters.dart';
import '../models/app_settings.dart';

const _kTaskName = 'workday_attendance_reminder';
const _kPrefEnabled = 'remind_enabled';
const _kPrefHour = 'remind_hour';
const _kPrefMinute = 'remind_minute';

/// Nhắc chấm công cuối ngày nếu còn người chưa được chấm (yêu cầu người dùng
/// 18/09/2026, mặc định 18h - không nằm trong đặc tả gốc nhưng không thuộc
/// danh sách ngoài phạm vi ở §0.9).
///
/// App không có server nên việc kiểm tra "đã chấm đủ chưa" phải tự chạy trên
/// máy, kể cả khi app đang đóng: dùng `workmanager` (bọc WorkManager của
/// Android) để dựng lại một isolate Dart vào đúng giờ đã hẹn, tự đọc Firestore
/// rồi quyết định có hiện thông báo hay không, xong tự hẹn lại cho ngày mai.
///
/// **Không chính xác tuyệt đối theo giây**: WorkManager không phải báo thức
/// hẹn giờ chính xác (AlarmManager exact) - Android có thể hoãn vài phút tới
/// vài chục phút nếu máy đang ở chế độ Doze sâu. Chấp nhận được vì đây chỉ là
/// nhắc nhở bằng chữ (§0 - "hiện text thôi"), không phải mốc khoá sổ.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Khởi tạo plugin thông báo + WorkManager. Gọi một lần ở `SplashScreen`,
  /// cùng chỗ với `Firebase.initializeApp` (xem CLAUDE.md §5.4) - chạy được cả
  /// khi chưa đăng nhập, không đụng Firestore.
  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: _androidInit),
    );
    await Workmanager().initialize(_callbackDispatcher);
    _ready = true;
  }

  /// Áp thiết lập nhắc chấm công hiện tại: bật thì hẹn giờ, tắt thì huỷ.
  ///
  /// Gọi mỗi khi `AppSettings` đổi (`HomeShell` nghe `watchSettings`) nên bật
  /// / tắt hoặc đổi giờ ở màn Cài đặt tự có hiệu lực, không cần nút riêng.
  Future<void> applySettings(AppSettings s) async {
    await _cacheLocally(s);
    if (!s.remindEnabled) {
      await Workmanager().cancelByUniqueName(_kTaskName);
      return;
    }
    // Android 13+ cần xin quyền hiện thông báo - xin ngay khi bật, không chờ
    // tới giờ mới hỏi vì lúc đó app thường không mở để hỏi được.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _schedule(s.remindHour, s.remindMinute);
  }

  /// Huỷ hẳn tác vụ nhắc - gọi khi đăng xuất. Không huỷ thì tài khoản đăng
  /// nhập sau trên cùng máy vẫn bị nhắc theo giờ của tài khoản trước, và cứ
  /// đến giờ hẹn lại kiểm tra nhầm sang cơ sở khác.
  Future<void> cancel() => Workmanager().cancelByUniqueName(_kTaskName);

  Future<void> _schedule(int hour, int minute) => Workmanager()
      .registerOneOffTask(
        _kTaskName,
        _kTaskName,
        initialDelay: _delayUntilNext(hour, minute),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
}

const _androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

/// Ghi thiết lập nhắc vào `SharedPreferences` - isolate nền của WorkManager
/// không có sẵn `DataService`/`companyId` của phiên đang chạy, nên đọc từ đây
/// thay vì phải mở lại kết nối Firestore chỉ để lấy 3 giá trị bật/giờ/phút.
Future<void> _cacheLocally(AppSettings s) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kPrefEnabled, s.remindEnabled);
  await p.setInt(_kPrefHour, s.remindHour);
  await p.setInt(_kPrefMinute, s.remindMinute);
}

Duration _delayUntilNext(int hour, int minute) {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next.difference(now);
}

/// Chạy trong isolate nền riêng của WorkManager - không chia sẻ state với
/// app đang mở (nếu có), phải tự khởi tạo Firebase từ đầu. Đánh dấu
/// `vm:entry-point` để trình biên dịch không cắt mất hàm này khi build
/// release (isolate nền gọi vào bằng tên, không qua lời gọi Dart bình thường
/// nên compiler tree-shaking không thấy được).
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await _runDailyCheck();
    } catch (_) {
      // Mất mạng / lỗi đọc dữ liệu: bỏ qua, vẫn hẹn lại ngày mai bên dưới để
      // không "rơi" mất lần nhắc của những ngày sau.
    }
    await _rescheduleFromCache();
    return true;
  });
}

Future<void> _runDailyCheck() async {
  final p = await SharedPreferences.getInstance();
  if (!(p.getBool(_kPrefEnabled) ?? true)) return;

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: firebaseOptions);
  }

  // Phiên đăng nhập của Firebase Auth được lưu sẵn trên máy nên vẫn đọc được
  // `currentUser` ở đây dù isolate này chưa từng tự đăng nhập.
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return; // Đã đăng xuất, không có cơ sở nào để kiểm tra.

  final root = FirebaseFirestore.instance.collection('companies').doc(uid);
  final employees = await root
      .collection('employees')
      .where('active', isEqualTo: true)
      .count()
      .get();
  final total = employees.count ?? 0;
  if (total == 0) return;

  final todayKey = Fmt.dateKey(DateTime.now());
  final marked = await root
      .collection('attendance')
      .where('workDate', isEqualTo: todayKey)
      .count()
      .get();
  final done = marked.count ?? 0;
  if (done >= total) return; // Đã chấm đủ cả danh sách, không cần nhắc.

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(android: _androidInit),
  );
  await plugin.show(
    id: 9001,
    title: 'Nhắc chấm công',
    body: 'Còn ${total - done}/$total người chưa được chấm công hôm nay.',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'attendance_reminder',
        'Nhắc chấm công cuối ngày',
        channelDescription:
            'Báo khi cuối ngày còn người trong danh sách chưa được chấm công',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

Future<void> _rescheduleFromCache() async {
  final p = await SharedPreferences.getInstance();
  if (!(p.getBool(_kPrefEnabled) ?? true)) return;
  final hour = p.getInt(_kPrefHour) ?? 18;
  final minute = p.getInt(_kPrefMinute) ?? 0;
  await Workmanager().registerOneOffTask(
    _kTaskName,
    _kTaskName,
    initialDelay: _delayUntilNext(hour, minute),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
