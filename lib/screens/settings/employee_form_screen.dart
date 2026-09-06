import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';

/// Thêm / sửa nhân viên.
class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;
  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _data = DataService.instance;

  late final TextEditingController _name;
  late final TextEditingController _salary;
  late final TextEditingController _otRate;
  late final TextEditingController _phone;

  bool _active = true;
  bool _busy = false;

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _name = TextEditingController(text: e?.name ?? '');
    _salary = TextEditingController(
      text: e == null ? '' : Fmt.money(e.dailySalary),
    );
    _otRate = TextEditingController(
      text: e == null ? '' : Fmt.money(e.otRate),
    );
    _phone = TextEditingController(text: e?.phone ?? '');
    _active = e?.active ?? true;

    if (e == null) _prefillDefaults();
  }

  /// Nhân viên mới lấy sẵn mức lương mặc định trong Cài đặt cho nhanh.
  Future<void> _prefillDefaults() async {
    AppSettings s;
    try {
      s = await _data.getSettings();
    } catch (_) {
      return;
    }
    if (!mounted || _salary.text.isNotEmpty) return;
    setState(() {
      _salary.text = Fmt.money(s.defaultDailySalary);
      _otRate.text = Fmt.money(s.defaultOtRate);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _salary.dispose();
    _otRate.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final employee = Employee(
        id: widget.employee?.id ?? '',
        name: _name.text.trim(),
        dailySalary: parseMoney(_salary.text).toDouble(),
        otRate: parseMoney(_otRate.text).toDouble(),
        phone: _phone.text.trim(),
        active: _active,
      );

      if (_isEdit) {
        await _data.updateEmployee(employee);
      } else {
        await _data.addEmployee(employee);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(
        context,
        _isEdit ? 'Đã lưu thay đổi' : 'Đã thêm ${employee.name}',
      );
    } catch (err) {
      if (mounted) showToast(context, 'Không lưu được: $err', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa nhân viên' : 'Thêm nhân viên'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Center(
              child: EmployeeAvatar(
                initials: _name.text.trim().isEmpty
                    ? '?'
                    : Employee(
                        id: '',
                        name: _name.text,
                        dailySalary: 0,
                      ).initials,
                size: 72,
              ),
            ),
            const SizedBox(height: 24),

            _label('Họ và tên *'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Ví dụ: Cô Ngọc'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập họ tên'
                  : null,
            ),
            const SizedBox(height: 16),

            _label('Lương/ngày (VNĐ) *'),
            TextFormField(
              controller: _salary,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                hintText: '200.000',
                suffixText: 'đ',
              ),
              validator: (v) => parseMoney(v ?? '') <= 0
                  ? 'Vui lòng nhập mức lương một ngày công'
                  : null,
            ),
            const SizedBox(height: 16),

            _label('Đơn giá tăng ca (VNĐ/giờ)'),
            TextFormField(
              controller: _otRate,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                hintText: '50.000',
                suffixText: 'đ',
                helperText: 'Để trống hoặc 0 nếu không trả tiền tăng ca riêng',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 16),

            _label('Số điện thoại'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Không bắt buộc'),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đang sử dụng',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _active
                              ? 'Có trong danh sách chấm công hằng ngày'
                              : 'Không hiện khi chấm công, vẫn giữ lịch sử cũ',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _active,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textBody,
      ),
    ),
  );
}
