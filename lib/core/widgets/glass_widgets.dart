import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/glass_quality_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_tokens.dart';
import '../theme/liquid_glass_tokens.dart';

/// 液态玻璃效果组件库
/// 使用 BackdropFilter + ImageFilter.blur 实现毛玻璃效果
/// 同时集成 liquid_glass_easy 提供更真实的折射/扭曲液态玻璃效果
/// 来自Trae

/// 液态玻璃浮动按钮（FAB）
/// 液态玻璃模式下：使用 liquid_glass_easy 的 LiquidGlassFab，带折射效果
/// 普通模式下：标准 FAB
/// 来自Trae
class GlassFab extends StatelessWidget {
  const GlassFab({
    super.key,
    required this.onPressed,
    required this.child,
    this.isGlass = false,
    this.backgroundColor,
    this.heroTag = 'glass-fab-default',
  });

  final VoidCallback onPressed;
  final Widget child;
  final bool isGlass;
  final Color? backgroundColor;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = backgroundColor ?? Theme.of(context).colorScheme.primary;
    final tokens = LiquidGlassTokens.of(context);

    if (isGlass) {
      // 使用统一玻璃参数（LiquidGlassTokens），深色下加软阴影提升浮起感——来自Trae
      final fab = LiquidGlassFab(
        onPressed: onPressed,
        size: 56,
        heroTag: heroTag,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        style: tokens.style(cornerRadius: 28),
        child: child,
      );
      if (tokens.bottomShadow.isEmpty) return fab;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: tokens.bottomShadow,
        ),
        child: fab,
      );
    }

    // 普通模式 FAB（带主题色）来自Trae
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: color,
      elevation: 4,
      heroTag: heroTag,
      child: IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: child,
      ),
    );
  }
}

/// 通用玻璃面板（档 2：卡片 / 列表项在玻璃模式下使用）
///
/// 质量跟随 [glassQualityProvider] 自动切换：
/// - full：LiquidGlassLens 折射（液态感最强）
/// - reduced：BackdropFilter 轻量模糊（低端机降级，保留毛玻璃观感、去掉折射扭曲）
/// 来自Trae
class GlassPanel extends ConsumerWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.onTap,
    this.highlight = false,
    this.tint,
    this.tintAlpha = 0.3,
    this.onLongPress,
  });

  final Widget child;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool highlight;

  /// 彩色玻璃染色层（可选，如危险操作的红色玻璃）
  final Color? tint;

  /// 染色层不透明度；按钮这类小元素需要更高的染色浓度才读得出颜色
  final double tintAlpha;

  /// 长按回调（配合 [onTap]，如日期头的「长按回到今天」）
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = LiquidGlassTokens.of(context);
    final quality = ref.watch(glassQualityProvider);
    final radius = BorderRadius.circular(borderRadius);

    Widget content = child;
    if (tint != null) {
      // 彩色玻璃：在折射层上铺一层半透明色——来自Trae
      content = Container(
        decoration: BoxDecoration(
          color: tint!.withValues(alpha: tintAlpha),
          borderRadius: radius,
        ),
        child: child,
      );
    }
    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    // 两档玻璃各成一棵子树，用 320ms 交叉淡化切换：折射"渐显/渐隐"，
    // 硬切树会让玻璃像"啪"地变成液态、观感割裂——来自Trae
    final fullPanel = Container(
      // 玻璃面板的投影放外层，制造悬浮感——来自Trae
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.cardShadow,
      ),
      child: LiquidGlassLens(
        style: tokens.cardStyle(cornerRadius: borderRadius),
        child: content,
      ),
    );
    // 降级路径：轻模糊 + 半透明填充，去掉折射——来自Trae
    final reducedPanel = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.cardFill,
            borderRadius: radius,
            border: Border.all(color: tokens.cardBorder, width: 1),
            boxShadow: tokens.cardShadow,
          ),
          child: content,
        ),
      ),
    );
    Widget panel = AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: quality == GlassQuality.full
          ? KeyedSubtree(
              key: const ValueKey('glass-full'), child: fullPanel,
            )
          : KeyedSubtree(
              key: const ValueKey('glass-reduced'), child: reducedPanel,
            ),
    );

    if (highlight) {
      panel = Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        child: panel,
      );
    }
    return panel;
  }
}

