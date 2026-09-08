import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';
import 'employee_form_screen.dart';

/// Quản lý nhân viên: thêm, sửa, ngừng sử dụng.
/// Nhân viên đã nghỉ vẫn giữ toàn bộ lịch sử công cũ.
class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final _data = DataService.instance;
  String _query = '';
  bool _showInactive = false;

  void _openForm([Employee? employee]) {
    pushScreen(context, EmployeeFormScreen(employee: employee));
  }

  Future<void> _toggleActive(Employee e) async {
    await _data.setEmployeeActive(e.id, !e.active);
    if (!mounted) return;
    showToast(
      context,
      e.active
          ? 'Đã chuyển ${e.name} sang Đã nghỉ'
          : 'Đã cho ${e.name} đi làm lại',
    );
  }

  Future<void> _confirmDelete(Employee e) async {
    final count = await _data.countAttendanceOf(e.id);
    if (!mounted) return;

    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Không nên xoá',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          content: Text(
            '${e.name} đã có $count ngày công đã chấm. '
            'Hãy chuyển sang "Đã nghỉ" để giữ lại lịch sử công và lương cũ.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xoá nhân viên',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: Text('Xoá hồ sơ của ${e.name}? Thao tác này không hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.absent),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _data.deleteEmployee(e.id);
      if (mounted) showToast(context, 'Đã xoá ${e.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách nhân viên')),
      body: StreamBuilder<List<Employee>>(
        stream: _data.watchAllEmployees(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final all = snap.data!;
          final activeCount = all.where((e) => e.active).length;
          final inactiveCount = all.length - activeCount;

          final q = _query.trim().toLowerCase();
          var visible = _showInactive
              ? all
              : all.where((e) => e.active).toList();
          if (q.isNotEmpty) {
            visible = visible
                .where((e) => e.name.toLowerCase().contains(q))
                .toList();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SearchBox(
                            hint: 'Tìm nhân viên...',
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () => _openForm(),
                            icon: const Icon(Icons.add_rounded, size: 19),
                            label: const Text('Thêm'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (inactiveCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Text(
                              'Đang làm: $activeCount • Đã nghỉ: $inactiveCount',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showInactive = !_showInactive),
                              child: Text(
                                _showInactive
                                    ? 'Ẩn người đã nghỉ'
                                    : 'Hiện người đã nghỉ',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        icon: Icons.person_add_alt_1_outlined,
                        title: all.isEmpty
                            ? 'Chưa có nhân viên nào'
                            : 'Không tìm thấy nhân viên',
                        message: all.isEmpty
                            ? 'Bấm "Thêm" để tạo hồ sơ nhân viên đầu tiên.'
                            : 'Thử nhập lại tên khác.',
                        action: all.isEmpty
                            ? SizedBox(
                                width: 200,
                                child: ElevatedButton(
                                  onPressed: () => _openForm(),
                                  child: const Text('Thêm nhân viên'),
                                ),
                              )
                            : null,
                      )
                    : ListView.separated(
                        // Cộng chiều cao thanh điều hướng Android vào đáy,
                        // không thì dòng cuối bị che (xem §5.2.3).
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          24 + MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final e = visible[i];
                          return _EmployeeRow(
                            index: i + 1,
                            employee: e,
                            onEdit: () => _openForm(e),
                            onToggleActive: () => _toggleActive(e),
                            onDelete: () => _confirmDelete(e),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  /// Số thứ tự hiển thị, bắt đầu từ 1.
  final int index;
  final Employee employee;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _EmployeeRow({
    required this.index,
    required this.employee,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final e = employee;

    return Opacity(
      opacity: e.active ? 1 : 0.62,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$index',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 4),
            EmployeeAvatar(initials: e.initials, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (!e.active) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.absentSoft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'Đã nghỉ',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.absent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Lương/ngày: ${Fmt.currency(e.dailySalary)}'
                    '${e.otRate > 0 ? ' • OT: ${Fmt.currency(e.otRate)}/h' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Sửa',
              icon: const Icon(
                Icons.edit_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              splashRadius: 20,
            ),
            PopupMenuButton<String>(
              tooltip: 'Thêm lựa chọn',
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'toggle') onToggleActive();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    e.active ? 'Chuyển sang Đã nghỉ' : 'Cho đi làm lại',
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Xoá hồ sơ',
                    style: TextStyle(color: AppColors.absent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
