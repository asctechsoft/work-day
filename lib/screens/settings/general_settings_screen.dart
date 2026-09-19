import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/pay_period.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';
import 'remind_time_sheet.dart';
import 'start_day_sheet.dart';

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
  bool _remindEnabled = true;
  int _remindHour = 18;
  int _remindMinute = 0;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _presets = List<int>.from(_settings.otPresets);
    // Gõ vào ô nào cũng phải cập nhật lại nút Lưu (hiện / mờ đi).
    _orgName.addListener(_onFieldChanged);
    _hours.addListener(_onFieldChanged);
    _load();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  /// Có gì khác so với thiết lập đang lưu trên Firestore không.
  ///
  /// Dùng để bật nút Lưu ở thanh tiêu đề và chặn thoát khi chưa lưu - màn này
  /// dài, người dùng dễ sửa xong rồi bấm back mà tưởng đã lưu.
  bool get _hasChanges {
    if (!_loaded) return false;
    final name = _orgName.text.trim().isEmpty
        ? 'WorkDay'
        : _orgName.text.trim();
    final hours =
        (int.tryParse(_hours.text.trim()) ?? _settings.workHoursPerDay)
            .clamp(1, 24);
    final presets = _presets.toList()..sort();
    final saved = _settings.otPresets.toList()..sort();

    return name != _settings.orgName ||
        hours != _settings.workHoursPerDay ||
        _startDay != _settings.payPeriodStartDay ||
        _remindEnabled != _settings.remindEnabled ||
        _remindHour != _settings.remindHour ||
        _remindMinute != _settings.remindMinute ||
        !listEquals(presets, saved);
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
      _remindEnabled = s.remindEnabled;
      _remindHour = s.remindHour;
      _remindMinute = s.remindMinute;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _orgName.removeListener(_onFieldChanged);
    _hours.removeListener(_onFieldChanged);
    _orgName.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final hours = int.tryParse(_hours.text.trim()) ?? 8;
      final next = _settings.copyWith(
        orgName: _orgName.text.trim().isEmpty
            ? 'WorkDay'
            : _orgName.text.trim(),
        workHoursPerDay: hours.clamp(1, 24),
        otPresets: (_presets.toList()..sort()),
        payPeriodStartDay: _startDay,
        remindEnabled: _remindEnabled,
        remindHour: _remindHour,
        remindMinute: _remindMinute,
      );
      await _data.saveSettings(next);
      if (!mounted) return;
      setState(() {
        // Lấy giá trị vừa lưu làm mốc so sánh mới, nếu không nút Lưu cứ sáng
        // mãi dù chẳng còn gì để lưu.
        _settings = next;
        _orgName.text = next.orgName;
        _hours.text = '${next.workHoursPerDay}';
        _presets = List<int>.from(next.otPresets);
      });
      showToast(context, 'Đã lưu thiết lập');
    } catch (e) {
      if (mounted) showToast(context, 'Không lưu được: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Bấm back khi còn thay đổi chưa lưu thì hỏi lại.
  Future<bool> _confirmLeave() async {
    if (!_hasChanges) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Chưa lưu thiết lập',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: const Text(
          'Bạn vừa sửa vài mục nhưng chưa lưu. Thoát ra thì các thay đổi đó '
          'sẽ mất.',
          style: TextStyle(color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.absent),
            child: const Text('Thoát, bỏ thay đổi'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ở lại'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _addPreset() async {
    final controller = TextEditingController();
    final entered = await showDialog<int>(
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Ví dụ: 90',
                suffixText: 'phút',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Nhập theo phút: 30 phút gõ 30, một tiếng rưỡi gõ 90.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text.trim())),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (entered == null || entered <= 0) return;
    final minutes = (entered.clamp(0, 24 * 60) / 5).round() * 5;
    if (minutes <= 0 || _presets.contains(minutes)) return;
    setState(() => _presets = [..._presets, minutes]..sort());
  }

  Future<void> _pickStartDay() async {
    final picked = await showStartDaySheet(context, selected: _startDay);
    if (picked == null || !mounted) return;
    setState(() => _startDay = picked);
  }

  Future<void> _pickRemindTime() async {
    final picked = await showRemindTimeSheet(
      context,
      hour: _remindHour,
      minute: _remindMinute,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _remindHour = picked.$1;
      _remindMinute = picked.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _loaded && !_busy && _hasChanges;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (!mounted || !leave) return;
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thiết lập chung'),
          actions: [
            // Nút Lưu ở thanh tiêu đề, chỉ hiện khi có thay đổi: màn này dài,
            // sửa xong ở nửa trên mà phải cuộn hết xuống đáy mới lưu được thì
            // rất dễ quên.
            if (canSave)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Lưu'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Nút lưu nằm ngoài vùng cuộn: trước đây nó là phần tử cuối của
        // ListView nên máy có thanh điều hướng dưới đáy che mất, người dùng
        // phản hồi "không vuốt lên để bấm nút lưu được".
        bottomNavigationBar: !_loaded
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: canSave ? _save : null,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _hasChanges
                                ? 'Lưu thiết lập'
                                : 'Đã lưu, không có thay đổi mới',
                          ),
                  ),
                ),
              ),
        body: !_loaded
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                          Material(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _pickStartDay,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Ngày $_startDay',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
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
                const SizedBox(height: 14),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Nhắc chấm công cuối ngày'),
                      const SizedBox(height: 6),
                      const Text(
                        'Đến giờ này mà còn người trong danh sách chưa được '
                        'chấm công hôm nay, điện thoại sẽ báo bằng một '
                        'thông báo.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Bật nhắc',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          Switch(
                            value: _remindEnabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) =>
                                setState(() => _remindEnabled = v),
                          ),
                        ],
                      ),
                      if (_remindEnabled) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Vào lúc',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            Material(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _pickRemindTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 16,
                                        color: AppColors.textDark,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_remindHour.toString().padLeft(2, '0')}:'
                                        '${_remindMinute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                ],
              ),
      ),
    );
  }
}
