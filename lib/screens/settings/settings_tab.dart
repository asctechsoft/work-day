import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/remote_config_service.dart';
import '../../widgets/common.dart';
import '../admin/company_list_screen.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'employee_list_screen.dart';
import 'general_settings_screen.dart';
import 'iap_screen.dart';
import 'review_screen.dart';
import 'salary_settings_screen.dart';

/// Tab Cài đặt: gom toàn bộ phần quản lý dữ liệu để navigation chỉ có 3 tab.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  /// Hồ sơ `users/{uid}` - chỉ dùng để biết có phải tài khoản tổng không.
  ///
  /// Dựng một lần trong `State`: `watchAccount()` tạo stream mới mỗi lần gọi,
  /// để trong `build` là mỗi lần vẽ lại một lần đăng ký nghe.
  late final Stream<Map<String, dynamic>> _profile =
      AuthService.instance.watchAccount();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _profile,
      builder: (context, snap) {
        // Lỗi đọc (vừa đăng xuất chẳng hạn) thì coi như tài khoản thường.
        final isSuper = snap.hasData && AuthService.isSuperAccount(snap.data!);
        return _buildBody(context, isSuper);
      },
    );
  }

  Widget _buildBody(BuildContext context, bool isSuper) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // Chỉ tài khoản tổng thấy dòng này. Thấy được cũng không đọc được
          // gì thêm: rules chặn theo danh sách uid, không theo trường `role`.
          if (isSuper)
            _SettingItem(
              icon: Icons.store_mall_directory_outlined,
              color: AppColors.info,
              title: 'Quản lý cơ sở',
              subtitle: 'Xem báo cáo của tất cả cơ sở (chỉ đọc)',
              onTap: () => _open(context, const CompanyListScreen()),
            ),
          _SettingItem(
            icon: Icons.person_outline_rounded,
            color: AppColors.info,
            title: 'Thông tin tài khoản',
            subtitle: 'Đổi tên hiển thị, thông tin đăng nhập',
            onTap: () => _open(context, const AccountScreen()),
          ),
          _SettingItem(
            icon: Icons.groups_outlined,
            color: AppColors.present,
            title: 'Danh sách nhân viên',
            subtitle: 'Thêm, sửa, ngừng sử dụng nhân viên',
            onTap: () => _openEmployeeList(context),
          ),
          _SettingItem(
            icon: Icons.payments_outlined,
            color: AppColors.overtime,
            title: 'Thiết lập lương & tăng ca',
            subtitle: 'Mức lương/ngày và đơn giá tăng ca mặc định',
            onTap: () => _open(context, const SalarySettingsScreen()),
          ),
          _SettingItem(
            icon: Icons.tune_rounded,
            color: AppColors.primary,
            title: 'Thiết lập chung',
            subtitle: 'Tiền tệ, mốc tăng ca nhanh, giờ làm mỗi ngày',
            onTap: () => _open(context, const GeneralSettingsScreen()),
          ),
          _SettingItem(
            icon: Icons.star_outline_rounded,
            color: AppColors.overtime,
            title: 'Đánh giá ứng dụng',
            subtitle: 'Cho 5 sao nếu thấy app hữu ích',
            // Dialog nổi trên chính màn này, không đẩy sang màn mới - xem
            // showReviewDialog() trong review_screen.dart.
            onTap: () => showReviewDialog(context),
          ),
          _SettingItem(
            icon: Icons.info_outline_rounded,
            color: AppColors.textMuted,
            title: 'Giới thiệu ứng dụng',
            subtitle: 'Phiên bản 1.0.0',
            onTap: () => _open(context, const AboutScreen()),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.absent,
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'WorkDay • Phiên bản 1.0.0',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    pushScreen(context, screen);
  }

  // Đẩy Danh sách nhân viên trước, rồi đẩy màn Nâng cấp gói chồng lên trên -
  // bấm X ở đó chỉ pop, lộ ra Danh sách nhân viên đã có sẵn dưới, không quay
  // thẳng về Cài đặt (xem IapScreen). Cờ `iapEnabled` tắt (mặc định) thì bỏ
  // qua màn IAP, vào thẳng danh sách như bản một-tài-khoản - đổi trên
  // Remote Config Console, không cần build lại app.
  void _openEmployeeList(BuildContext context) {
    pushScreen(context, const EmployeeListScreen());
    if (RemoteConfigService.instance.iapEnabled) {
      pushScreen(context, const IapScreen());
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: const Text(
          'Bạn sẽ cần nhập lại tài khoản và mật khẩu ở lần mở app tiếp theo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.absent),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok == true) await AuthService.instance.signOut();
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