/// 玻璃感知卡片（Material Card 的替代品，调用点 `Card(` → `GlassCard(` 即可）
/// 普通模式：完全等价于 Material Card（cardTheme 纯色 + 阴影）；
/// 玻璃模式：GlassPanel 折射/轻模糊（按性能档位自动切换），color 参数变为染色玻璃
/// 功能逻辑不变，仅外观随玻璃开关自适应——来自Trae
class GlassCard extends ConsumerWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.color,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;

  /// 卡片底色；玻璃模式下作为染色玻璃的色调
  final Color? color;

  /// 玻璃模式下的圆角（普通模式以 cardTheme 为准）
  final double? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isLiquidGlassProvider)) {
      // 普通模式：走统一的卡片层级（圆角/描边/阴影），不再直接用 Card——
      // Card 在渐变背景上没有描边，边界读不出来——2026-10-11
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: AppTokens.cardSurface(context, override: color),
          borderRadius:
              BorderRadius.circular(borderRadius ?? AppTokens.cardRadius),
          border: AppTokens.cardBorder(context),
          boxShadow: AppTokens.cardShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    final panel = GlassPanel(
      borderRadius: borderRadius ?? AppTokens.cardRadius,
      tint: color,
      child: child,
    );
    if (margin != null) {
      return Padding(padding: margin!, child: panel);
    }
    return panel;
  }
}

/// 渐变统计 / 概览大卡
///
/// 用于顶部数据概览（课程概览、上课记录头部等）。
///
/// 设计取舍：玻璃用于「浮层」（卡片、按钮、弹层、导航），大卡里的彩色内容保留实心，
/// 否则白字压在高折射玻璃上会读不清。但这块实心色块必须和玻璃是同一套语言——
/// 所以统一圆角、加一圈玻璃感的亮边描边和顶部高光，让它读起来是「玻璃里的彩色内容」
/// 而不是另一张卡片。玻璃模式下另做降饱和处理，避免和玻璃背景打架。
/// 来自Trae
class GradientStatCard extends ConsumerWidget {
  const GradientStatCard({
    super.key,
    required this.child,
    this.colors,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.margin,
    this.desaturate = true,
    this.shadowColor,
  });

  final Widget child;
  final List<Color>? colors;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  /// 玻璃模式下是否自动降饱和（调用方已自行调过色时关掉）
  final bool desaturate;

  /// 投影色；默认取渐变首色
  final Color? shadowColor;

