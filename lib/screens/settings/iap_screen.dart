import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../services/remote_config_service.dart';
import '../../widgets/common.dart';

/// Màn "Nâng cấp gói" - hiện khi bấm "Danh sách nhân viên" ở Cài đặt.
///
/// Hiện tại chỉ là UI mẫu để duyệt giao diện: "Tiếp tục thanh toán" và
/// "Khôi phục mua hàng" chưa nối cửa hàng thật, chờ đăng ký gói IAP xong mới
/// nối logic mua (xem [_onContinue]). Đây là tính năng ngoài phạm vi bản
/// đơn giản trong CLAUDE.md, làm theo yêu cầu riêng của người dùng.
class IapScreen extends StatefulWidget {
  const IapScreen({super.key});

  @override
  State<IapScreen> createState() => _IapScreenState();
}

enum _Plan { trial, monthly, yearly }

/// Chỉ hiện Gói Dùng thử, ẩn Gói Tháng/Gói Năm - theo yêu cầu người dùng
/// 21/09/2026 (mặc định cho dùng thử trước). Đổi lại `true` khi mở bán gói
/// trả phí, không cần xoá code hai gói đó.
const _kShowPaidPlans = false;

class _IapScreenState extends State<IapScreen> {
  _Plan _selected = _Plan.trial;

  @override
  Widget build(BuildContext context) {
    // Đọc đồng bộ từ bộ nhớ đệm - đã fetch một lần ở SplashScreen._bootstrap.
    final rc = RemoteConfigService.instance;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Image.asset(
                    'assets/images/img_splash.png',
                    width: 84,
                    height: 84,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Nâng cấp gói',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mở khoá đầy đủ tính năng chấm công & tính lương',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == 0 ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? AppColors.primary
                              : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  _PlanCard(
                    selected: _selected == _Plan.trial,
                    onTap: () => setState(() => _selected = _Plan.trial),
                    title: 'Gói Dùng thử',
                    price: '0đ',
                    unit: '/ 1 tháng đầu',
                    badgeAsset: 'assets/images/iap_1month.png',
                    employeeLimitLabel: '20 nhân viên',
                    hasBackup: false,
                    hasPrioritySupport: false,
                  ),
                  if (_kShowPaidPlans) ...[
                    const SizedBox(height: 12),
                    _PlanCard(
                      selected: _selected == _Plan.monthly,
                      onTap: () => setState(() => _selected = _Plan.monthly),
                      title: 'Gói Tháng',
                      price: Fmt.currency(rc.monthlyPrice),
                      unit: '/ tháng',
                      badgeAsset: 'assets/images/iap_1month.png',
                      employeeLimitLabel: '50 nhân viên',
                      hasBackup: true,
                      hasPrioritySupport: true,
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      selected: _selected == _Plan.yearly,
                      onTap: () => setState(() => _selected = _Plan.yearly),
                      title: 'Gói Năm',
                      price: Fmt.currency(rc.yearlyFinalPrice),
                      unit: '/ năm',
                      originalPrice: Fmt.currency(rc.yearlyOriginalPrice),
                      badgeAsset: 'assets/images/iap_12month.png',
                      employeeLimitLabel: 'Không giới hạn nhân viên',
                      hasBackup: true,
                      hasPrioritySupport: true,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const _SecurePaymentCard(),
                ],
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
      // Nút chính nổi cố định ở đáy màn - không nằm cuối phần cuộn, giống
      // cách các màn Cài đặt khác đang làm (xem §5.2.3 CLAUDE.md): cuộn hết
      // danh sách gói vẫn luôn thấy và bấm được nút này ngay.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GradientButton(
          label: _selected == _Plan.trial
              ? 'Dùng thử miễn phí'
              : 'Tiếp tục thanh toán',
          icon: _selected == _Plan.trial
              ? Icons.play_circle_fill_rounded
              : Icons.arrow_forward_rounded,
          onPressed: _onContinue,
        ),
      ),
    );
  }

  // Chưa nối cửa hàng thật (Play Store) - chờ đăng ký gói IAP xong mới nối
  // logic mua/dùng thử. Bấm nút chính hiện tại chỉ để xem giao diện.
  void _onContinue() {
    showToast(
      context,
      'Chức năng đăng ký gói đang được hoàn thiện, sẽ sớm ra mắt',
    );
  }
}

