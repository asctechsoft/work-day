import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../intro_screen.dart';

/// Giới thiệu ứng dụng và nhắc lại phạm vi của bản đơn giản.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giới thiệu ứng dụng')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          28 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          const Center(child: AppLogo(size: 88)),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'WorkDay',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Phiên bản 1.0.0',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Đơn giản • Nhanh chóng • Hiệu quả',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),

          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle('App làm được gì'),
                SizedBox(height: 12),
                _Bullet('Chấm công từng ngày: Đi làm = 1 công, Nghỉ = 0 công.'),
                _Bullet('Ghi giờ tăng ca riêng: 0.5h, 1h, 1.5h, 2h hoặc tự nhập.'),
                _Bullet('Nút "Tất cả đi làm" để chấm nhanh cả danh sách.'),
                _Bullet('Cuối tháng tự cộng công, tổng OT và tính lương.'),
                _Bullet('Quản lý nhân viên: thêm, sửa, ngừng sử dụng.'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle('Cách tính lương'),
                SizedBox(height: 12),
                _Bullet('Lương công = Tổng công × Lương/ngày'),
                _Bullet('Tiền tăng ca = Tổng giờ OT × Đơn giá OT/giờ'),
                _Bullet('Tổng lương = Lương công + Tiền tăng ca'),
                SizedBox(height: 4),
                Text(
                  'Lương luôn được tính lại từ dữ liệu công của tháng đang '
                  'chọn nên sửa công là số lương cập nhật theo ngay.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle('Không có trong bản này'),
                SizedBox(height: 12),
                Text(
                  'Phân quyền và nhiều tài khoản • Bộ phận, chức vụ, duyệt '
                  'công, chốt bảng lương • Quét bảng giấy bằng AI, GPS, khuôn '
                  'mặt, QR, máy chấm công • Tạm ứng, thưởng, phụ cấp, khấu '
                  'trừ, nghỉ phép và báo cáo nâng cao.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textBody,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Dữ liệu được lưu trên Firebase Firestore.\n'
              'App vẫn chấm công được khi mất mạng và tự đồng bộ lại sau.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.check_circle_rounded,
              size: 15,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textBody,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
