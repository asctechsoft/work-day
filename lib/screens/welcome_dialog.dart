import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

/// Khoá đánh dấu đã chào tài khoản này trên máy này.
///
/// Ghép thêm `uid` chứ không dùng một khoá chung: máy dùng chung cho hai cơ sở
/// thì cơ sở thứ hai vẫn phải được chào một lần.
String _seenKey(String uid) => 'welcome_seen_$uid';

/// Hiện dialog chào mừng **đúng một lần** cho mỗi tài khoản trên mỗi máy.
///
/// Cố ý không hiện mỗi lần mở app: mục tiêu của tab Chấm công là xong 10-20
/// người trong 15-30 giây (§5.2), chèn một cú bấm vào mỗi buổi sáng là đi
/// ngược lại chính mục tiêu đó.
///
/// Gọi từ `HomeShell` sau khung hình đầu (`addPostFrameCallback`) - gọi trong
/// `initState` thì chưa có `Overlay` để đẩy dialog lên.
Future<void> showWelcomeIfFirstTime(BuildContext context) async {
  final uid = AuthService.instance.currentUser?.uid;
  if (uid == null) return;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_seenKey(uid)) ?? false) return;
  if (!context.mounted) return;

  // Phải đợi stack route sạch, nếu không dialog chỉ loé lên rồi tắt (xem
  // [_waitUntilHomeIsTop]).
  if (!await _waitUntilHomeIsTop(context)) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _WelcomeDialog(),
  );

  // Ghi sau khi đã hiện: đóng app giữa lúc dialog đang mở thì lần sau vẫn được
  // chào, thà chào hai lần còn hơn người dùng chưa kịp đọc đã mất luôn.
  await prefs.setBool(_seenKey(uid), true);
}

/// Đợi tới khi màn Home là route **trên cùng**, trả về `false` nếu chờ quá lâu.
///
/// Vì sao cần: sau khi đăng nhập / tạo cơ sở, `LoginScreen` và `RegisterScreen`
/// gọi `popUntil((r) => r.isFirst)` để dọn stack. Mà `HomeShell` lại mount
/// **trước** lệnh dọn đó — `AuthGate` đổi nội dung route đầu ngay khi
/// `authState` đổi, còn lệnh `popUntil` chỉ chạy khi hàm `signIn` await xong.
/// Dialog đẩy lên trong khoảng đó nằm trên route đầu nên bị chính `popUntil`
/// kia pop mất: người dùng thấy nó hiện rồi tắt ngay, chưa kịp bấm gì.
///
/// Chờ quá lâu (10s) thì thôi không hiện và **không ghi khoá** — lần mở app
/// sau sẽ chào lại.
Future<bool> _waitUntilHomeIsTop(BuildContext context) async {
  for (var i = 0; i < 100; i++) {
    if (!context.mounted) return false;
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      // Thêm một nhịp cho hiệu ứng pop chạy xong, khỏi hiện dialog giữa lúc
      // màn đăng nhập còn đang trượt ra.
      await Future.delayed(const Duration(milliseconds: 250));
      return context.mounted;
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }
  return false;
}

class _WelcomeDialog extends StatelessWidget {
  const _WelcomeDialog();

  @override
  Widget build(BuildContext context) {
    // `canPop: false`: nút back của Android không tắt được - phải bấm nút X
    // hoặc "Bắt đầu". Cả hai gọi thẳng `Navigator.pop()` nên không bị chặn -
    // `canPop` chỉ chặn cử chỉ back của hệ thống.
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Nền trang trí (đúng ảnh mẫu) phủ sau toàn bộ nội dung - dialog
            // đã `clipBehavior: antiAlias` nên ảnh tự bo theo góc tròn.
            const Positioned.fill(
              child: Image(
                image: AssetImage('assets/images/img_bg_welcome.png'),
                fit: BoxFit.cover,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _CalendarClockIcon(),
                    const SizedBox(height: 18),
                    const Text(
                      'Chào mừng đến với WorkDay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chấm công nhanh chóng và tính lương\n'
                      'đơn giản mỗi ngày',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const _FeatureRow(
                      icon: Icons.how_to_reg_rounded,
                      color: AppColors.info,
                      background: AppColors.infoSoft,
                      title: 'Chấm công hằng ngày',
                      detail: 'Dễ dàng chấm công, theo dõi thời gian làm việc',
                    ),
                    const _FeatureRow(
                      icon: Icons.bar_chart_rounded,
                      color: AppColors.info,
                      background: AppColors.infoSoft,
                      title: 'Tổng hợp công cuối tháng',
                      detail: 'Tự động thống kê, rõ ràng và chính xác',
                    ),
                    const _FeatureRow(
                      icon: Icons.payments_rounded,
                      color: AppColors.overtime,
                      background: AppColors.overtimeSoft,
                      title: 'Tính lương tự động',
                      detail: 'Tiết kiệm thời gian, hạn chế sai sót',
                      last: true,
                    ),

                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                        children: [
                          const TextSpan(text: 'Bạn chỉ cần '),
                          const TextSpan(
                            text: '3 tab',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textBody,
                            ),
                          ),
                          const TextSpan(
                            text: ': Chấm công • Tổng quan • Cài đặt',
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),

                    GradientButton(
                      label: 'Bắt đầu',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon minh hoạ đầu dialog: lịch có dấu tick (chấm công) + huy hiệu đồng hồ
/// (thời gian) chồng ở góc dưới phải - ghép từ hai icon Material sẵn có thay
/// vì vẽ icon riêng, vẫn đúng bộ màu của app.
class _CalendarClockIcon extends StatelessWidget {
  const _CalendarClockIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              color: AppColors.infoSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 50,
              color: AppColors.info,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3),
              ),
              child: const Icon(
                Icons.access_time_filled_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng tính năng: icon tròn nền màu nhạt + tiêu đề cùng màu + mô tả.
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String detail;
  final bool last;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.detail,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
