import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../widgets/common.dart';

/// Khoá đánh dấu đã xem giới thiệu ứng dụng trên máy này.
///
/// Không ghép `uid` như `welcome_seen_<uid>` của `welcome_dialog.dart`: màn
/// này hiện **trước khi đăng nhập**, giới thiệu chung về app chứ không phải
/// hướng dẫn riêng cho một tài khoản, nên chỉ cần một khoá chung cho cả máy.
const _seenKey = 'onboarding_seen';

/// Gọi từ `AuthGate` để biết hiện [OnboardingScreen] hay [IntroScreen] khi
/// chưa đăng nhập.
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_seenKey) ?? false;
}

/// Vị trí một thẻ nổi quanh ảnh minh hoạ.
enum _ChipSlot { topLeft, topRight, bottomLeft, bottomRight }

const _slotAlignment = {
  _ChipSlot.topLeft: Alignment(-1, -0.5),
  _ChipSlot.topRight: Alignment(1, -0.62),
  _ChipSlot.bottomLeft: Alignment(-1, 0.55),
  _ChipSlot.bottomRight: Alignment(1, 0.65),
};

class _Chip {
  final _ChipSlot slot;
  final IconData icon;
  final Color color;
  final Color background;
  final String label;

  const _Chip({
    required this.slot,
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
  });
}

class _OnboardingPage {
  final String asset;
  final String badge;
  final String title;
  final String subtitle;
  final String tagline;
  final List<_Chip> chips;

  const _OnboardingPage({
    required this.asset,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.tagline,
    required this.chips,
  });
}

const _pages = [
  _OnboardingPage(
    asset: 'assets/images/on_boarding_1.png',
    badge: 'Quản lý thời gian thông minh',
    title: 'WorkDay',
    subtitle: 'Chấm công & tính lương',
    tagline: 'Đơn giản  •  Nhanh chóng  •  Dễ dùng',
    chips: [
      _Chip(
        slot: _ChipSlot.topLeft,
        icon: Icons.event_available_rounded,
        color: AppColors.present,
        background: AppColors.presentSoft,
        label: 'Chấm công\nnhanh chóng',
      ),
      _Chip(
        slot: _ChipSlot.topRight,
        icon: Icons.payments_rounded,
        color: AppColors.overtime,
        background: AppColors.overtimeSoft,
        label: 'Tính lương\nchính xác',
      ),
      _Chip(
        slot: _ChipSlot.bottomLeft,
        icon: Icons.bar_chart_rounded,
        color: AppColors.info,
        background: AppColors.infoSoft,
        label: 'Theo dõi\nhiệu suất',
      ),
      _Chip(
        slot: _ChipSlot.bottomRight,
        icon: Icons.verified_user_rounded,
        color: AppColors.custom,
        background: AppColors.customSoft,
        label: 'An toàn\nbảo mật',
      ),
    ],
  ),
  _OnboardingPage(
    asset: 'assets/images/on_boarding_2.png',
    badge: 'Lên kế hoạch dễ dàng',
    title: 'Quản lý công việc',
    subtitle: 'Sắp xếp công việc khoa học, tập trung hơn mỗi ngày.',
    tagline: 'Chủ động  •  Hiệu quả  •  Đạt mục tiêu',
    chips: [
      _Chip(
        slot: _ChipSlot.topLeft,
        icon: Icons.event_note_rounded,
        color: AppColors.present,
        background: AppColors.presentSoft,
        label: 'Lịch làm việc\ntrực quan',
      ),
      _Chip(
        slot: _ChipSlot.topRight,
        icon: Icons.notifications_active_rounded,
        color: AppColors.overtime,
        background: AppColors.overtimeSoft,
        label: 'Nhắc nhở\nthông minh',
      ),
      _Chip(
        slot: _ChipSlot.bottomLeft,
        icon: Icons.checklist_rounded,
        color: AppColors.info,
        background: AppColors.infoSoft,
        label: 'Tạo & theo dõi\ncông việc',
      ),
    ],
  ),
  _OnboardingPage(
    asset: 'assets/images/on_boarding_3.png',
    badge: 'Tối ưu hiệu suất mỗi ngày',
    title: 'Đạt mục tiêu',
    subtitle: 'Kiên trì mỗi ngày, thành công trong tầm tay.',
    tagline: 'Theo dõi tiến độ  •  Tăng hiệu suất  •  Cân bằng',
    chips: [
      _Chip(
        slot: _ChipSlot.topLeft,
        icon: Icons.emoji_events_rounded,
        color: AppColors.present,
        background: AppColors.presentSoft,
        label: 'Hoàn thành\nmục tiêu',
      ),
      _Chip(
        slot: _ChipSlot.topRight,
        icon: Icons.eco_rounded,
        color: AppColors.custom,
        background: AppColors.customSoft,
        label: 'Thói quen\ntốt hơn',
      ),
      _Chip(
        slot: _ChipSlot.bottomLeft,
        icon: Icons.star_rounded,
        color: AppColors.overtime,
        background: AppColors.overtimeSoft,
        label: 'Hiệu suất\ntăng lên',
      ),
      _Chip(
        slot: _ChipSlot.bottomRight,
        icon: Icons.favorite_rounded,
        color: AppColors.absent,
        background: AppColors.absentSoft,
        label: 'Cân bằng\ncuộc sống',
      ),
    ],
  ),
];

