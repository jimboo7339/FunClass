import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/help/help_topics.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/page_shell.dart';
import '../../../core/widgets/settings_gear_button.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../courses/providers/course_providers.dart';
import '../../members/providers/member_providers.dart';
import '../../shared/providers/lesson_providers.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/widgets/app_scroll_view.dart';
import '../../../shared/widgets/calendar_lesson_marker.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../shared/widgets/lesson_card.dart';
import '../../../shared/widgets/modern_picker.dart';
import '../../../shared/widgets/section_header.dart';

/// 今日/待办页
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  static Future<void> openDatePicker(
    BuildContext context,
    WidgetRef ref, {
    DateTime? initialDate,
  }) async {
    final initial = initialDate ??
        DateUtilsTool.dateOnly(ref.read(todaySelectedDateProvider));
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DatePickerSheet(initialDate: initial),
    );
    if (picked != null && context.mounted) {
      ref.read(todaySelectedDateProvider.notifier).state =
          DateUtilsTool.dateOnly(picked);
    }
  }

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  /// 点击过期提醒条后高亮定位的那节课（1.5s 后自动清除）——来自Trae
  int? _highlightLessonId;

  Future<void> _refresh() async {
    ref.invalidate(lessonsByDateProvider);
    ref.invalidate(overduePendingProvider);
    ref.invalidate(expiringCoursesProvider);
    ref.invalidate(membersProvider);
  }

  void _changeDate(int days) {
    HapticFeedback.selectionClick();
    final current = ref.read(todaySelectedDateProvider);
    ref.read(todaySelectedDateProvider.notifier).state =
        DateUtilsTool.dateOnly(current.add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate =
        DateUtilsTool.dateOnly(ref.watch(todaySelectedDateProvider));
    final todayLessons = ref.watch(lessonsByDateProvider(selectedDate));
    final overdue = ref.watch(overduePendingProvider);
    final expiring = ref.watch(expiringCoursesProvider);
    final membersAsync = ref.watch(membersProvider);
    final memberMap = <int, String>{};
    membersAsync.whenData((ms) {
      for (final m in ms) {
        memberMap[m.id] = m.name;
      }
    });

    return PageShell(
      title: '今日',
      actions: [
        const HelpButton(topic: HelpTopics.today),
        buildSettingsGear(context),
      ],
      body: AppScrollView(
        onRefresh: _refresh,
        children: [
          _DateHeader(
            date: selectedDate,
            onTap: () => TodayPage.openDatePicker(context, ref),
            onPrev: () => _changeDate(-1),
            onNext: () => _changeDate(1),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              ref.read(todaySelectedDateProvider.notifier).state =
                  DateUtilsTool.dateOnly(DateTime.now());
            },
          ),
          const SizedBox(height: 12),
          // 加一节补录按钮：为当前选中日期补记一节课——来自Trae
          _AddLessonButton(date: selectedDate),
          const SizedBox(height: 12),
          // 过期未处理提醒条：到点了还没记「已上/未上」的课，点了才消停——来自Trae
          overdue.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return _OverdueReminder(
                count: items.length,
                onTap: () {
                  final target =
                      DateUtilsTool.dateOnly(items.first.lesson.date);
                  ref.read(todaySelectedDateProvider.notifier).state = target;
                  setState(() {
                    _highlightLessonId = items.first.lesson.id;
                  });
                  Future.delayed(const Duration(milliseconds: 1500), () {
                    if (mounted) setState(() => _highlightLessonId = null);
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          expiring.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return _ExpiringReminder(items: items);
            },
          ),
          if (expiring.valueOrNull != null && expiring.valueOrNull!.isNotEmpty)
            const SizedBox(height: 16),
          todayLessons.when(
            loading: () =>
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.free_breakfast_outlined,
                  title: '今天没有课',
                  subtitle: '好好休息，或切换日期查看其他安排',
                );
              }
              final grouped = <int, List<LessonWithCourse>>{};
              for (final i in items) {
                grouped.putIfAbsent(i.course.memberId, () => []).add(i);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: memberMap[entry.key] ?? '成员 #${entry.key}',
                        subtitle: '${entry.value.length} 节课',
                      ),
                      ...entry.value.map((item) => LessonCard(
                            item: item,
                            highlight: item.lesson.id == _highlightLessonId,
                            onStatusTap: (status) => ref
                                .read(lessonActionsProvider)
                                .updateStatus(item.lesson.id, status),
                            onDelete: () => ref
                                .read(lessonActionsProvider)
                                .deleteLesson(item.lesson.id),
                          )),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 过期未处理提醒条：点一下定位到最晚那节没记的课，去标「已上课」或「未上课」——来自Trae
class _OverdueReminder extends StatelessWidget {
  const _OverdueReminder({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.skipped.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.skipped.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppColors.skipped),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '有 $count 节课已结束还没记「已上/未上」，点击处理',
                style: const TextStyle(
                  color: AppColors.skipped,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.skipped),
          ],
        ),
      ),
    );
  }
}

class _ExpiringReminder extends ConsumerWidget {
  const _ExpiringReminder({required this.items});
  final List<ExpiringCourse> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom, color: Colors.deepOrange),
              const SizedBox(width: 10),
              const Text(
                '有效期临近',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} 门课',
                style: const TextStyle(color: Colors.deepOrange),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${e.course.name}（${e.memberName}）',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      e.daysRemaining == 0
                          ? '今天到期'
                          : '还剩 ${e.daysRemaining} 天',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: e.daysRemaining <= 7
                            ? Colors.red
                            : Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );

    // 玻璃模式：橙色染色玻璃告警卡；普通模式保留原来的淡橙底+描边——来自Trae
    if (ref.watch(isLiquidGlassProvider)) {
      return GlassPanel(
        borderRadius: AppTokens.cardRadius,
        tintAlpha: 0.16,
        tint: Colors.deepOrange,
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.4)),
      ),
      child: Padding(padding: EdgeInsets.zero, child: content),
    );
  }
}