/// Một thẻ gói cước, chạm để chọn.
class _PlanCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String price;
  final String unit;
  final String badgeAsset;

  /// Giá gốc trước giảm giá, hiện gạch ngang dưới giá cuối. Để trống nếu gói
  /// không giảm giá (Gói Tháng, Gói Dùng thử).
  final String? originalPrice;

  final String employeeLimitLabel;
  final bool hasBackup;
  final bool hasPrioritySupport;

  const _PlanCard({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.price,
    required this.unit,
    required this.badgeAsset,
    required this.employeeLimitLabel,
    required this.hasBackup,
    required this.hasPrioritySupport,
    this.originalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? AppColors.primary : AppColors.textMuted,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                price,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                unit,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          if (originalPrice != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              originalPrice!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      badgeAsset,
                      width: 84,
                      height: 84,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
              // const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _PlanFeatures(
                employeeLimitLabel: employeeLimitLabel,
                hasBackup: hasBackup,
                hasPrioritySupport: hasPrioritySupport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Danh sách tính năng - số nhân viên và hai mục sao lưu/hỗ trợ ưu tiên khác
/// nhau theo từng gói (Gói Dùng thử không có sao lưu & hỗ trợ ưu tiên), riêng
/// "Tự động tổng công & tính lương" luôn có ở cả ba gói.
///
/// Gộp theo **cột** (mỗi cột một `Column` riêng) thay vì theo hàng: hai icon
/// cùng cột nằm chung một `Column` nên chắc chắn thẳng hàng dọc, không phụ
/// thuộc dòng chữ ở hàng trên có xuống dòng hay không như cách gộp theo hàng
/// trước đó - người dùng phản hồi "căn chưa thẳng hàng cột".
class _PlanFeatures extends StatelessWidget {
  final String employeeLimitLabel;
  final bool hasBackup;
  final bool hasPrioritySupport;

  const _PlanFeatures({
    required this.employeeLimitLabel,
    required this.hasBackup,
    required this.hasPrioritySupport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeatureMini(
                  icon: Icons.groups_rounded,
                  label: employeeLimitLabel,
                ),
                const SizedBox(height: 10),
                const _FeatureMini(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Tự động tổng công & tính lương',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeatureMini(
                  icon: Icons.cloud_done_rounded,
                  label: 'Sao lưu dữ liệu',
                  included: hasBackup,
                ),
                const SizedBox(height: 10),
                _FeatureMini(
                  icon: Icons.headset_mic_rounded,
                  label: 'Hỗ trợ ưu tiên',
                  included: hasPrioritySupport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureMini extends StatelessWidget {
  final IconData icon;
  final String label;

  /// `false` vẽ mờ + gạch ngang chữ - báo gói này không có tính năng đó
  /// (Gói Dùng thử không có sao lưu & hỗ trợ ưu tiên).
  final bool included;

  const _FeatureMini({
    required this.icon,
    required this.label,
    this.included = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          included ? icon : Icons.close_rounded,
          size: 15,
          color: included ? AppColors.textMuted : AppColors.border,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: included ? AppColors.textBody : AppColors.textMuted,
              height: 1.3,
              decoration: included ? null : TextDecoration.lineThrough,
              decorationColor: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Thẻ "Thanh toán an toàn" cuối danh sách gói.
class _SecurePaymentCard extends StatelessWidget {
  const _SecurePaymentCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.presentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.present,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thanh toán an toàn',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Thông tin của bạn luôn được mã hoá và bảo mật',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Row(
            children: [
              _MiniIcon(Icons.credit_card_rounded),
              SizedBox(width: 6),
              _MiniIcon(Icons.shield_rounded),
              SizedBox(width: 6),
              _MiniIcon(Icons.lock_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  const _MiniIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 13, color: AppColors.textMuted),
    );
  }
}
