// Chọn Firebase project theo flavor đang build.
//
// `appFlavor` do chính Flutter tool ghi vào bản build từ cờ `--flavor`, nên nó
// KHÔNG THỂ lệch với google-services.json mà Gradle đã nhúng: cùng một nguồn
// sự thật cho tầng native và tầng Dart. Đừng thay bằng `--dart-define` tự đặt —
// quên truyền một lần là bản dev nói chuyện với dữ liệu thật.
//
//   --flavor dev     → dev-asc (Firestore/Auth để test, xoá thoải mái)
//   --flavor product → tick-go (DỮ LIỆU THẬT CỦA CƠ SỞ)
//
// Chạy không có flavor (`appFlavor == null`) thì rơi về prod — vì vậy mọi lệnh
// `flutter run` / `flutter build apk` cho Android đều PHẢI truyền `--flavor`.
//
// MỌI chỗ gọi `Firebase.initializeApp` phải dùng `firebaseOptions` ở đây; hiện
// chỉ có một chỗ là `SplashScreen._bootstrap`. Thêm FirebaseApp phụ nào thì
// cũng truyền options này, sót một chỗ là bản dev ghi thẳng vào project thật.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/services.dart' show appFlavor;

import '../firebase_options.dart';
import '../firebase_options_dev.dart';

/// Tên flavor môi trường test, khớp `productFlavors` trong build.gradle.kts.
const String kDevFlavor = 'dev';

/// Đang chạy bản dev (project dev-asc) hay không.
bool get isDevEnv => appFlavor == kDevFlavor;

/// Nhãn ngắn để hiện trên UI/log khi cần phân biệt môi trường.
String get envLabel => isDevEnv ? 'DEV' : 'PROD';

/// Cấu hình Firebase của môi trường đang build.
FirebaseOptions get firebaseOptions => isDevEnv
    ? DevFirebaseOptions.currentPlatform
    : DefaultFirebaseOptions.currentPlatform;
