import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/home_shell.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Cho phép chấm công khi mất mạng, dữ liệu tự đồng bộ lại sau.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Nếu lần trước không chọn "Lưu đăng nhập" thì bắt đăng nhập lại.
  await AuthService.instance.applyRememberPolicyOnStart();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
          child: child!,
        );
      },
      home: const _AuthGate(),
    );
  }
}

/// Điều hướng gốc: chưa đăng nhập -> màn mở app -> đăng nhập.
/// Đã đăng nhập -> vào thẳng 3 tab.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.surface,
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

/// Điều hướng tới màn đăng nhập từ màn mở app.
void goToLogin(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
}
