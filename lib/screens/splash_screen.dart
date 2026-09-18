import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/firebase_env.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/remote_config_service.dart';
import 'auth_gate.dart';

/// Màn chào lúc mở app.
///
/// Trước đây `main()` chờ `Firebase.initializeApp()` **rồi mới** `runApp`, nên
/// người dùng phải nhìn màn trắng của hệ thống mấy giây - phản hồi thật:
/// *"mới đầu bật lên hiện màn này lâu vậy"*. Nay `runApp` chạy ngay, màn này
/// hiện gần như tức thì và phần khởi tạo Firebase chạy trong lúc nó đang hiện.
///
/// Vì vậy **đừng đưa việc nặng nào ngược lên `main()`**: mọi thứ cần chờ thì
/// làm ở [_bootstrap].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Thời gian tối thiểu màn này hiện, do người dùng chọn (07/09/2026).
  ///
  /// Chờ song song với việc khởi tạo nên tổng thời gian mở app **không** phải
  /// 5 giây cộng thêm - chỉ là màn chào không tắt trước mốc này.
  static const _minShow = Duration(seconds: 5);

  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      // Chờ song song: việc khởi tạo và khoảng thời gian tối thiểu.
      await Future.wait([_bootstrap(), Future.delayed(_minShow)]);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, _, _) => const AuthGate(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _bootstrap() async {
    // `firebaseOptions` chọn project theo flavor (dev-asc / tick-go) — xem
    // core/firebase_env.dart. Đừng gọi thẳng DefaultFirebaseOptions ở đây.
    await Firebase.initializeApp(options: firebaseOptions);

    // Cho phép chấm công khi mất mạng, dữ liệu tự đồng bộ lại sau.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Nếu lần trước không chọn "Lưu đăng nhập" thì bắt đăng nhập lại.
    await AuthService.instance.applyRememberPolicyOnStart();

    // Giá gói ở IapScreen - fetch một lần ở đây để màn đó đọc đồng bộ, không
    // cần chờ riêng (xem RemoteConfigService).
    await RemoteConfigService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Trong suốt để dùng nền gradient chung của app (AppGradients.page).
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Mấy vòng tròn mờ cho nền đỡ phẳng.
          const Positioned(top: -60, right: -40, child: _Blob(size: 200)),
          const Positioned(top: 120, left: -50, child: _Blob(size: 120)),
          const Positioned(bottom: -40, left: 20, child: _Blob(size: 220)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Image.asset(
                    'assets/images/img_splash.png',
                    width: 190,
                    height: 190,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'WorkDay',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chấm công & tính lương',
                    style: TextStyle(fontSize: 15.5, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 14),
                  const _Tagline(),
                  const Spacer(flex: 3),
                  if (_error == null)
                    const _LoadingDots()
                  else
                    _ErrorBox(error: _error!, onRetry: _start),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Đơn giản • Nhanh chóng • Dễ dùng" - dấu chấm giữa các từ tô màu xanh cho
/// đỡ đơn điệu.
class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    const words = ['Đơn giản', 'Nhanh chóng', 'Dễ dùng'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < words.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7),
              child: Icon(Icons.circle, size: 5, color: AppColors.primary),
            ),
          Text(
            words[i],
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Ba chấm sáng dần lần lượt - dấu hiệu app đang khởi động.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _dot(i),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(int index) {
    // Mỗi chấm trễ một nhịp so với chấm trước, tạo cảm giác chạy từ trái sang.
    final t = (_c.value - index * 0.22) % 1.0;
    // Sáng lên nhanh rồi mờ dần: chỉ nửa đầu chu kỳ mới sáng.
    final glow = t < 0.5 ? (1 - (t * 4 - 1).abs()).clamp(0.0, 1.0) : 0.0;
    final size = 8.0 + 3 * glow;

    return SizedBox(
      width: 11,
      height: 11,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.presentMedium,
              AppColors.primary,
              glow,
            ),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Khởi tạo Firebase lỗi (thường là mất mạng lần đầu chạy) - cho thử lại chứ
/// đừng để người dùng đứng nhìn ba chấm chạy mãi.
class _ErrorBox extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Không khởi động được',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.absent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$error',
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 160,
          child: ElevatedButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ),
      ],
    );
  }
}

/// Vòng tròn xanh rất mờ dùng trang trí nền.
class _Blob extends StatelessWidget {
  final double size;

  const _Blob({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.present.withValues(alpha: 0.06),
      ),
    );
  }
}
