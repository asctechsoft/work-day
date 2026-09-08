import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/pay_period.dart';
import '../../core/theme.dart';
import '../../models/app_review.dart';
import '../../models/app_settings.dart';
import '../../models/attendance_record.dart';
import '../../models/company.dart';
import '../../models/employee.dart';
import '../../services/data_service.dart';
import '../../services/export_service.dart';
import '../../widgets/common.dart';
import '../overview/period_picker_sheet.dart';

/// Báo cáo của **một cơ sở khác**, dành cho tài khoản tổng.
///
/// Dùng [DataService.forCompany] chứ không phải `DataService.instance`: cơ sở
/// đang đăng nhập vẫn là cơ sở của chính tài khoản này, ba tab không bị đổi
/// dữ liệu dưới chân người dùng.
///
/// **Cố ý chỉ đọc.** Rules không cho tài khoản tổng ghi gì cả nên màn này
/// không có một nút sửa nào - chỉ xem số và xuất file. Đừng thêm thao tác
/// chấm công vào đây: mỗi nút ghi bỏ sót là một lần ăn `permission-denied`.
class CompanyReportScreen extends StatefulWidget {
  final Company company;

  const CompanyReportScreen({super.key, required this.company});

  @override
  State<CompanyReportScreen> createState() => _CompanyReportScreenState();
}

class _CompanyReportScreenState extends State<CompanyReportScreen> {
  late final DataService _data = DataService.forCompany(widget.company.id);

  AppSettings _settings = const AppSettings();
  DateTime _anchor = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  bool _exporting = false;
  Object? _error;

  List<Employee> _employees = const [];
  List<AttendanceRecord> _records = const [];
  AppReview? _review;

  PayPeriod get _period => PayPeriod.of(_anchor, _settings.payPeriodStartDay);

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Đọc một lần thay vì `StreamBuilder`: đây là màn xem báo cáo của khách,
  /// không cần cập nhật realtime, mà đọc một lần thì cũng đỡ mở listener trên
  /// dữ liệu của người khác.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _data.getSettings();
      final period = PayPeriod.of(_anchor, settings.payPeriodStartDay);
      final records = await _data.getPeriod(period);
      final all = await _data.getAllEmployees();
      // Đánh giá của cơ sở: hỏng phần này thì bỏ qua, đừng để cả màn báo cáo
      // chết chỉ vì một thẻ phụ.
      AppReview? review;
      try {
        review = await _data.latestReview();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _review = review;
        // Người đã nghỉ mà còn công trong kỳ vẫn phải có trong bảng (luật §0.7).
        _employees = DataService.employeesForExport(all, records);
        _records = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _shiftMonth(int months) {
    setState(() => _anchor = DateTime(_anchor.year, _anchor.month + months));
    _load();
  }

  Future<void> _pickPeriod() async {
    final picked = await showPeriodPicker(
      context,
      current: _period,
      startDay: _settings.payPeriodStartDay,
    );
    if (picked == null || !mounted) return;
    setState(() => _anchor = picked);
    await _load();
  }

  Future<void> _export() async {
    if (_exporting || _employees.isEmpty) return;
    setState(() => _exporting = true);
    try {
      await ExportService.instance.exportAndShare(
        period: _period,
        employees: _employees,
        records: _records,
        orgName: _settings.orgName.isEmpty
            ? widget.company.orgName
            : _settings.orgName,
      );
    } catch (e) {
      if (mounted) showToast(context, 'Không xuất được file: $e', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaries = DataService.summarize(_employees, _records);
    var totalUnits = 0.0;
    var totalOt = 0;
    var totalPay = 0.0;
    for (final s in summaries) {
      totalUnits += s.totalWorkUnits;
      totalOt += s.overtimeMinutes;
      totalPay += s.totalPay;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.company.orgName),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                PeriodSelector(
                  label: _period.title,
                  subLabel: 'Tính công ${_period.rangeLabel}',
                  onPrev: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                  onTapLabel: _pickPeriod,
                  trailingIcon: Icons.expand_more_rounded,
                ),
                const SizedBox(height: 12),
                StatGrid(
                  items: [
                    StatItem(
                      label: 'Nhân viên',
                      value: '${_employees.length}',
                      unit: 'người',
                      color: AppColors.primaryDark,
                      icon: Icons.groups_rounded,
                    ),
                    StatItem(
                      label: 'Tổng công',
                      value: Fmt.workUnits(totalUnits),
                      unit: 'công',
                      color: AppColors.present,
                      icon: Icons.check_rounded,
                    ),
                    StatItem(
                      label: 'Tổng tăng ca',
                      value: Fmt.otHours(totalOt),
                      color: AppColors.info,
                      icon: Icons.access_time_filled_rounded,
                    ),
                    StatItem(
                      label: 'Tổng quỹ lương',
                      value: Fmt.money(totalPay),
                      unit: 'đ',
                      color: AppColors.primaryDark,
                      icon: Icons.payments_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(child: _buildBody(summaries)),
        ],
      ),
    );
  }

  Widget _buildBody(List<MonthlySummary> summaries) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Không đọc được dữ liệu cơ sở này',
        message:
            'Tài khoản tổng phải được khai trong hàm isSuperAdmin() của '
            'firestore.rules.\n\n$_error',
      );
    }
    if (_employees.isEmpty) {
      return const EmptyState(
        icon: Icons.insert_chart_outlined_rounded,
        title: 'Kỳ này chưa có dữ liệu',
        message: 'Cơ sở chưa có nhân viên hoặc chưa chấm công trong kỳ.',
      );
    }

    final byId = {for (final s in summaries) s.employeeId: s};
    final review = _review;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        if (review != null) ...[
          _ReviewCard(review: review),
          const SizedBox(height: 14),
        ],
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Bảng lương của kỳ'),
              const SizedBox(height: 4),
              for (final e in _employees)
                _ReportRow(employee: e, summary: byId[e.id]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.ios_share_rounded, size: 20),
          label: Text(
            _exporting ? 'Đang tạo file...' : 'Xuất bảng công (.xlsx)',
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tài khoản tổng chỉ xem được số liệu, không sửa được dữ liệu của '
          'cơ sở khách.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textMuted,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Đánh giá app gần nhất của cơ sở này (nếu chủ cơ sở đã gửi).
///
/// Đọc từ `companies/{cid}/reviews`, cùng nhánh với dữ liệu công nên tài khoản
/// tổng đọc được sẵn - xem [DataService.latestReview].
class _ReviewCard extends StatelessWidget {
  final AppReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final at = review.createdAt;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionTitle('Đánh giá của cơ sở')),
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= review.stars
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 18,
                  color: i <= review.stars
                      ? AppColors.overtime
                      : AppColors.textMuted,
                ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textBody,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            [
              if (at != null) 'Gửi ngày ${Fmt.date(at)}',
              if (review.appVersion.isNotEmpty) 'bản ${review.appVersion}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Một dòng: tên nhân viên + công + tăng ca + tiền.
class _ReportRow extends StatelessWidget {
  final Employee employee;
  final MonthlySummary? summary;

  const _ReportRow({required this.employee, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${Fmt.workUnits(s?.totalWorkUnits ?? 0)} công'
                  '${(s?.overtimeMinutes ?? 0) > 0 ? ' · OT ${Fmt.otHours(s!.overtimeMinutes)}' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Fmt.currency(s?.totalPay ?? 0),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
