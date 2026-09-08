import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/company.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';
import 'company_report_screen.dart';

/// Danh sách toàn bộ cơ sở - chỉ dành cho **tài khoản tổng**.
///
/// Vào được màn này không có nghĩa là đọc được dữ liệu: `firestore.rules` chỉ
/// cho các uid trong `isSuperAdmin()` đọc `companies`, người thường mở ra sẽ
/// nhận `permission-denied`. Menu vào đây cũng chỉ hiện khi `users/{uid}` có
/// `role: 'super'` (xem `settings_tab.dart`).
///
/// **Chỉ đọc.** Rules không cho tài khoản tổng ghi bất cứ thứ gì, nên màn này
/// và [CompanyReportScreen] cố tình không có một nút sửa nào - đừng thêm vào,
/// bấm là ăn `permission-denied` giữa mặt.
class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý cơ sở')),
      body: StreamBuilder<List<Company>>(
        stream: DataService.instance.watchCompanies(),
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Không đọc được danh sách cơ sở',
              message:
                  'Tài khoản này không phải tài khoản tổng. Thêm uid của nó '
                  'vào hàm isSuperAdmin() trong firestore.rules rồi Publish '
                  'lại.\n\n${snap.error}',
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final all = snap.data!;
          final q = _deaccentLower(_query);
          final list = q.isEmpty
              ? all
              : all
                    .where(
                      (c) =>
                          _deaccentLower(c.orgName).contains(q) ||
                          _deaccentLower(c.ownerAccount).contains(q),
                    )
                    .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SearchBox(
                  hint: 'Tìm cơ sở theo tên hoặc email',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${all.length} cơ sở',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const TagChip(
                      text: 'Chỉ đọc',
                      color: AppColors.info,
                      background: AppColors.infoSoft,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.store_outlined,
                        title: 'Không có cơ sở nào',
                        message:
                            'Cơ sở được tạo khi khách bấm "Tạo cơ sở mới" ở '
                            'màn đăng nhập.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _CompanyRow(
                          company: list[i],
                          onTap: () => pushScreen(
                            context,
                            CompanyReportScreen(company: list[i]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  final Company company;
  final VoidCallback onTap;

  const _CompanyRow({required this.company, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final created = company.createdAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                EmployeeAvatar(initials: _initials(company.orgName)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.orgName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        company.ownerAccount.isEmpty
                            ? 'Chưa rõ email chủ cơ sở'
                            : company.ownerAccount,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (created != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Tạo ngày ${Fmt.date(created)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!company.active)
                  const TagChip(
                    text: 'Đã ngừng',
                    color: AppColors.absent,
                    background: AppColors.absentSoft,
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

  /// Hai chữ đầu của tên cơ sở, cùng kiểu với avatar nhân viên.
  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String first(String s) => s.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return '${first(parts.first)}${first(parts.last)}';
  }
}

/// Bỏ dấu + hạ chữ thường để tìm kiếm gõ không dấu vẫn ra.
String _deaccentLower(String input) {
  const accents = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
      'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const plain = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
      'ooooooooooooooooouuuuuuuuuuuyyyyyd';
  final buf = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    final i = accents.indexOf(ch);
    buf.write(i >= 0 ? plain[i] : ch);
  }
  return buf.toString();
}
