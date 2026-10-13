import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../theme/app_tokens.dart';
import 'glass_widgets.dart';

/// 双模式卡片
/// 玻璃模式：走 GlassPanel（折射 / 轻模糊按性能档位自动切换）；
/// 普通模式：主题 surface 纯色，与今日页/统计页的卡片保持一致——来自Trae
class AdaptiveCard extends ConsumerWidget {
  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = AppTokens.cardRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGlass = ref.watch(isLiquidGlassProvider);
    final content = Padding(padding: padding, child: child);

    Widget card;
    if (isGlass) {
      card = GlassPanel(
        borderRadius: borderRadius,
        onTap: onTap,
        child: content,
      );
    } else {
      card = Container(
        decoration: BoxDecoration(
          color: AppTokens.cardSurface(context),
          borderRadius: BorderRadius.circular(borderRadius),
          // 描边 + 柔和投影：卡片浮在渐变背景上，纯白无边界会糊成一片——2026-10-11
          border: AppTokens.cardBorder(context),
          boxShadow: AppTokens.cardShadow(context),
        ),
        child: content,
      );
      if (onTap != null) {
        card = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: card,
          ),
        );
      }
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }
    return card;
  }
}
