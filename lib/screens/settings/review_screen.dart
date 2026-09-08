import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';

/// Phiên bản app ghi kèm mỗi lượt đánh giá, để biết góp ý nói về bản nào.
/// Đổi số phiên bản thì đổi cả ở đây, `settings_tab.dart` và `about_screen.dart`.
const _appVersion = '1.0.0';

/// App **chưa lên Google Play** (đang giao bằng file APK) nên phần "Đánh giá
/// trên Play Store" đang ẩn. Lên store rồi thì đổi cờ này thành `true` là
/// dòng đó hiện ra, không phải sửa gì thêm.
const kOnPlayStore = false;

/// Trang app trên Play Store - đổi theo applicationId của bản product.
const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.campany.tickgo';

/// Màn đánh giá app: chọn sao, góp ý, gửi.
///
/// Đánh giá lưu vào `companies/{cid}/reviews` (xem [DataService.saveReview]) -
/// nhánh con của cơ sở nên tài khoản tổng đọc được ngay, không phải sửa rules.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _comment = TextEditingController();

  int _stars = 0;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      showToast(context, 'Chọn số sao trước đã', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await DataService.instance.saveReview(
        stars: _stars,
        comment: _comment.text,
        appVersion: _appVersion,
      );
      if (!mounted) return;
      showToast(context, 'Đã nhận đánh giá của bạn. Cảm ơn nhiều!');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showToast(context, 'Không gửi được đánh giá: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPlayStore() async {
    final ok = await launchUrl(
      Uri.parse(_playStoreUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      showToast(context, 'Không mở được Play Store', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đánh giá ứng dụng')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          28 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              children: [
                const Text(
                  'Bạn thấy WorkDay dùng thế nào?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chạm vào số sao bạn muốn cho',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _stars = i),
                        // Nút to cho dễ bấm bằng một tay.
                        iconSize: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(
                          i <= _stars
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: i <= _stars
                              ? AppColors.overtime
                              : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _starLabel(_stars),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Góp ý thêm (không bắt buộc)'),
                const SizedBox(height: 10),
                TextField(
                  controller: _comment,
                  maxLines: 5,
                  minLines: 3,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Chỗ nào khó dùng, cần thêm gì...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Gửi đánh giá'),
          ),

          if (kOnPlayStore) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy ? null : _openPlayStore,
              icon: const Icon(Icons.shop_outlined, size: 20),
              label: const Text('Đánh giá trên Play Store'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size.fromHeight(48),
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
          ],

          const SizedBox(height: 14),
          const Text(
            'Đánh giá được gửi thẳng cho người làm app, không hiện công khai '
            'và không ảnh hưởng gì tới dữ liệu chấm công.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  static String _starLabel(int stars) => switch (stars) {
    1 => 'Rất tệ',
    2 => 'Chưa tốt',
    3 => 'Tạm được',
    4 => 'Tốt',
    5 => 'Rất tốt',
    _ => 'Chưa chọn',
  };
}
