import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/pay_period.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';

/// Thiết lập chung: tên cơ sở, tiền tệ, mốc OT nhanh, giờ làm mỗi ngày.
class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  final _data = DataService.instance;
  final _orgName = TextEditingController();
  final _hours = TextEditingController();

  AppSettings _settings = const AppSettings();
  late List<int> _presets;
  int _startDay = 1;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _presets = List<int>.from(_settings.otPresets);
    _load();
  }

  Future<void> _load() async {
    AppSettings s;
    try {
      s = await _data.getSettings();
    } catch (_) {
      s = _settings;
    }
    if (!mounted) return;
    setState(() {
      _settings = s;
      _orgName.text = s.orgName;
      _hours.text = '${s.workHoursPerDay}';
      _presets = List<int>.from(s.otPresets);
      _startDay = s.payPeriodStartDay;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _orgName.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final hours = int.tryParse(_hours.text.trim()) ?? 8;
      await _data.saveSettings(
        _settings.copyWith(
          orgName: _orgName.text.trim().isEmpty
              ? 'WorkDay'
              : _orgName.text.trim(),
          workHoursPerDay: hours.clamp(1, 24),
          otPresets: (_presets.toList()..sort()),
          payPeriodStartDay: _startDay,
        ),
      );
      if (mounted) showToast(context, 'Đã lưu thiết lập');
    } catch (e) {
      if (mounted) showToast(context, 'Không lưu được: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPreset() async {
    final controller = TextEditingController();
    final hours = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Thêm mốc tăng ca',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            hintText: 'Ví dụ: 3',
            suffixText: 'giờ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              double.tryParse(controller.text.trim().replaceAll(',', '.')),
            ),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (hours == null || hours <= 0) return;
    final minutes = ((hours * 60).round() / 5).round() * 5;
    if (minutes <= 0 || _presets.contains(minutes)) return;
    setState(() => _presets = [..._presets, minutes]..sort());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết lập chung')),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Tên cơ sở'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _orgName,
                        decoration: const InputDecoration(
                          hintText: 'Ví dụ: Xưởng may Bình An',
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
                      const SectionTitle('Kỳ lương'),
                      const SizedBox(height: 6),
                      const Text(
                        'Cơ sở chốt công vào ngày nào trong tháng? Chọn 1 nếu '
                        'chốt đúng theo tháng dương lịch.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Bắt đầu từ ngày',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _startDay,
                                isDense: true,
                                borderRadius: BorderRadius.circular(12),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                                items: [
                                  for (var d = 1; d <= 28; d++)
                                    DropdownMenuItem(
                                      value: d,
                                      child: Text('Ngày $d'),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _startDay = v ?? 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kỳ đang diễn ra',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              PayPeriod.current(_startDay).fullRangeLabel,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
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
                      const SectionTitle('Mốc tăng ca nhanh'),
                      const SizedBox(height: 6),
                      const Text(
                        'Các nút hiện trong bảng chọn giờ tăng ca.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in _presets)
                            InputChip(
                              label: Text(Fmt.otHours(m)),
                              backgroundColor: AppColors.primarySoft,
                              side: BorderSide.none,
                              labelStyle: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              deleteIconColor: AppColors.primaryDark,
                              onDeleted: _presets.length <= 1
                                  ? null
                                  : () => setState(
                                      () => _presets = [..._presets]..remove(m),
                                    ),
                            ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.add_rounded,
                              size: 17,
                              color: AppColors.primary,
                            ),
                            label: const Text('Thêm mốc'),
                            backgroundColor: AppColors.background,
                            side: const BorderSide(color: AppColors.border),
                            labelStyle: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            onPressed: _addPreset,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Số giờ làm mỗi ngày'),
                      const SizedBox(height: 6),
                      const Text(
                        'Chỉ dùng để gợi ý đơn giá tăng ca, không ảnh hưởng '
                        'tới cách tính công.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: _hours,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: const InputDecoration(suffixText: 'giờ'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AppCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tiền tệ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'VND (đ)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textBody,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Lưu thiết lập'),
                ),
              ],
            ),
    );
  }
}
