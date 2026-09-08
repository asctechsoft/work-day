import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';
import 'employee_form_screen.dart';

/// Thiết lập lương: mức mặc định cho nhân viên mới + xem nhanh mức lương
/// hiện tại của từng người.
class SalarySettingsScreen extends StatefulWidget {
  const SalarySettingsScreen({super.key});

  @override
  State<SalarySettingsScreen> createState() => _SalarySettingsScreenState();
}

class _SalarySettingsScreenState extends State<SalarySettingsScreen> {
  final _data = DataService.instance;
  final _salary = TextEditingController();
  final _otRate = TextEditingController();

  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _data.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = s;
        _salary.text = Fmt.money(s.defaultDailySalary);
        _otRate.text = Fmt.money(s.defaultOtRate);
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _salary.text = Fmt.money(_settings.defaultDailySalary);
        _otRate.text = Fmt.money(_settings.defaultOtRate);
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _salary.dispose();
    _otRate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await _data.saveSettings(
        _settings.copyWith(
          defaultDailySalary: parseMoney(_salary.text).toDouble(),
          defaultOtRate: parseMoney(_otRate.text).toDouble(),
        ),
      );
      if (mounted) showToast(context, 'Đã lưu mức lương mặc định');
    } catch (e) {
      if (mounted) showToast(context, 'Không lưu được: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết lập lương & tăng ca')),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                28 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Mặc định cho nhân viên mới'),
                      const SizedBox(height: 6),
                      const Text(
                        'Giá trị này chỉ điền sẵn khi thêm nhân viên mới. '
                        'Lương của từng người vẫn sửa riêng được.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Lương/ngày (VNĐ)'),
                      TextField(
                        controller: _salary,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsFormatter()],
                        decoration: const InputDecoration(
                          hintText: '200.000',
                          suffixText: 'đ',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _label('Đơn giá tăng ca (VNĐ/giờ)'),
                      TextField(
                        controller: _otRate,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsFormatter()],
                        decoration: const InputDecoration(
                          hintText: '50.000',
                          suffixText: 'đ',
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _busy ? null : _save,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: const Text('Lưu'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Công thức tính lương'),
                      const SizedBox(height: 12),
                      _formulaLine('Lương công', 'Tổng công × Lương/ngày'),
                      _formulaLine('Tiền tăng ca', 'Tổng giờ OT × Đơn giá OT'),
                      _formulaLine('Tổng lương', 'Lương công + Tiền tăng ca'),
                      const SizedBox(height: 6),
                      const Text(
                        'Nếu cơ sở không trả tăng ca riêng thì đặt đơn giá '
                        'tăng ca = 0.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                StreamBuilder<List<Employee>>(
                  stream: _data.watchActiveEmployees(),
                  builder: (context, snap) {
                    final list = snap.data ?? const <Employee>[];
                    if (list.isEmpty) return const SizedBox.shrink();
                    return AppCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Mức lương hiện tại'),
                          const SizedBox(height: 4),
                          for (final e in list)
                            InkWell(
                              onTap: () => pushScreen(
                                context,
                                EmployeeFormScreen(employee: e),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Fmt.currency(e.dailySalary),
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        Text(
                                          e.otRate > 0
                                              ? 'OT ${Fmt.currency(e.otRate)}/h'
                                              : 'Không tính OT',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
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

  Widget _formulaLine(String name, String formula) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.calculate_outlined,
          size: 17,
          color: AppColors.primary,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13.5, color: AppColors.textBody),
              children: [
                TextSpan(
                  text: '$name = ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                TextSpan(text: formula),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
