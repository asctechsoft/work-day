import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_events.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

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

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _WelcomeDialog(),
  );

  // Ghi sau khi đã hiện: đóng app giữa lúc dialog đang mở thì lần sau vẫn được
  // chào, thà chào hai lần còn hơn người dùng chưa kịp đọc đã mất luôn.
  await prefs.setBool(_seenKey(uid), true);
}

class _WelcomeDialog extends StatelessWidget {
  const _WelcomeDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.waving_hand_rounded,
                  color: AppColors.primaryDark,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chào mừng đến WorkDay!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ba tab, làm theo thứ tự này là xong:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),

              const _Step(
                icon: Icons.groups_rounded,
                color: AppColors.info,
                title: '1. Thêm nhân viên',
                detail: 'Vào tab Cài đặt › Danh sách nhân viên, nhập tên và '
                    'lương/ngày của từng người.',
              ),
              const _Step(
                icon: Icons.event_available_rounded,
                color: AppColors.present,
                title: '2. Chấm công mỗi ngày',
                detail: 'Tab Chấm công: bấm "Tất cả đi làm" rồi sửa lẻ vài '
                    'người nghỉ. Mất chưa tới một phút.',
              ),
              const _Step(
                icon: Icons.payments_rounded,
                color: AppColors.overtime,
                title: '3. Xem lương cuối kỳ',
                detail: 'Tab Tổng quan tự tính lương từ số công, tải được ra '
                    'file Excel để lưu hoặc gửi.',
                last: true,
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Bắt đầu'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Mở luôn tab Cài đặt cho người mới - việc đầu tiên phải làm
                  // là thêm nhân viên, không thì tab Chấm công trống trơn.
                  //
                  // Phải đi qua `AppEvents`, KHÔNG dùng `HomeShell.of(context)`:
                  // dialog là một route nằm cùng cấp với HomeShell trong
                  // Overlay, không phải con của nó (xem §6).
                  AppEvents.requestTab.value = 2;
                },
                child: const Text(
                  'Thêm nhân viên ngay',
                  style: TextStyle(fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một bước trong hướng dẫn: icon tròn + tiêu đề + mô tả.
class _Step extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final bool last;

  const _Step({
    required this.icon,
    required this.color,
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              // Nền lấy chính màu của bước ở alpha 0.12, khỏi thêm hằng số màu.
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.4,
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
