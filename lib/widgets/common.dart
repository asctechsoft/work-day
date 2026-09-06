import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Avatar tròn hiển thị chữ cái đầu của tên nhân viên.
class EmployeeAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const EmployeeAvatar({super.key, required this.initials, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Ô thống kê: số lớn ở trên, nhãn nhỏ ở dưới.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color = AppColors.textDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Hàng thống kê nằm trong thẻ trắng bo góc.
class StatRow extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const StatRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Container(width: 1, height: 34, color: AppColors.border),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// Thanh chọn ngày / tháng có nút lùi - tiến.
class PeriodSelector extends StatelessWidget {
  final String label;

  /// Dòng phụ nhỏ bên dưới, ví dụ khoảng ngày của kỳ lương.
  final String? subLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onTapLabel;
  final IconData? trailingIcon;

  const PeriodSelector({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.subLabel,
    this.onTapLabel,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: subLabel == null ? 46 : 58,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _arrow(Icons.chevron_left_rounded, onPrev, 'Lùi'),
          Expanded(
            child: InkWell(
              onTap: onTapLabel,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          trailingIcon,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                  if (subLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subLabel!,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _arrow(Icons.chevron_right_rounded, onNext, 'Tiến'),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap, String tooltip) => SizedBox(
    width: 44,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.textDark),
      splashRadius: 20,
    ),
  );
}

/// Ô tìm kiếm dùng chung.
class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  const SearchBox({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        isDense: true,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
          size: 21,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ).copyWith(hintText: hint),
    );
  }
}

/// Màn hình trống có biểu tượng và lời nhắc.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Chip trạng thái / OT.
class TagChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;
  final VoidCallback? onTap;
  final double minWidth;

  const TagChip({
    super.key,
    required this.text,
    required this.color,
    required this.background,
    this.icon,
    this.onTap,
    this.minWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth),
          height: 34,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ trắng bo góc dùng để nhóm nội dung.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Tiêu đề nhỏ phía trên một nhóm nội dung.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

void showToast(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.absent : AppColors.textDark,
        duration: const Duration(seconds: 2),
      ),
    );
}
