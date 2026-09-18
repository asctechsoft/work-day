import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Đọc giá gói "Nâng cấp gói" (`IapScreen`) từ Firebase Remote Config, để đổi
/// giá không cần build lại app - chỉ cần sửa trên Console rồi Publish, app tự
/// lấy giá mới ở lần mở kế tiếp (chờ tối đa [_RemoteConfigDefaults] hoặc khi
/// hết `minimumFetchInterval`).
///
/// `init()` được gọi một lần ở `SplashScreen._bootstrap`, sau
/// `Firebase.initializeApp` - các getter bên dưới đọc đồng bộ từ bộ nhớ đệm
/// nên `IapScreen` không cần `FutureBuilder`, giống cách `AuthService` đang
/// dùng cho các singleton khác trong app.
class RemoteConfigService {
  RemoteConfigService._();
  static final instance = RemoteConfigService._();

  static const _keyIapEnabled = 'iap_enabled';
  static const _keyMonthlyPrice = 'iap_price_monthly';
  static const _keyYearlyOriginalPrice = 'iap_price_yearly_original';
  static const _keyYearlyDiscountPercent = 'iap_yearly_discount_percent';

  FirebaseRemoteConfig get _rc => FirebaseRemoteConfig.instance;

  Future<void> init() async {
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    // Giá mặc định - dùng khi chưa fetch được lần nào (mất mạng lần đầu mở
    // app). Luôn khớp giá đang công bố, đừng để lệch với Console.
    //
    // `_keyIapEnabled` mặc định `false` - ẩn màn Nâng cấp gói, bấm "Danh sách
    // nhân viên" vào thẳng danh sách như bản một-tài-khoản. Bật lại bằng
    // cách đổi giá trị `iap_enabled` trên Console (không cần build lại app).
    await _rc.setDefaults({
      _keyIapEnabled: false,
      _keyMonthlyPrice: 50000,
      _keyYearlyOriginalPrice: 600000,
      _keyYearlyDiscountPercent: 24,
    });
    // Mất mạng thì giữ nguyên giá mặc định/giá đã fetch lần trước - không để
    // lỗi này chặn cả app khởi động.
    try {
      await _rc.fetchAndActivate();
    } catch (_) {}
  }

  bool get iapEnabled => _rc.getBool(_keyIapEnabled);

  int get monthlyPrice => _rc.getInt(_keyMonthlyPrice);
  int get yearlyOriginalPrice => _rc.getInt(_keyYearlyOriginalPrice);
  int get yearlyDiscountPercent => _rc.getInt(_keyYearlyDiscountPercent);

  /// Giá gói năm sau khi trừ phần trăm giảm giá, làm tròn tới nghìn gần nhất.
  int get yearlyFinalPrice {
    final raw = yearlyOriginalPrice * (100 - yearlyDiscountPercent) / 100;
    return (raw / 1000).round() * 1000;
  }
}
