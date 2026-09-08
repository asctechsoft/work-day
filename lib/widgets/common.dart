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

/// Ô thống kê: icon tròn, số lớn ở giữa, nhãn nhỏ ở dưới.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  /// Icon nhỏ trong vòng tròn nền nhạt phía trên con số. Không bắt buộc,
  /// nhưng có thì hàng thống kê đỡ trống và nhìn ra ngay ô nào nói về gì.
  final IconData? icon;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color = AppColors.textDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Nền lấy từ chính màu của ô nên không phải thêm hằng số màu
              // mới cho từng loại.
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 6),
        ],
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

/// Nút hành động chính, tô dải màu chuyển ("Tất cả đi làm").
///
/// Dùng gradient thay vì `ElevatedButton` phẳng vì đây là nút được bấm nhiều
/// nhất trong app - mỗi ngày một lần cho cả danh sách - nên phải nổi hẳn lên
/// so với mọi thứ khác trên màn.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Đang chạy: thay icon bằng vòng xoay, chặn bấm tiếp.
  final bool busy;

  /// Mũi tên nhỏ ở mép phải, gợi ý "bấm là chạy luôn".
  final bool showArrow;

  const GradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.primaryButton,
          borderRadius: BorderRadius.circular(20),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.buttonGradientMid.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Vòng tròn trắng bọc icon: chi tiết này làm nút trông như
                  // một nút "chạy" chứ không phải một thanh màu.
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.buttonIcon,
                            ),
                          )
                        : Icon(icon, size: 17, color: AppColors.buttonIcon),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (showArrow)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Colors.white,
                    )
                  else
                    const SizedBox(width: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Một ô số liệu trong [StatGrid].
class StatItem {
  final String label;
  final String value;

  /// Đơn vị viết nhỏ sau con số ("công", "người", "đ"). Để trống nếu bản thân
  /// giá trị đã mang đơn vị, ví dụ "3h30".
  final String unit;
  final Color color;

  /// Icon nhỏ trong vòng tròn nền nhạt, đứng bên trái con số.
  final IconData? icon;

  const StatItem({
    required this.label,
    required this.value,
    this.unit = '',
    this.color = AppColors.textDark,
    this.icon,
  });
}

/// Lưới số liệu 2 cột.
///
/// Dùng thay [StatRow] khi có từ 4 ô trở lên hoặc khi giá trị dài (số tiền):
/// nhét 4 số tiền vào một hàng thì chữ dính sát viền và phải viết tắt kiểu
/// "22,4 tr" - người dùng phản hồi là khó đọc. Hai cột thì mỗi ô rộng gấp đôi,
/// đủ chỗ ghi số đầy đủ kèm đơn vị.
class StatGrid extends StatelessWidget {
  final List<StatItem> items;

  const StatGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) {
        rows.add(
          const Divider(height: 1, thickness: 1, color: AppColors.border),
        );
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _cell(items[i])),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              // Số ô lẻ thì ô cuối chiếm nửa bên trái, nửa phải để trống.
              Expanded(
                child: i + 1 < items.length
                    ? _cell(items[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _cell(StatItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (item.icon != null) ...[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 13, color: item.color),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: item.color,
                  ),
                ),
                if (item.unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    item.unit,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: item.color.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool autofocus;

  /// Đặt [onTap] kèm [readOnly] để ô chỉ đóng vai trò nút mở màn tìm kiếm
  /// riêng - vẫn nhìn y hệt ô nhập nên người dùng bấm vào theo thói quen.
  final VoidCallback? onTap;
  final bool readOnly;

  const SearchBox({
    super.key,
    required this.hint,
    this.onChanged,
    this.controller,
    this.autofocus = false,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      readOnly: readOnly,
      // Ô chỉ để bấm thì đừng nhận focus, không thì con trỏ nhấp nháy trong
      // ô rỗng trong khi bàn phím không hề bật.
      canRequestFocus: !readOnly,
      onTap: onTap,
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

/// Nền gradient riêng cho một màn được `push`.
///
/// Nền chung của app dựng ở `MaterialApp.builder`, tức là nằm *sau* toàn bộ
/// Navigator. Scaffold để trong suốt nên trong lúc chuyển cảnh, màn mới không
/// có gì che và nhìn xuyên thẳng xuống màn cũ - hai màn chồng chữ lên nhau.
/// Bọc `Scaffold` của màn được push bằng widget này là hết: vẫn đúng
/// `AppGradients.page` nên nhìn không khác nền chung.
///
/// Không phải bọc tay ở từng màn: [appPageRoute] / [pushScreen] đã bọc sẵn.
class PageBackground extends StatelessWidget {
  final Widget child;
  const PageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.page),
      child: child,
    );
  }
}

/// Route chuẩn của app cho mọi màn được `push`. **Đừng dùng
/// `MaterialPageRoute` nữa**, hai lý do:
///
/// 1. **Nền.** Nền chung nằm sau Navigator, `Scaffold` thì trong suốt, nên màn
///    mới không có gì che và nhìn xuyên thẳng xuống màn cũ. Route này bọc
///    [PageBackground] nên màn nào push qua đây cũng đục sẵn, không thể quên.
/// 2. **Chuyển cảnh.** Nền đục thôi vẫn chưa đủ: chuyển cảnh mặc định của
///    Android (`ZoomPageTransitionsBuilder`) làm mờ dần *cả hai* màn, giữa
///    chừng chính cái nền vừa thêm cũng đang mờ và vẫn nhìn xuyên. Trượt ngang
///    thì màn mới đục từ đầu, che dần màn cũ, không lúc nào thấy hai màn.
Route<T> appPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => PageBackground(child: page),
    transitionsBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(animation),
      child: child,
    ),
  );
}

/// Mở một màn mới bằng [appPageRoute].
Future<T?> pushScreen<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(appPageRoute<T>(page));
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
    final content = Center(
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

    // Nằm trong Expanded mà bàn phím bật lên thì chỗ trống còn chưa tới 200px,
    // Column sẽ tràn (vạch vàng đen) - lúc đó cho cuộn. Còn khi nằm sẵn trong
    // một ListView (chiều cao vô hạn) thì tuyệt đối không được bọc thêm
    // SingleChildScrollView: viewport lồng viewport không giới hạn là lỗi.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return content;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
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
