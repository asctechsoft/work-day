import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bảng màu của WorkDay - lấy theo logo và bản thiết kế giao diện.
class AppColors {
  static const primary = Color(0xFF17A17A);
  static const primaryDark = Color(0xFF0E8465);
  static const primarySoft = Color(0xFFE4F5EF);

  static const background = Color(0xFFF4F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE3E8EE);

  static const textDark = Color(0xFF16324F);
  static const textBody = Color(0xFF44546A);
  static const textMuted = Color(0xFF8A97A8);

  static const present = Color(0xFF1F9D6D);
  static const presentSoft = Color(0xFFE3F5EC);
  static const absent = Color(0xFFE0484D);
  static const absentSoft = Color(0xFFFDE9E9);
  static const overtime = Color(0xFFE08600);
  static const overtimeSoft = Color(0xFFFFF3E0);

  // Nền đậm vừa, dùng cho ô nhỏ (ô ngày trong lịch): các màu *Soft* ở trên
  // quá nhạt, ô cỡ 45px nhìn ra gần như trắng nên không phân biệt được.
  static const presentMedium = Color(0xFFBCE7D3);
  static const overtimeMedium = Color(0xFFFFDDAF);
  static const info = Color(0xFF2F80ED);
  static const infoSoft = Color(0xFFE8F1FE);

  // Trạng thái "Tuỳ chỉnh" (công nhập tay theo giờ làm thực tế) - tách màu
  // riêng khỏi info (đã dùng cho Nửa công) để hai trạng thái không lẫn nhau.
  static const custom = Color(0xFF7C5CFC);
  static const customSoft = Color(0xFFEFEAFE);

  // Ba mức xanh của nút chính (xanh ngọc -> mint), dùng trong
  // [AppGradients.primaryButton].
  static const buttonGradientStart = Color(0xFF36CFA4);
  static const buttonGradientMid = Color(0xFF27C590);
  static const buttonGradientEnd = Color(0xFF42D08A);

  /// Màu icon tick nằm trong vòng tròn trắng của nút chính.
  static const buttonIcon = Color(0xFF25B889);
}

/// Các dải màu chuyển. Tách riêng khỏi [AppColors] cho dễ tìm, nhưng cùng quy
/// tắc: màn hình **không được** tự dựng gradient tại chỗ, phải lấy ở đây.
class AppGradients {
  /// Nền của mọi màn: xanh rất nhạt ở đỉnh, loang dần về gần trắng.
  ///
  /// Áp một lần ở `MaterialApp.builder` (xem `main.dart`) và
  /// `scaffoldBackgroundColor` để trong suốt, nên mọi màn - kể cả màn được
  /// `push` - đều dùng chung đúng nền này.
  static const page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE6FBF4), Color(0xFFF8FCFB), Color(0xFFF5F9FB)],
    stops: [0, 0.35, 1],
  );

  /// Nút hành động chính ("Tất cả đi làm").
  static const primaryButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.buttonGradientStart,
      AppColors.buttonGradientMid,
      AppColors.buttonGradientEnd,
    ],
    stops: [0, 0.5, 1],
  );
}

class AppTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      // Trong suốt để thấy nền gradient dựng ở MaterialApp.builder.
      scaffoldBackgroundColor: Colors.transparent,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        // Trong suốt để thanh tiêu đề liền một mảng với nền gradient, không
        // thành một dải trắng cắt ngang đầu màn.
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textBody,
        displayColor: AppColors.textDark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.absent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.absent, width: 1.6),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
