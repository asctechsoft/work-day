import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'home_shell.dart';
import 'intro_screen.dart';

/// Điều hướng gốc sau màn splash: chưa đăng nhập -> màn mở app -> đăng nhập.
/// Đã đăng nhập -> vào thẳng 3 tab.
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
          return const IntroScreen();
        }
        return const HomeShell();
      },
    );
  }
}
