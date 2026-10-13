import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/widgets/glass_widgets.dart';

/// 统一底部弹层容器（圆角 + 拖拽手柄 + SafeArea）
///
/// 玻璃模式下整块弹层换成悬浮玻璃片（GlassSheetSurface），
/// 一次改动即可让所有走本包装的弹层统一为玻璃质感。——来自Trae
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Consumer(
        builder: (context, ref, _) {
          final isGlass = ref.watch(isLiquidGlassProvider);
          final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

          Widget handle() => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );

          if (isGlass) {
            // GlassSheetSurface 自己处理底部安全区，这里不再包 SafeArea，避免留白叠加
            return GlassSheetSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showDragHandle) handle(),
                  Flexible(child: child),
                ],
              ),
            );
          }

          return SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showDragHandle) handle(),
                  Flexible(child: child),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}