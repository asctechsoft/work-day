import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'login_screen.dart';

/// Màn hình mở app: logo + tên + nút "Bắt đầu".
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const AppLogo(size: 132),
              const SizedBox(height: 28),
              const Text(
                'WorkDay',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Đơn giản • Nhanh chóng • Hiệu quả',
                style: TextStyle(fontSize: 15, color: AppColors.textMuted),
              ),
              const Spacer(flex: 4),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Bắt đầu'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quản lý công việc mỗi ngày',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo app bo góc mềm, dùng lại ở màn mở app và màn đăng nhập.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: AppColors.primarySoft,
          alignment: Alignment.center,
          child: Icon(
            Icons.event_available_rounded,
            size: size * 0.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