/// "加一节"补录按钮：为当前选中日期（支持任意日期）补记一节课——来自Trae
class _AddLessonButton extends ConsumerWidget {
  const _AddLessonButton({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassButton(
      label: '加一节（${date.month}月${date.day}日）',
      icon: Icons.add,
      expand: true,
      height: 50,
      onPressed: () => _openPicker(context, ref),
    );
  }

  /// 弹出课程选择面板，选中后为指定日期补录已上课——来自Trae
  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;
    final courses = await ref.read(coursesProvider.future);
    if (!context.mounted) return;
    if (courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加课程')),
      );
      return;
    }

    final members = await ref.read(membersProvider.future);
    if (!context.mounted) return;
    final memberMap = {for (final m in members) m.id: m.name};

    // ModernPickerSheet 内部 onTap 已经会 Navigator.pop，这里不能再 pop，否则会把当前页也弹掉——来自Trae
    Course? picked;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ModernPickerSheet<Course>(
        title: '选择课程',
        items: courses,
        selectedValue: null,
        itemLabel: (c) => c.name,
        secondaryLabel: (c) => memberMap[c.memberId] ?? '',
        leadingWidget: (c) => CircleAvatar(
          radius: 18,
          backgroundColor: c.colorTag != null
              ? ColorHex.fromHex(c.colorTag!)
              : scheme.primary,
          child: Text(
            c.name.characters.first,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        onChanged: (c) {
          picked = c; // 只保存，不自己 pop——来自Trae
        },
      ),
    );

    if (picked == null || !context.mounted) return;
    final course = picked!; // 提升为非空——来自Trae

    HapticFeedback.lightImpact();
    final count = await ref
        .read(lessonActionsProvider)
        .markAttendedForDate(course.id, date);
    if (!context.mounted) return;
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已为 ${course.name} 补记 $count 节课')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该课程没有排课规则，无法补录')),
      );
    }
  }
}

class _DateHeader extends ConsumerWidget {
  const _DateHeader({
    required this.date,
    required this.onTap,
    required this.onPrev,
    required this.onNext,
    required this.onLongPress,
  });

