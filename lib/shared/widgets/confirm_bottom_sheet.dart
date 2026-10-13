import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_bottom_sheet.dart';
import '../../core/widgets/glass_widgets.dart';

/// 移动端确认弹层（替代 AlertDialog）
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final result = await showAppBottomSheet<bool>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // 确认/取消都走玻璃按钮：弹层本身已经是玻璃面，按钮再用实心 Material
          // 会在同一屏里出现两种材质——来自Trae
          GlassButton(
            label: confirmLabel,
            expand: true,
            height: 48,
            borderRadius: 16,
            tint: destructive ? Colors.red : Theme.of(context).colorScheme.primary,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context, true);
            },
          ),
          const SizedBox(height: 8),
          GlassButton(
            label: cancelLabel,
            expand: true,
            height: 48,
            borderRadius: 16,
            outlined: true,
            tint: Theme.of(context).colorScheme.primary,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// 纯信息告知弹层（替代 AlertDialog）
/// 和 [showConfirmSheet] 一样走玻璃弹层，只有一枚「知道了」按钮——来自Trae
Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '知道了',
}) {
  return showAppBottomSheet<void>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          GlassButton(
            label: confirmLabel,
            expand: true,
            height: 48,
            borderRadius: 16,
            tint: Theme.of(context).colorScheme.primary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
