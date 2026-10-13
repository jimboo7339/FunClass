import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../features/members/providers/member_providers.dart';
import '../../features/shared/providers/lesson_providers.dart';
import 'app_bottom_sheet.dart';
import 'confirm_bottom_sheet.dart';
import 'undo_snackbar.dart';

/// 课次卡片（含滑动打卡 + 状态操作）
class LessonCard extends ConsumerWidget {
  const LessonCard({
    super.key,
    required this.item,
    this.showStatusButtons = true,
    required this.onStatusTap,
    this.onDelete,
    this.highlight = false,
  });

  final LessonWithCourse item;
  final bool showStatusButtons;
  final void Function(LessonStatus status) onStatusTap;
  final VoidCallback? onDelete;
  final bool highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = item.lesson;
    final course = item.course;
    final color = course.colorTag != null
        ? ColorHex.fromHex(course.colorTag!)
        : AppColors.primary;

    // 用 Dart 3 switch 表达式，确保所有分支都有返回值——来自Trae
    final statusColor = switch (lesson.status) {
      LessonStatus.attended => AppColors.attended,
      LessonStatus.skipped => AppColors.skipped,
      LessonStatus.pending => AppColors.pending,
    };

    Widget card = AdaptiveCardWrapper(
      highlight: highlight,
      // 已上/未上给极淡的状态底色，一屏扫过去就知道哪几节已经处理过；
      // 待上保持中性白，免得整屏泛绿——2026-10-11
      tint: lesson.status == LessonStatus.pending
          ? null
          : Color.alphaBlend(
              AppTokens.statusTint(context, statusColor),
              AppTokens.cardSurface(context),
            ),
      child: _LessonCardContent(
        item: item,
        color: color,
        statusColor: statusColor,
        showStatusButtons: showStatusButtons,
        onStatusTap: onStatusTap,
        onDelete: onDelete,
        onShowActions: () => _showStatusActions(context, lesson.status, ref),
      ),
    );

