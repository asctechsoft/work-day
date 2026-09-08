import 'package:cloud_firestore/cloud_firestore.dart';

/// Một lượt đánh giá app do chủ cơ sở gửi.
///
/// Nằm ở `companies/{companyId}/reviews/{tự sinh}` để dùng luôn quyền của
/// nhánh cơ sở: chủ ghi được, tài khoản tổng đọc được, không phải sửa rules.
class AppReview {
  /// Số sao 1..5.
  final int stars;

  /// Góp ý kèm theo, có thể để trống.
  final String comment;

  /// Phiên bản app lúc gửi - để biết góp ý này nói về bản nào.
  final String appVersion;

  final DateTime? createdAt;

  const AppReview({
    required this.stars,
    this.comment = '',
    this.appVersion = '',
    this.createdAt,
  });

  factory AppReview.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppReview(
      stars: ((d['stars'] as num?)?.toInt() ?? 0).clamp(0, 5),
      comment: (d['comment'] as String?) ?? '',
      appVersion: (d['appVersion'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
