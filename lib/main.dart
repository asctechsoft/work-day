import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Chạy app ngay, KHÔNG chờ Firebase ở đây: chờ ở đây thì người dùng nhìn
  // màn trắng của hệ thống mấy giây. Việc khởi tạo nằm trong [SplashScreen],
  // chạy trong lúc màn chào đang hiện.
  runApp(const WorkDayApp());
}

class WorkDayApp extends StatelessWidget {
  const WorkDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkDay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      builder: (context, child) {
        // Khoá cỡ chữ hệ thống trong khoảng an toàn để bảng chấm công
        // không bị vỡ trên máy đặt cỡ chữ rất lớn.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.25,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          // Nền gradient của cả app dựng đúng một lần ở đây, còn
          // `scaffoldBackgroundColor` để trong suốt (xem `AppGradients.page`).
          // Nhờ vậy mọi màn - kể cả màn được push - có cùng một nền, không
          // phải bọc Container ở từng màn.
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.page),
            child: child!,
          ),
        );
      },
      // Vào app là thấy màn chào ngay; nó tự chuyển sang `AuthGate` khi khởi
      // tạo xong (xem `screens/splash_screen.dart`).
      home: const SplashScreen(),
    );
  }
}

/// Điều hướng tới màn đăng nhập từ màn mở app.
void goToLogin(BuildContext context) {
  pushScreen(context, const LoginScreen());
}
