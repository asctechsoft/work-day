import 'package:cloud_firestore/cloud_firestore.dart';

/// Một cơ sở (một khách hàng dùng app).
///
/// `id` **chính là uid Firebase của chủ cơ sở** - xem `firestore.rules`. Nhờ
/// quy ước đó client biết đường dẫn dữ liệu của mình ngay từ
/// `AuthService.currentUser.uid`, không phải đọc thêm document nào trước khi
/// vẽ màn đầu (mở app offline vẫn chạy).
class Company {
  final String id;
  final String orgName;
  final String ownerAccount;
  final bool active;
  final DateTime? createdAt;

  const Company({
    required this.id,
    required this.orgName,
    required this.ownerAccount,
    this.active = true,
    this.createdAt,
  });

  factory Company.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Company(
      id: doc.id,
      orgName: (d['orgName'] as String?)?.trim().isNotEmpty == true
          ? (d['orgName'] as String).trim()
          : 'Chưa đặt tên',
      ownerAccount: (d['ownerAccount'] as String?) ?? '',
      active: (d['active'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'orgName': orgName,
        'ownerAccount': ownerAccount,
        'active': active,
      };
}