    if (showStatusButtons && lesson.status == LessonStatus.pending) {
      card = Dismissible(
        key: ValueKey('lesson-${lesson.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          HapticFeedback.mediumImpact();
          if (direction == DismissDirection.startToEnd) {
            final prev = lesson.status;
            onStatusTap(LessonStatus.attended);
            if (context.mounted) {
              showUndoSnackBar(
                context,
                message: '已标记为上课',
                onUndo: () => onStatusTap(prev),
              );
            }
          } else {
            // 未上课 = 这节不上了但不占课时，排程器会在计划末尾自动补一节（顺延）——来自Trae
            final prev = lesson.status;
            onStatusTap(LessonStatus.skipped);
            if (context.mounted) {
              showUndoSnackBar(
                context,
                message: '已标记为未上课，后续自动补一节',
                onUndo: () => onStatusTap(prev),
              );
            }
          }
          return false;
        },
        background: _SwipeBackground(
          icon: Icons.check,
          label: '已上课',
          color: AppColors.attended,
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _SwipeBackground(
          icon: Icons.close,
          label: '未上课',
          color: AppColors.skipped,
          alignment: Alignment.centerRight,
        ),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: card,
    );
  }

  Future<void> _showStatusActions(
    BuildContext context,
    LessonStatus current,
    WidgetRef ref,
  ) async {
    await showAppBottomSheet<void>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('编辑备注'),
              subtitle: item.lesson.note != null && item.lesson.note!.isNotEmpty
                  ? Text(item.lesson.note!,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : const Text('点击添加备注'),
              onTap: () async {
                Navigator.pop(context);
                await _editNote(context, ref);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('标记已上课'),
              subtitle: const Text('消耗一节，按计划继续'),
              onTap: () {
                Navigator.pop(context);
                onStatusTap(LessonStatus.attended);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('标记未上课'),
              subtitle: const Text('这节不算上了，计划末尾自动补一节'),
              onTap: () {
                Navigator.pop(context);
                onStatusTap(LessonStatus.skipped);
              },
            ),
            if (current != LessonStatus.pending)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('撤销为待上课'),
                onTap: () {
                  Navigator.pop(context);
                  onStatusTap(LessonStatus.pending);
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                title: Text('删除', style: TextStyle(color: Colors.red.shade700)),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showConfirmSheet(
                    context,
                    title: '删除课次',
                    message: '确定删除这条记录吗？',
                    confirmLabel: '删除',
                    destructive: true,
                  );
                  if (ok && context.mounted) onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 编辑课次备注（弹出玻璃弹层）——来自Trae
  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final lesson = item.lesson;
    final controller = TextEditingController(text: lesson.note ?? '');
    final scheme = Theme.of(context).colorScheme;
    final saved = await showAppBottomSheet<String>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '课次备注',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '记下这次上课的情况，比如：表现好、请假、迟到…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: '保存',
              expand: true,
              height: 48,
              borderRadius: 16,
              tint: scheme.primary,
              onPressed: () => Navigator.pop(context, controller.text),
            ),
            if (lesson.note != null && lesson.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: '清除',
                      expand: true,
                      height: 48,
                      borderRadius: 16,
                      outlined: true,
                      tint: scheme.error,
                      onPressed: () => Navigator.pop(context, ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GlassButton(
                      label: '取消',
                      expand: true,
                      height: 48,
                      borderRadius: 16,
                      outlined: true,
                      tint: scheme.primary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == null || !context.mounted) return;
    final note = saved.trim().isEmpty ? null : saved.trim();
    await ref.read(lessonActionsProvider).updateNote(lesson.id, note);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('备注已保存')),
      );
    }
  }
}

class AdaptiveCardWrapper extends ConsumerWidget {
  const AdaptiveCardWrapper({
    super.key,
    required this.child,
    this.highlight = false,
    this.tint,
  });

  final Widget child;
  final bool highlight;

  /// 底色偏色（课次卡按状态给极淡的绿/橘底）——2026-10-11
  final Color? tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // 玻璃模式走 GlassPanel（折射/轻模糊按性能档位切换）——来自Trae
    if (ref.watch(isLiquidGlassProvider)) {
      return GlassPanel(
        borderRadius: AppTokens.cardRadius,
        highlight: highlight,
        child: child,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppTokens.cardSurface(context, override: tint),
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: highlight
            ? Border.all(color: scheme.primary, width: 2)
            : AppTokens.cardBorder(context),
        boxShadow: AppTokens.cardShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        child: child,
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignment,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _LessonCardContent extends ConsumerWidget {
  const _LessonCardContent({
    required this.item,
    required this.color,
    required this.statusColor,
    required this.showStatusButtons,
    required this.onStatusTap,
    this.onDelete,
    required this.onShowActions,
  });

  final LessonWithCourse item;
  final Color color;
  final Color statusColor;
  final bool showStatusButtons;
  final void Function(LessonStatus status) onStatusTap;
  final VoidCallback? onDelete;
  final VoidCallback onShowActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = item.lesson;
    final course = item.course;
    final scheme = Theme.of(context).colorScheme;
    final memberAsync = ref.watch(memberProvider(course.memberId));
    final member = memberAsync.valueOrNull;
    final memberColor =
        member != null ? ColorHex.fromHex(member.colorTag) : null;

    return InkWell(
      onTap: lesson.status != LessonStatus.pending ? onShowActions : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lesson.startTime} - ${lesson.endTime}'
                        '${lesson.isExtra ? '  ·  加课' : ''}'
                        '${lesson.note != null && lesson.note!.isNotEmpty ? '  ·  ${lesson.note}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onShowActions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      lesson.status.label,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (member != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: memberColor ?? Colors.grey,
                      child: Text(
                        member.name.characters.first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            // 待上课课次的两个动作：已上课（消耗一节、按计划走）/
            // 未上课（不占课时、排程器尾部自动补一节顺延）——来自Trae
            if (showStatusButtons && lesson.status == LessonStatus.pending)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: '已上课',
                        icon: Icons.check,
                        tint: AppColors.attended,
                        expand: true,
                        height: 44,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onStatusTap(LessonStatus.attended);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        label: '未上课',
                        icon: Icons.close,
                        tint: AppColors.skipped,
                        expand: true,
                        height: 44,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onStatusTap(LessonStatus.skipped);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