  /// 保留色相，饱和度压到 45%（向自身灰度色 lerp 55%）
  Color _desaturateColor(Color c) {
    final v = (c.computeLuminance() * 255).round().clamp(0, 255);
    final gray = Color.from(
      red: v / 255,
      green: v / 255,
      blue: v / 255,
      alpha: c.a,
    );
    return Color.lerp(c, gray, 0.55) ?? c;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColors = [
      scheme.primary,
      Color.lerp(scheme.primary, scheme.secondary, 0.5)!,
    ];
    final rawColors = colors ?? defaultColors;
    final isGlass = ref.watch(isLiquidGlassProvider);
    final gradientColors =
        (isGlass && desaturate) ? rawColors.map(_desaturateColor).toList() : rawColors;

    final radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: (shadowColor ?? gradientColors.first)
                .withValues(alpha: isGlass ? 0.18 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // 彩色渐变底
            Container(
              width: double.infinity,
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: child,
            ),
            // 顶部高光：让实心色块也有一层「玻璃感」的受光面——来自Trae
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.16 : 0.24),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.55],
                    ),
                  ),
                ),
              ),
            ),
            // 亮边描边：深色下更明显，浅色下收细
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: isGlass ? (isDark ? 0.30 : 0.38) : 0.22),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玻璃背景层（渐变 + 极淡彩色光斑）
///
/// 纯渐变背景几乎是无色的，玻璃折射时背后没有任何形状/色彩可折，
/// 结果就是一块灰蒙蒙的色块（这也是之前"违和感"的主要来源）。
/// 这里叠两团低透明度径向光斑，给玻璃提供可折射的内容。
/// 来自Trae
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: tokens.backgroundGradient()),
      child: Stack(
        children: [
          // 两团光斑：一冷一暖、位置错开，制造出可被折射的色彩层次
          Positioned(
            top: -140,
            left: -100,
            child: _AuroraBlob(color: tokens.auroraA, size: 360),
          ),
          Positioned(
            top: 120,
            right: -140,
            child: _AuroraBlob(color: tokens.auroraB, size: 420),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// 玻璃按钮（FilledButton / OutlinedButton 的玻璃感知替代品）
///
/// 普通模式回退到 Material 按钮；玻璃模式用染色玻璃面板，
/// [tint] 决定颜色（不传则用主题 primary）。——来自Trae
class GlassButton extends ConsumerWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.tint,
    this.expand = true,
    this.height = 48,
    this.borderRadius = 14,
    this.textStyle,
    this.outlined = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? tint;
  final bool expand;
  final double height;
  final double borderRadius;
  final TextStyle? textStyle;

  /// 描边风格：只描边不填充（用于「未上课」这类次要操作）
  final bool outlined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = tint ?? scheme.primary;
    final foreground = outlined ? color : scheme.onPrimary;
    final style = textStyle ??
        const TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

    if (!ref.watch(isLiquidGlassProvider)) {
      final child = Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(label, style: style.copyWith(color: foreground)),
        ],
      );
      if (expand) {
        return SizedBox(
          width: double.infinity,
          height: height,
          child: outlined
              ? OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(borderRadius)),
                  ),
                  child: child,
                )
              : FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(borderRadius)),
                  ),
                  child: child,
                ),
        );
      }
      return outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius)),
              ),
              child: child,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius)),
              ),
              child: child,
            );
    }

    // 玻璃模式：染色玻璃面板 + 高浓度染色，让按钮读得出颜色
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 6),
        ],
        Text(label, style: style.copyWith(color: foreground)),
      ],
    );

    Widget button = SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: GlassPanel(
        borderRadius: borderRadius,
        onTap: onPressed,
        tintAlpha: outlined ? 0.14 : 0.45,
        tint: color,
        child: Center(child: content),
      ),
    );

    if (outlined) {
      button = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
        ),
        child: button,
      );
    }
    return button;
  }
}

/// 分段控件的一项
class GlassSegmentedItem<T> {
  const GlassSegmentedItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// 玻璃分段控件（SegmentedButton / TabBar / 文字筛选条的玻璃感知替代品）
///
/// 普通模式回退到 Material SegmentedButton；玻璃模式是一条玻璃轨道，
/// 选中项是一枚可滑动的玻璃药丸。——来自Trae
class GlassSegmented<T> extends ConsumerWidget {
  const GlassSegmented({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.position,
    this.height = 40,
    this.borderRadius = 14,
  });

  final List<GlassSegmentedItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  /// 连续位置（0 = 第一项，1.5 = 正滑向第三项的一半）。
  /// 传入后药丸跟着手指实时滑动，而不是等分页动画停稳才跳过去——
  /// 横向滑动 TabBarView 时必须用它，否则内容和按钮明显不同步——来自Trae
  final double? position;

  final double height;
  final double borderRadius;

