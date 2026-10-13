import 'package:flutter/material.dart';

/// 全局 Design Tokens（间距、圆角、触控尺寸、动画）
class AppTokens {
  AppTokens._();

  static const pagePaddingH = 16.0;
  static const pagePaddingTop = 12.0;
  static const sectionGap = 16.0;
  static const itemGap = 12.0;
  static const cardRadius = 20.0;
  static const sheetRadius = 24.0;
  static const minTouchTarget = 48.0;
  static const bottomNavClearance = 88.0;

  static const animFast = Duration(milliseconds: 200);
  static const animNormal = Duration(milliseconds: 300);

  // ===== 卡片层级：底色 / 描边 / 阴影 / 状态色偏 =====
  // 以前各页面各写一套（有的纯白无描边、有的带影），同一屏里层级读不出来。
  // 现在统一从下面四个方法取，页面里不要再硬编码圆角/阴影——2026-10-11

  /// 卡片底色：浅色纯白（浮在渐变背景上），深色用高一档的表面色
  static Color cardSurface(BuildContext context, {Color? override}) {
    if (override != null) return override;
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(context).brightness == Brightness.dark
        ? scheme.surfaceContainerLow
        : scheme.surface;
  }

  /// 1px 发丝描边：不给重阴影也能把卡片从渐变背景上"切"出来
  static Border cardBorder(BuildContext context, {double width = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55);
    return Border.all(color: color, width: width);
  }

  /// 柔和投影；深色下靠底色+描边分层，不再叠影（深色阴影几乎看不见还显脏）
  static List<BoxShadow> cardShadow(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return const [];
    }
    return const [
      BoxShadow(color: Color(0x0F1B2A44), blurRadius: 18, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x081B2A44), blurRadius: 3, offset: Offset(0, 1)),
    ];
  }

  /// 课次卡的状态底色偏：已上淡绿 / 未上淡橘 / 待上不染色
  static Color statusTint(BuildContext context, Color statusColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return statusColor.withValues(alpha: isDark ? 0.13 : 0.10);
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(
      pagePaddingH,
      pagePaddingTop,
      pagePaddingH,
      bottomNavClearance + bottom,
    );
  }

  static EdgeInsets pagePaddingWithoutNav(BuildContext context) {
    return EdgeInsets.fromLTRB(
      pagePaddingH,
      pagePaddingTop,
      pagePaddingH,
      MediaQuery.paddingOf(context).bottom + 16,
    );
  }
}
