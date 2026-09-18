import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../models/attendance_record.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';
import 'attendance_actions.dart';
import 'attendance_row.dart';

/// Mở màn tìm nhân viên để chấm công cho [date].
Future<void> showAttendanceSearch(
  BuildContext context, {
  required DateTime date,
  required AppSettings settings,
}) {
  // `pushScreen` lo cả nền đục lẫn chuyển cảnh trượt ngang - xem `appPageRoute`
  // trong widgets/common.dart. Đừng quay lại `MaterialPageRoute`.
  return pushScreen<void>(
    context,
    AttendanceSearchScreen(date: date, settings: settings),
  );
}

/// Màn tìm nhân viên riêng, mở khi chạm ô tìm kiếm ở tab Chấm công.
///
/// Ô tìm kiếm ở tab nằm dưới bốn ô thống kê và nút "Tất cả đi làm" nên khi
/// bàn phím bật thì danh sách kết quả chỉ còn một mẩu. Tách hẳn ra một màn
/// giúp cả màn hình dành cho kết quả, thao tác chấm công vẫn y như ở tab.
class AttendanceSearchScreen extends StatefulWidget {
  final DateTime date;
  final AppSettings settings;

  const AttendanceSearchScreen({
    super.key,
    required this.date,
    required this.settings,
  });

  @override
  State<AttendanceSearchScreen> createState() => _AttendanceSearchScreenState();
}

class _AttendanceSearchScreenState extends State<AttendanceSearchScreen> {
  final _data = DataService.instance;
  final _controller = TextEditingController();
  String _query = '';

  late final AttendanceActions _actions = AttendanceActions(
    data: _data,
    date: widget.date,
    settings: widget.settings,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `appPageRoute` đã bọc nền, giữ thêm lớp này để màn vẫn đục nếu có ai
    // push nó bằng route khác.
    return PageBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tìm nhân viên'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  SearchBox(
                    hint: 'Nhập tên nhân viên...',
                    controller: _controller,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          // Nhắc rõ đang chấm cho ngày nào, vì màn này đứng
                          // tách khỏi thanh chọn ngày ở tab.
                          'Chấm công cho ${Fmt.fullDate(widget.date)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<Employee>>(
      stream: _data.watchActiveEmployees(),
      builder: (context, empSnap) {
        if (empSnap.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Không tải được danh sách',
            message: '${empSnap.error}',
          );
        }
        if (!empSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final employees = empSnap.data!;

        return StreamBuilder<Map<String, AttendanceRecord>>(
          stream: _data.watchDay(widget.date),
          builder: (context, recSnap) {
            final records = recSnap.data ?? const <String, AttendanceRecord>{};

            final q = _query.trim().toLowerCase();
            // Số thứ tự phải là vị trí trong danh sách gốc, không phải vị trí
            // trong kết quả lọc - để khớp với số nhìn thấy ở tab Chấm công.
            final visible = <(int, Employee)>[
              for (var i = 0; i < employees.length; i++)
                if (q.isEmpty || employees[i].name.toLowerCase().contains(q))
                  (i + 1, employees[i]),
            ];

            if (employees.isEmpty) {
              return const EmptyState(
                icon: Icons.group_add_outlined,
                title: 'Chưa có nhân viên nào',
                message:
                    'Vào tab Cài đặt > Danh sách nhân viên để thêm nhân viên '
                    'trước khi chấm công.',
              );
            }
            if (visible.isEmpty) {
              return const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Không tìm thấy nhân viên',
                message: 'Thử nhập lại tên khác.',
              );
            }

            return ListView.separated(
              // Bàn phím đang bật thì vuốt danh sách là tắt bàn phím, khỏi
              // phải bấm nút back của máy trước rồi mới chấm được.
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              // Cộng chiều cao thanh điều hướng Android vào đáy, không thì
              // dòng cuối bị che (xem §5.2.3).
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final (index, e) = visible[i];
                return AttendanceRow(
                  index: index,
                  employee: e,
                  record: records[e.id],
                  locked: _actions.isFuture,
                  workHoursPerDay: widget.settings.workHoursPerDay,
                  onToggleStatus: () =>
                      _actions.toggleStatus(context, e, records[e.id]),
                  onEditOvertime: () =>
                      _actions.editOvertime(context, e, records[e.id]),
                  onPickStatus: () =>
                      _actions.pickStatus(context, e, records[e.id]),
                );
              },
            );
          },
        );
      },
    );
  }
}
