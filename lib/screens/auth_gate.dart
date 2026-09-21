import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'home_shell.dart';
import 'intro_screen.dart';
import 'onboarding_screen.dart';

/// Điều hướng gốc sau màn splash: chưa đăng nhập, chưa xem giới thiệu app
/// -> OnboardingScreen -> IntroScreen -> đăng nhập. Đã đăng nhập -> vào thẳng
/// 3 tab.
///
/// Đây cũng là **chỗ duy nhất** gán `DataService.instance.companyId`. Quy ước:
/// `companyId` = `uid` của chủ cơ sở (xem `firestore.rules`), nên chỉ cần biết
/// ai đang đăng nhập là biết đường dẫn dữ liệu, không phải đọc thêm document
/// nào - mở app offline vẫn vào được ngay.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Gán `companyId` ngay trong luồng auth, tức là **trước** khi màn nào kịp
  /// đọc Firestore. Đăng xuất thì xoá về `null` để phiên sau không còn trỏ
  /// vào cơ sở cũ.
  ///
  /// Dựng một lần trong `State` chứ không dựng trong `build`: `map` tạo stream
  /// mới mỗi lần gọi, để trong `build` là mỗi lần vẽ lại một lần đăng ký nghe.
  late final Stream<User?> _authState = AuthService.instance.authState.map((
    user,
  ) {
    DataService.instance.companyId = user?.uid;
    return user;
  });

  /// Đọc một lần cho cả phiên app.
  late final Future<bool> _seenOnboarding = hasSeenOnboarding();

  /// Đánh dấu đã xong Onboarding **trong phiên này**, không chờ đọc lại
  /// `SharedPreferences`. `OnboardingScreen` chỉ gọi [setState] qua callback
  /// này, **không** tự điều hướng - xem lý do ở comment trong `build()`.
  bool _skipOnboarding = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.data == null) {
          if (_skipOnboarding) return const IntroScreen();
          return FutureBuilder<bool>(
            future: _seenOnboarding,
            builder: (context, seenSnap) {
              if (!seenSnap.hasData) {
                return const Scaffold(backgroundColor: Colors.transparent);
              }
              if (seenSnap.data!) return const IntroScreen();
              // `OnboardingScreen` không được tự `Navigator.push`/
              // `pushReplacement` sang `IntroScreen` - route gốc của
              // Navigator chính là route của `AuthGate` này (StreamBuilder
              // theo dõi đăng nhập). Thay route đó bằng một `IntroScreen`
              // tĩnh thì "route đầu tiên" mà `LoginScreen.popUntil((r) =>
              // r.isFirst)` quay về không còn là `AuthGate` nữa - đăng nhập
              // xong `authState` đổi nhưng chẳng còn ai lắng nghe để tự
              // chuyển sang `HomeShell`, kẹt luôn ở `IntroScreen`. Onboarding
              // xong chỉ cần gọi lại `setState` ở đây, vẫn trong đúng route
              // của `AuthGate`.
              return OnboardingScreen(
                onFinished: () => setState(() => _skipOnboarding = true),
              );
            },
          );
        }
        return const HomeShell();
      },
    );
  }
}
