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

  /// Sửa riêng ngoài `_settings`: thêm/xoá ngày lễ lưu ngay, không chờ nút
  /// Lưu chung của khối "Mặc định cho nhân viên mới" phía trên.
  List<String> _holidayDates = const [];
  bool _holidayBusy = false;

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
        _holidayDates = [...s.holidayDates]..sort();
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

  /// Ngày lễ lưu ngay khi thêm/xoá, không có nút Lưu riêng - đây là một danh
  /// sách chọn/bỏ đơn giản, không phải form nhiều ô nhập như phần trên.
  Future<void> _saveHolidayDates(List<String> next) async {
    setState(() => _holidayBusy = true);
    try {
      await _data.saveSettings(_settings.copyWith(holidayDates: next));
      if (!mounted) return;
      setState(() {
        _settings = _settings.copyWith(holidayDates: next);
        _holidayDates = next;
      });
    } catch (e) {
      if (mounted) showToast(context, 'Không lưu được: $e', error: true);
    } finally {
      if (mounted) setState(() => _holidayBusy = false);
    }
  }

  Future<void> _addHoliday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'Chọn ngày lễ',
    );
    if (picked == null) return;
    final key = Fmt.dateKey(picked);
    if (_holidayDates.contains(key)) return;
    await _saveHolidayDates([..._holidayDates, key]..sort());
  }

  Future<void> _removeHoliday(String key) async {
    await _saveHolidayDates(
      _holidayDates.where((d) => d != key).toList(),
    );
  }

  /// Hệ số nhân lương công của ngày lễ - lưu ngay khi chọn, cùng kiểu với
  /// danh sách ngày lễ ngay trên nó.
  Future<void> _saveHolidayMultiplier(double value) async {
    if (_settings.holidayPayMultiplier == value) return;
    setState(() => _holidayBusy = true);
    try {
      await _data.saveSettings(
        _settings.copyWith(holidayPayMultiplier: value),
      );
      if (!mounted) return;
      setState(() {
        _settings = _settings.copyWith(holidayPayMultiplier: value);
      });
    } catch (e) {
      if (mounted) showToast(context, 'Không lưu được: $e', error: true);
    } finally {
      if (mounted) setState(() => _holidayBusy = false);
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

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: SectionTitle('Ngày lễ'),
                          ),
                          if (_holidayBusy)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: _addHoliday,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Thêm ngày'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Nhân viên đi làm vào đúng ngày lễ được tính OT theo '
                        'đơn giá tăng ca ngày lễ riêng (đặt ở hồ sơ từng '
                        'người), thay vì đơn giá thường.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Hệ số lương công ngày lễ'),
                      Row(
                        children: [
                          for (final m in const [1.0, 2.0, 3.0]) ...[
                            _MultiplierChip(
                              value: m,
                              selected: _settings.holidayPayMultiplier == m,
                              enabled: !_holidayBusy,
                              onTap: () => _saveHolidayMultiplier(m),
                            ),
                            if (m != 3.0) const SizedBox(width: 10),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Áp dụng cho lương công của đúng ngày lễ (ví dụ x2 = '
                        'gấp đôi lương/ngày). Không ảnh hưởng ngày thường '
                        'hay cuối tuần, và không tính vào tiền tăng ca.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      if (_holidayDates.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Chưa có ngày lễ nào.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      else
                        for (final key in _holidayDates)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    Fmt.fullDate(Fmt.parseDateKey(key)),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _holidayBusy
                                      ? null
                                      : () => _removeHoliday(key),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 19,
                                    color: AppColors.textMuted,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
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
                                        // Chỉ hiện khi có đặt riêng - đa số
                                        // nhân viên dùng chung một đơn giá.
                                        if (e.otRateWeekend > 0 ||
                                            e.otRateHoliday > 0)
                                          Text(
                                            [
                                              if (e.otRateWeekend > 0)
                                                'T7-CN ${Fmt.currency(e.otRateWeekend)}/h',
                                              if (e.otRateHoliday > 0)
                                                'Lễ ${Fmt.currency(e.otRateHoliday)}/h',
                                            ].join(' · '),
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.overtime,
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

/// Một lựa chọn hệ số ("x1", "x2", "x3") - kiểu chip chọn/bỏ giống các
/// bảng chọn khác trong app, không dùng ô nhập % tự do.
class _MultiplierChip extends StatelessWidget {
  final double value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _MultiplierChip({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: Text(
              value == 1 ? 'x1 (thường)' : 'x${Fmt.workUnits(value)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primaryDark : AppColors.textBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