  final DateTime date;
  final VoidCallback onTap;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = DateUtilsTool.dateOnly(date) ==
        DateUtilsTool.dateOnly(DateTime.now());
    final primary = Theme.of(context).colorScheme.primary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: primary),
            onPressed: onPrev,
            tooltip: '前一天',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${DateUtilsTool.formatDate(date)} · ${DateUtilsTool.chineseWeekday(date.weekday)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  isToday ? '今天 · 长按回到今天' : '点击选择日期',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: primary),
            onPressed: onNext,
            tooltip: '后一天',
          ),
          Icon(Icons.keyboard_arrow_down, color: primary),
        ],
      ),
    );

    // 玻璃模式：染一层主题色的玻璃；普通模式沿用原来的淡色底——来自Trae
    if (ref.watch(isLiquidGlassProvider)) {
      return GlassPanel(
        borderRadius: AppTokens.cardRadius,
        tintAlpha: 0.12,
        tint: primary,
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      );
    }

    return Material(
      color: primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        child: content,
      ),
    );
  }
}

/// 半屏日历日期选择器
class DatePickerSheet extends ConsumerStatefulWidget {
  const DatePickerSheet({super.key, required this.initialDate});
  final DateTime initialDate;

  @override
  ConsumerState<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends ConsumerState<DatePickerSheet> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
    _selectedDay = DateUtilsTool.dateOnly(widget.initialDate);
  }

  void _pickQuick(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDay = DateUtilsTool.dateOnly(day);
      _focusedDay = _selectedDay;
    });
    Navigator.of(context).pop(_selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(calendarDayStatusProvider(_focusedDay));
    final dayStatus =
        statusAsync.valueOrNull ?? const <DateTime, Set<LessonStatus>>{};
    final countAsync = ref.watch(calendarDayCountProvider(_focusedDay));
    final dayCount = countAsync.valueOrNull ?? const <DateTime, int>{};
    final scheme = Theme.of(context).colorScheme;
    final today = DateUtilsTool.dateOnly(DateTime.now());

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GlassChip(
                    label: '今天',
                    onTap: () => _pickQuick(today),
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: '昨天',
                    onTap: () =>
                        _pickQuick(today.subtract(const Duration(days: 1))),
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: '明天',
                    onTap: () =>
                        _pickQuick(today.add(const Duration(days: 1))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TableCalendar<DateTime>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2100),
              focusedDay: _focusedDay,
              locale: 'zh_CN',
              // 圆 + 底部标记需要更高一行才不重叠——2026-10-10
              rowHeight: 56,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(DateUtilsTool.dateOnly(selectedDay));
              },
              onPageChanged: (focusedDay) =>
                  setState(() => _focusedDay = focusedDay),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false, // 去掉 "2 weeks" 切换按钮——来自Trae
                leftChevronIcon: Icon(Icons.chevron_left),
                rightChevronIcon: Icon(Icons.chevron_right),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                ),
                weekendStyle: TextStyle(
                  color: scheme.error,
                  fontSize: 12,
                ),
              ),
              // 日期圆与数字标记的布局走 CalendarDayCell，
              // 圆固定 32px 靠上，底部留给标记，避免重叠——2026-10-10
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, date, _) => CalendarDayCell(
                  date: date,
                  textColor: CalendarDayCell.isWeekend(date)
                      ? scheme.error
                      : scheme.onSurface,
                ),
                todayBuilder: (context, date, _) => CalendarDayCell(
                  date: date,
                  textColor: CalendarDayCell.isWeekend(date)
                      ? scheme.error
                      : scheme.onSurface,
                  circleColor: AppColors.primary.withValues(alpha: 0.3),
                ),
                selectedBuilder: (context, date, _) => CalendarDayCell(
                  date: date,
                  textColor: Colors.white,
                  circleColor: AppColors.primary,
                ),
                markerBuilder: (context, date, _) {
                  final day = DateUtilsTool.dateOnly(date);
                  final count = dayCount[day];
                  final statuses = dayStatus[day];
                  if (count == null || count == 0) return null;
                  if (statuses == null || statuses.isEmpty) return null;
                  return CalendarLessonMarker(
                    count: count,
                    statuses: statuses,
                    date: day,
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}