  int get _selectedIndex {
    final i = items.indexWhere((e) => e.value == value);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    // 有连续位置时以它为准（最近的一项决定高亮和文字），否则退回报的选中值
    final count = items.length;
    final pos = (position ?? _selectedIndex.toDouble())
        .clamp(0.0, (count - 1).toDouble());
    final nearest = pos.round().clamp(0, count - 1);
    final activeValue = items[nearest].value;

    if (!ref.watch(isLiquidGlassProvider)) {
      return SizedBox(
        height: height,
        child: SegmentedButton<T>(
          segments: [
            for (final item in items)
              ButtonSegment<T>(
                value: item.value,
                label: Text(item.label),
                icon: item.icon == null ? null : Icon(item.icon, size: 16),
              ),
          ],
          selected: {activeValue},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 药丸宽度 = 轨道宽度平均分摊，两侧各留 4px 内边距
        const inset = 4.0;
        final slot = (constraints.maxWidth - inset * 2) / count;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              // 轨道
              Positioned.fill(
                child: GlassPanel(
                    borderRadius: borderRadius,
                    tintAlpha: 0.12,
                    tint: scheme.primary,
                    child: const SizedBox.shrink(),
                  ),
              ),
// 选中药丸：跟手实时滑动。文字高亮用最近项（过半就切换），
              // 并把动画压到 160ms——分段控件跟着手指走时，长动画会让文字明显拖在药丸后面。
              // 由 position 驱动时药丸必须完全跟手（不加位移动画，动画来自页面本身），
              // 否则每帧都在追赶上一个目标，看起来是糊的、慢半拍
              AnimatedPositioned(
                duration: position == null
                    ? const Duration(milliseconds: 160)
                    : Duration.zero,
                curve: Curves.easeOut,
                left: inset + slot * pos,
                top: inset,
                bottom: inset,
                width: slot,
                child: GlassPanel(
                  borderRadius: (borderRadius - 4).clamp(4.0, borderRadius),
                  tintAlpha: 0.55,
                  tint: scheme.primary,
                  child: const SizedBox.shrink(),
                ),
              ),
              // 图标 + 文字层
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(items[i].value),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (items[i].icon != null) ...[
                                Icon(
                                  items[i].icon,
                                  size: 16,
                                  color: i == nearest
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                              ],
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 160),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: i == nearest
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: i == nearest
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                                child: Text(items[i].label),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 玻璃小药丸（ChoiceChip / ActionChip 的玻璃感知替代品）
///
/// 普通模式回退到 Material FilterChip；玻璃模式下是一枚小玻璃药丸，
/// 选中时染主题色、未选中时只有一圈浅边——来自Trae
class GlassChip extends ConsumerWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.tint,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = tint ?? scheme.primary;
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    if (!ref.watch(isLiquidGlassProvider)) {
      return FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onTap == null ? null : (_) => onTap!(),
        avatar: icon == null ? null : Icon(icon, size: 16),
      );
    }

    final pill = GlassPanel(
      borderRadius: 999,
      tintAlpha: selected ? 0.5 : 0.1,
      tint: color,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );

    if (selected) return pill;
    // 未选中态加一圈浅边，否则在玻璃上完全读不出这是一个可点的药丸
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: pill,
    );
  }
}

/// 玻璃底部弹层表面
///
/// 普通模式：贴底、只圆上角（与原实现一致）。
/// 玻璃模式：改成悬浮玻璃片（四角圆角 + 四周留白），和悬浮的 TabBar / FAB 同一套语言。
/// 之所以用悬浮而不是贴底，是因为镜片形状只有统一圆角，贴底会让下方两角也变圆、
/// 露出背景色缺口。功能逻辑不变，仅外观随玻璃开关自适应。——来自Trae
class GlassSheetSurface extends ConsumerWidget {
  const GlassSheetSurface({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.cornerRadius = 28,
  });

  final Widget child;
  final EdgeInsets margin;
  final double cornerRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    if (!ref.watch(isLiquidGlassProvider)) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: child,
      );
    }

    final tokens = LiquidGlassTokens.of(context);
    final quality = ref.watch(glassQualityProvider);
    final radius = BorderRadius.circular(cornerRadius);

    // 两档交叉淡化切换，同 GlassPanel——避免折射"啪"地出现——来自Trae
    final fullSurface = LiquidGlassLens(
      style: tokens.sheetStyle(cornerRadius: cornerRadius),
      child: child,
    );
    // 降级：折射换成轻模糊，保留半透明填充与描边
    final reducedSurface = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.cardBlurSigma,
          sigmaY: tokens.cardBlurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.sheetFill,
            borderRadius: radius,
            border: Border.all(color: tokens.sheetBorder),
          ),
          child: child,
        ),
      ),
    );
    Widget surface = AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: quality == GlassQuality.full
          ? KeyedSubtree(
              key: const ValueKey('sheet-full'), child: fullSurface,
            )
          : KeyedSubtree(
              key: const ValueKey('sheet-reduced'), child: reducedSurface,
            ),
    );

    return Padding(
      padding: margin + MediaQuery.paddingOf(context),
      child: surface,
    );
  }
}

/// 液态玻璃相关组件（LiquidGlassScaffold 自研包装已移除，
/// 玻璃效果统一由 GlassFab + HomeShell 的 LiquidGlassTabBar 输出）来自Trae
