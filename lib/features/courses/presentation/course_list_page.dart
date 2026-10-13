import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/help/help_topics.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/adaptive_card.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/page_shell.dart';
import '../../../core/widgets/settings_gear_button.dart';
import '../../../data/database/app_database.dart';
import '../providers/course_providers.dart';
import '../../members/providers/member_providers.dart';
import '../../shared/providers/lesson_providers.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_scroll_view.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import 'course_edit_page.dart';
import 'course_share_sheet.dart';
import 'course_timeline_page.dart';

/// 课程管理列表页
class CourseListPage extends ConsumerWidget {
  const CourseListPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(coursesWithStatsProvider);
    ref.invalidate(monthlyAttendedCountProvider);
    ref.invalidate(membersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesWithStatsProvider);
    final membersAsync = ref.watch(membersProvider);
    final monthlyAsync = ref.watch(monthlyAttendedCountProvider);

    return PageShell(
      title: '课程',
      actions: [
        const HelpButton(topic: HelpTopics.courses),
        buildSettingsGear(context),
      ],
      floatingActionButton: GlassFab(
        isGlass: ref.watch(appThemeProvider).isLiquidGlass,
        heroTag: 'fab-course',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CourseEditPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (courses) {
          final memberMap = <int, Member>{
            for (final m in (membersAsync.valueOrNull ?? [])) m.id: m,
          };

          final totalSpent =
              courses.fold<double>(0, (sum, c) => sum + c.course.totalAmount);
          final monthlyAttended = monthlyAsync.valueOrNull ?? 0;
          final activeCount = courses.where((c) {
            final validTo = c.course.validTo;
            return isPermanentValidTo(validTo) ||
                validTo.isAfter(DateTime.now());
          }).length;

          return AppScrollView(
            onRefresh: () => _refresh(ref),
            children: [
              GradientStatCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '课程概览',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _summaryItem('本月已上', '$monthlyAttended', '节'),
                        _divider(),
                        _summaryItem('在读课程', '$activeCount', '门'),
                        _divider(),
                        _summaryItem(
                          '总投入',
                          '¥${totalSpent.toStringAsFixed(0)}',
                          '',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (courses.isEmpty)
                EmptyStateView(
                  icon: Icons.menu_book_outlined,
                  title: '还没有课程',
                  subtitle: '添加第一门课外兴趣课，开始记录吧',
                  actionLabel: '添加课程',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CourseEditPage()),
                  ),
                )
              else
                ..._buildGroups(context, ref, courses, memberMap),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildGroups(
    BuildContext context,
    WidgetRef ref,
    List<CourseWithStats> courses,
    Map<int, Member> memberMap,
  ) {
    final grouped = <int, List<CourseWithStats>>{};
    for (final c in courses) {
      grouped.putIfAbsent(c.course.memberId, () => []).add(c);
    }
    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      final member = memberMap[entry.key];
      widgets.add(
        SectionHeader(
          title: member?.name ?? '未知成员',
          subtitle: '${entry.value.length} 门课程',
          trailing: CircleAvatar(
            radius: 14,
            backgroundColor: ColorHex.fromHex(
              member?.colorTag ?? AppColors.primary.toHex(),
            ),
            child: Text(
              member?.name.characters.first ?? '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
      for (final cs in entry.value) {
        widgets.add(_CourseCard(
          stats: cs,
          memberName: member?.name ?? '未知成员',
        ));
        widgets.add(const SizedBox(height: 12));
      }
    }
    return widgets;
  }

  Widget _summaryItem(String label, String value, String unit) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.25),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.stats, required this.memberName});

  final CourseWithStats stats;
  final String memberName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = stats.course;
    final color = course.colorTag != null
        ? ColorHex.fromHex(course.colorTag!)
        : AppColors.primary;
    final validToText = isPermanentValidTo(course.validTo)
        ? '永久'
        : DateUtilsTool.formatDate(course.validTo);
    final daysLeft = isPermanentValidTo(course.validTo)
        ? null
        : course.validTo.difference(DateTime.now()).inDays;
    final progress = stats.progress.clamp(0.0, 1.0);
    final unitPrice = stats.unitPrice;

    return Dismissible(
      key: ValueKey('course-${course.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return showConfirmSheet(
          context,
          title: '删除课程',
          message: '确定删除"${course.name}"吗？\n该课程下所有上课记录也会一起删除，且无法恢复。',
          confirmLabel: '删除',
          destructive: true,
        );
      },
      onDismissed: (_) {
        ref.read(courseActionsProvider).delete(course.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除课程')),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: AdaptiveCard(
        onTap: () {
          // 卡片点击 → 时间轴页面（查看课次记录）——来自Trae
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CourseTimelinePage(courseId: course.id),
            ),
          );
        },
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.book_outlined, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¥${course.totalAmount.toStringAsFixed(0)} · 共 ${course.totalLessons} 节',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 5,
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _infoChip(
                  Icons.check_circle_outline,
                  '${stats.attendedCount}/${course.totalLessons} 节',
                  color,
                ),
                _infoChip(
                  Icons.attach_money,
                  '均价 ¥${unitPrice.toStringAsFixed(1)}',
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                _infoChip(
                  Icons.event_outlined,
                  '截止 $validToText',
                  (daysLeft != null && daysLeft < 30 && daysLeft >= 0)
                      ? Colors.orange
                      : (daysLeft != null && daysLeft < 0
                          ? Colors.red
                          : Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: '记一节',
                    icon: Icons.check,
                    tint: color,
                    expand: true,
                    height: 46,
                    onPressed: () => _markLesson(context, ref, course),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _showMoreActions(context, ref, course),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markLesson(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    HapticFeedback.lightImpact();
    final count =
        await ref.read(lessonActionsProvider).markNextPendingAttended(course.id);
    if (!context.mounted) return;
    if (count > 0) {
      showUndoSnackBar(
        context,
        message: '已记录 $count 节课',
        onUndo: () {},
      );
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已记录 $count 节课'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '查看今日',
            onPressed: () {
              ref.read(currentTabProvider.notifier).state = 0;
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有待上的课次了')),
      );
    }
  }

  Future<void> _showMoreActions(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    await showAppBottomSheet<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 查看时间轴（课程卡片默认跳转页，这里也放一个入口）——来自Trae
          ListTile(
            leading: const Icon(Icons.timeline_outlined),
            title: const Text('查看课次记录'),
            subtitle: Text('${stats.attendedCount}/${course.totalLessons} 节'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourseTimelinePage(courseId: course.id),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑课程'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourseEditPage(courseId: course.id),
                ),
              );
            },
          ),
          // 导出/分享：生成课时进度卡片图（已上 / 剩余，不展示待上）——来自Trae
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('分享课时图'),
            subtitle: Text('${stats.attendedCount} 已上 · ${stats.remaining} 剩余'),
            onTap: () {
              Navigator.pop(context);
              showCourseShareSheet(
                context,
                course: course,
                memberName: memberName,
                attendedCount: stats.attendedCount,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.check),
            title: const Text('记一节'),
            onTap: () {
              Navigator.pop(context);
              _markLesson(context, ref, course);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
            title: Text('删除', style: TextStyle(color: Colors.red.shade700)),
            onTap: () async {
              Navigator.pop(context);
              final ok = await showConfirmSheet(
                context,
                title: '删除课程',
                message: '确定删除"${course.name}"吗？\n该课程下所有上课记录也会一起删除，且无法恢复。',
                confirmLabel: '删除',
                destructive: true,
              );
              if (ok && context.mounted) {
                await ref.read(courseActionsProvider).delete(course.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除课程')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
