import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';
import 'page_transitions.dart';

/// 趣课应用主题（Material 3）
class AppTheme {
  AppTheme._();

  static const _bgLight = Color(0xFFF8F9FB);
  static const _bgLightSurface = Color(0xFFFFFFFF);
  static const _bgDark = Color(0xFF111214);
  static const _bgDarkSurface = Color(0xFF18191C);

  static ThemeData build(Brightness brightness, Color seedColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;
    final scaffoldBg = isDark ? _bgDark : _bgLight;
    final surfaceBg = isDark ? _bgDarkSurface : _bgLightSurface;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      // 二级页转场换成「无遮罩 + 不缩放」的淡入，见 page_transitions.dart。
      // 玻璃页面上满屏 BackdropFilter 每帧重模糊是卡顿主因，缩放还会让旧页面变暗——来自Trae
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: GlassFriendlyTransitions(),
          TargetPlatform.fuchsia: GlassFriendlyTransitions(),
          TargetPlatform.linux: GlassFriendlyTransitions(),
          TargetPlatform.windows: GlassFriendlyTransitions(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: isDark ? Colors.white : const Color(0xDE000000),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        // 必须显式指定：AppBar 默认按 backgroundColor 的亮度推状态栏图标颜色，
        // 而玻璃模式下标题栏背景是 transparent（被当成黑色），浅色主题下
        // 状态栏图标会一直是白色的、糊在浅背景上看不清——来自Trae
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xDE000000),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          // 卡片浮在渐变背景上，纯白无边框会糊成一片——2026-10-11
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: seedColor.withValues(alpha: 0.15),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seedColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, AppTokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppTokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return seedColor;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return seedColor.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: seedColor,
        thumbColor: seedColor,
        overlayColor: seedColor.withValues(alpha: 0.2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: false, // 全局关掉默认外层 handle，自己在内容里画——来自Trae
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.sheetRadius),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
      ),
    );
  }
}