/// Giới thiệu app qua 3 màn trượt ngang, hiện **đúng một lần** trước
/// `IntroScreen` (khoá `onboarding_seen` ở `SharedPreferences`).
class OnboardingScreen extends StatefulWidget {
  /// Gọi khi xong (bấm "Bắt đầu ngay" hoặc "Bỏ qua") - **không** tự điều
  /// hướng ở đây. `AuthGate` là nơi quyết định hiện gì tiếp theo (xem comment
  /// ở `auth_gate.dart`), `OnboardingScreen` chỉ báo lại là đã xong.
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _pages.length - 1;

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    if (!mounted) return;
    widget.onFinished();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Trong suốt để dùng nền gradient chung của app (AppGradients.page).
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Trang cuối không có gì để "bỏ qua" nữa - đã có nút
                  // "Bắt đầu ngay" ngay dưới.
                  if (!_isLast)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        child: const Text('Bỏ qua'),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) =>
                    _OnboardingPageView(page: _pages[i]),
              ),
            ),
            _Dots(count: _pages.length, index: _page),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              // Chỉ một nút hành động chính - bỏ nút tròn lùi trang riêng vì
              // đứng cạnh vòng tròn mũi tên của GradientButton nhìn rối, hai
              // nút mũi tên cùng lúc (người dùng phản hồi 21/09/2026). Lùi
              // trang thì vuốt `PageView` như bình thường.
              child: GradientButton(
                label: _isLast ? 'Bắt đầu ngay' : 'Tiếp theo',
                icon: _isLast
                    ? Icons.play_arrow_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nội dung một trang: nhãn nhỏ + tiêu đề + phụ đề + tagline ở trên, ảnh
/// minh hoạ cùng các thẻ nổi quanh nó chiếm phần còn lại - đúng bố cục ảnh
/// mẫu (badge -> tiêu đề -> ảnh có thẻ nổi 4 góc -> dots -> nút).
class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 4),
          _Badge(text: page.badge),
          const SizedBox(height: 16),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16.5,
              color: AppColors.textBody,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            page.tagline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: SizedBox.expand(
                    child: Image.asset(page.asset, fit: BoxFit.contain),
                  ),
                ),
                for (final chip in page.chips)
                  Align(
                    alignment: _slotAlignment[chip.slot]!,
                    child: _FloatingChip(chip: chip),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn nhỏ bo tròn phía trên tiêu đề ("Quản lý thời gian thông minh"...).
class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// Thẻ nhỏ nổi quanh ảnh minh hoạ, mỗi thẻ một màu lấy từ `AppColors` (đúng
/// quy ước §5 CLAUDE.md - không tự pha màu mới).
class _FloatingChip extends StatelessWidget {
  final _Chip chip;
  const _FloatingChip({required this.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: chip.background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, color: chip.color, size: 20),
          const SizedBox(height: 6),
          Text(
            chip.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
