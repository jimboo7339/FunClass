import 'package:flutter/material.dart';

/// 应用颜色常量
/// 主色青蓝色系，状态色：pending=灰、attended=绿、skipped=橙
/// 来自Trae
class AppColors {
  AppColors._();

  // ===== 主色（青蓝色系） =====
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);

  // ===== 背景 / 表面 =====
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);

  // ===== 课次状态色 =====
  /// pending = 灰色
  static const Color pending = Color(0xFF9E9E9E);

  /// attended = 绿色
  static const Color attended = Color(0xFF4CAF50);

  /// skipped = 橙色
  static const Color skipped = Color(0xFFFF9800);

  // ===== 成员调色板（用户从中选择） =====
  static const List<Color> memberPalette = [
    Color(0xFFE57373), // 红
    Color(0xFFFFB74D), // 橙
    Color(0xFFFFF176), // 黄
    Color(0xFF81C784), // 绿
    Color(0xFF4FC3F7), // 青
    Color(0xFF7986CB), // 蓝紫
    Color(0xFFBA68C8), // 紫
    Color(0xFFF06292), // 粉
    Color(0xFF4DD0E1), // 蓝绿
    Color(0xFFA1887F), // 棕
  ];
}
