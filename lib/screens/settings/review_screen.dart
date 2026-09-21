import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';

/// Phiên bản app ghi kèm mỗi lượt đánh giá, để biết góp ý nói về bản nào.
const _appVersion = '1.0.0';

/// App **chưa lên Google Play** (đang giao bằng file APK) nên bấm "Đánh giá
/// ngay" chỉ ghi nhận lời khen chứ chưa mở được trang Store thật. Lên store
/// rồi thì đổi cờ này thành `true`, nút sẽ mở thẳng `_playStoreUrl`.
const kOnPlayStore = false;

/// Trang app trên Play Store - đổi theo applicationId của bản product.
const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.campany.tickgo';

/// Hiện bảng "đánh giá app" trượt lên từ đáy màn - không điều hướng sang màn
/// mới, vì đây là một lời mời ngắn chứ không phải một biểu mẫu cần trang
/// riêng. Đổi từ dialog nổi giữa màn sang bottom sheet theo yêu cầu người
/// dùng 21/09/2026.
///
/// Bấm **"Đánh giá ngay"**: sheet đóng lại **rồi mới** mở Play Store, dùng
/// đúng `context` của màn gọi hàm này (màn Cài đặt, hoặc sau dialog chào
/// mừng) - context của sheet vừa đóng đã mất, không dùng lại được để launch
/// URL hay hiện toast.
Future<void> showReviewDialog(BuildContext context) async {
  final rated = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ReviewSheet(),
  );
  if (rated != true || !context.mounted) return;

  if (kOnPlayStore) {
    final ok = await launchUrl(
      Uri.parse(_playStoreUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      showToast(context, 'Không mở được Play Store', error: true);
    }
  } else {
    showToast(context, 'Cảm ơn bạn đã đánh giá! App chưa có trên Play Store.');
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet();

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  // Mở dialog là 5 sao đã sáng sẵn (mời đánh giá cao) - `_litStars` chỉ để
  // chạy hiệu ứng sáng lần lượt, không đổi giá trị đánh giá được gửi đi.
  int _stars = 5;
  int _litStars = 0;
  int _animationRun = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateStars(5));
  }

  @override
  void dispose() {
    _animationRun++;
    super.dispose();
  }

  /// Sáng dần từng sao một - chạy khi mở dialog, và chạy lại nếu người dùng
  /// chạm chọn một số sao khác.
  Future<void> _animateStars(int stars) async {
    final run = ++_animationRun;
    if (!mounted) return;
    setState(() {
      _stars = stars;
      _litStars = 0;
    });

    await Future<void>.delayed(const Duration(milliseconds: 80));
    for (var i = 1; i <= stars; i++) {
      if (!mounted || run != _animationRun) return;
      setState(() => _litStars = i);
      await Future<void>.delayed(const Duration(milliseconds: 110));
    }
  }

  /// Ghi nhanh số sao rồi đóng dialog ngay - đây là hành động rời màn, lỗi
  /// ghi (mất mạng...) không được cản người dùng qua Play Store.
  void _rateNow() {
    DataService.instance
        .saveReview(stars: _stars, comment: '', appVersion: _appVersion)
        .catchError((_) {});
    Navigator.of(context).pop(true);
  }

  void _later() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    // `SafeArea` bắt buộc cho mọi `showModalBottomSheet` (§5.2.3 CLAUDE.md) -
    // bảng chọn của Material không tự tránh thanh điều hướng Android.
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/img_rate.png',
                  height: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                    children: [
                      const TextSpan(text: 'Bạn thích '),
                      const TextSpan(
                        text: 'ứng dụng này',
                        style: TextStyle(color: AppColors.primaryDark),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nếu thấy hữu ích, hãy dành 1 phút để đánh giá 5 sao '
                  'giúp chúng tôi nhé!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (var i = 1; i <= 5; i++) _starButton(i)],
                ),
                const SizedBox(height: 22),
                GradientButton(
                  label: 'Đánh giá ngay',
                  icon: Icons.star_rounded,
                  onPressed: _rateNow,
                ),
                const SizedBox(height: 10),
                _LaterButton(onTap: _later),
                const SizedBox(height: 16),
                const Text(
                  'Cảm ơn bạn đã đồng hành cùng chúng tôi! 💚',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _starButton(int star) {
    final active = star <= _litStars;
    return Semantics(
      button: true,
      selected: star == _stars,
      label: '$star sao',
      child: IconButton(
        tooltip: '$star sao',
        onPressed: () => _animateStars(star),
        iconSize: 40,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        constraints: const BoxConstraints(minWidth: 46, minHeight: 48),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.elasticOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            active ? Icons.star_rounded : Icons.star_border_rounded,
            key: ValueKey(active),
            color: active ? AppColors.overtime : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Nút phụ "Để sau" - nền xanh nhạt, không tranh chú ý với [GradientButton].
class _LaterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LaterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const SizedBox(
          height: 50,
          child: Center(
            child: Text(
              'Để sau',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
