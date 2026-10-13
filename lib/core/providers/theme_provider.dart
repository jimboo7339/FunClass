import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式 来自Trae
enum ThemeModeType {
  /// 白色模式
  light,

  /// 暗色模式
  dark,

  /// 跟随系统
  system,
}

/// 主题状态 来自Trae
///
/// [seedColor] 是全局强调色：它决定 Material 的 primary 体系，也决定玻璃背景的
/// 极光色、按钮 / 分段控件 / 选中态等通用颜色的基色。
/// 它**不会**影响课程色、成员色标这类「内容色」——那些是用户自己挑的，
/// 本来就该独立于主题。深浅模式镜像保留——来自Trae
class ThemeState {
  final ThemeModeType mode;
  final Color seedColor;
  final bool isLiquidGlass;
  final bool isFloatingNav;

  const ThemeState({
    this.mode = ThemeModeType.system,
    this.seedColor = defaultSeedColor,
    this.isLiquidGlass = false,
    this.isFloatingNav = true,
  });

  /// 默认强调色（原来的主题蓝）
  static const Color defaultSeedColor = Color(0xFF2196F3);

  /// 设置页提供的强调色候选
  static const List<Color> accentPalette = [
    Color(0xFF2196F3), // 蓝
    Color(0xFF5C6BC0), // 靛
    Color(0xFF009688), // 青
    Color(0xFF43A047), // 绿
    Color(0xFFFB8C00), // 琥珀
    Color(0xFFE64A19), // 橙红
    Color(0xFFD81B60), // 玫红
    Color(0xFF8E24AA), // 紫
  ];

  ThemeState copyWith({
    ThemeModeType? mode,
    Color? seedColor,
    bool? isLiquidGlass,
    bool? isFloatingNav,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
      isLiquidGlass: isLiquidGlass ?? this.isLiquidGlass,
      isFloatingNav: isFloatingNav ?? this.isFloatingNav,
    );
  }
}

/// 主题 Provider（持久化到 SharedPreferences）来自Trae
class AppThemeNotifier extends StateNotifier<ThemeState> {
  static const _keyMode = 'theme_mode';
  static const _keySeed = 'theme_seed_color'; // 强调色 来自Trae
  static const _keyFloatingNav = 'theme_floating_nav'; // 悬浮导航开关 来自Trae

  AppThemeNotifier() : super(const ThemeState());

  /// 从磁盘加载持久化的主题设置（强调色 + 悬浮导航）来自Trae
  /// 液态玻璃效果已下线：磁盘里残留的开关值直接忽略，isLiquidGlass 恒为 false
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_keyMode) ?? 0;
    final floatingNav = prefs.getBool(_keyFloatingNav) ?? true;
    final seed = prefs.getInt(_keySeed);
    state = ThemeState(
      mode: ThemeModeType.values[modeIndex],
      seedColor: seed == null
          ? ThemeState.defaultSeedColor
          : Color(seed),
      isFloatingNav: floatingNav,
    );
  }

  /// 切换主题模式
  Future<void> setMode(ThemeModeType mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMode, mode.index);
    state = state.copyWith(mode: mode);
  }

  /// 切换全局强调色（持久化到磁盘）
  /// 会连锁更新 primary 体系、玻璃极光色以及所有通用控件的着色——来自Trae
  Future<void> setSeedColor(Color color) async {
    if (state.seedColor.toARGB32() == color.toARGB32()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeed, color.toARGB32());
    state = state.copyWith(seedColor: color);
  }

  /// 切换悬浮导航（开 = 悬浮导航栏，关 = 贴底标准导航栏；持久化到磁盘）来自Trae
  Future<void> setFloatingNav(bool enabled) async {
    if (state.isFloatingNav == enabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFloatingNav, enabled);
    state = state.copyWith(isFloatingNav: enabled);
  }
}

/// 主题 Provider 来自Trae
final appThemeProvider =
    StateNotifierProvider<AppThemeNotifier, ThemeState>((ref) {
  return AppThemeNotifier();
});

/// 是否液态玻璃模式（便捷读取）来自Trae
///
/// 液态玻璃效果已整体下线，此 Provider 恒为 false——
/// 玻璃系组件（GlassPanel 等）全部走普通回退分支，保留是为不改动各组件的取数点
final isLiquidGlassProvider = Provider<bool>((ref) => false);

/// 是否悬浮导航（开 = 悬浮导航栏，关 = 贴底标准导航栏；便捷读取）来自Trae
final isFloatingNavProvider = Provider<bool>((ref) {
  return ref.watch(appThemeProvider).isFloatingNav;
});
