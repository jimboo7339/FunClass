import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../shared/providers/lesson_providers.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/widgets/calendar_lesson_marker.dart';
import '../../../shared/widgets/lesson_card.dart';

/// 日历页
/// 顺序：日历（月/周可切换）→ 成员筛选 → 当天课次列表
/// 整个页面一个 ListView 统一滚动：
///   上滑到阈值 → 月历切成周视图（收缩到一行）
///   列表滚到顶再下滑 → 周视图展开回月视图
/// 来自Trae
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 日历展开/收缩高度——来自Trae
  // 行高 52 后月视图 6 行 + 头部，展开高相应加大——2026-10-10
  static const double _expandedHeight = 430;
  static const double _collapsedHeight = 140;
  static const double _midpoint = (_expandedHeight + _collapsedHeight) / 2;
  double _calendarHeight = _expandedHeight;

  final ScrollController _scrollCtrl = ScrollController();

  // 手指在日历上直接滑动收缩/展开（与列表长度无关）——来自Trae
  bool _dragging = false;
  double _dragStartHeight = _expandedHeight;

  // 上滑阈值：超过此值切周视图；低于此值切月视图——来自Trae
  static const double _collapseThreshold = 80;
  static const double _expandThreshold = 10;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateUtilsTool.dateOnly(ref.read(calendarFocusDateProvider));
    _selectedDay = _focusedDay;
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollCtrl.offset;
    if (offset > _collapseThreshold && !_isCollapsed) {
      _collapseCalendar();
    } else if (offset <= _expandThreshold && _isCollapsed) {
      _expandCalendar();
    }
  }

  void _collapseCalendar() {
    if (_calendarFormat == CalendarFormat.week) return;
    _isCollapsed = true;
    setState(() {
      _calendarFormat = CalendarFormat.week;
      _calendarHeight = _collapsedHeight;
    });
  }

  void _expandCalendar() {
    if (_calendarFormat == CalendarFormat.month) return;
    _isCollapsed = false;
    setState(() {
      _calendarFormat = CalendarFormat.month;
      _calendarHeight = _expandedHeight;
    });
  }

  // ---- 日历上直接滑动收缩/展开（手指跟随，松手吸附）——来自Trae ----
  void _onDragStart(DragStartDetails d) {
    _dragging = true;
    _dragStartHeight = _calendarHeight;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // 手指上滑（dy>0 表示向上），高度减小；下滑高度增大
    final clamped = (_dragStartHeight - d.delta.dy)
        .clamp(_collapsedHeight, _expandedHeight)
        .toDouble();
    setState(() {
      _calendarHeight = clamped;
      // 越过中点则切换周视图，否则月视图，让行数跟高度匹配——来自Trae
      _calendarFormat = clamped < _midpoint
          ? CalendarFormat.week
          : CalendarFormat.month;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    final collapse = velocity < -300 ||
        (velocity.abs() <= 300 && _calendarHeight < _midpoint);
    _dragging = false;
    setState(() {
      _calendarFormat = collapse ? CalendarFormat.week : CalendarFormat.month;
      _calendarHeight = collapse ? _collapsedHeight : _expandedHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 监听外部聚焦日期变化（今日页过期提醒跳转）来自Trae
    ref.listen<DateTime>(calendarFocusDateProvider, (prev, next) {
      if (prev != next) {
        setState(() {
          _focusedDay = next;
          _selectedDay = DateUtilsTool.dateOnly(next);
        });
      }
    });

            final countAsync = ref.watch(calendarDayCountProvider(_focusedDay));
    final statusAsync = ref.watch(calendarDayStatusProvider(_focusedDay));
    final selectedLessons = _selectedDay != null
        ? ref.watch(lessonsByDateProvider(_selectedDay!))
        : const AsyncValue.data(<LessonWithCourse>[]);

    final dayCount = countAsync.valueOrNull ?? const <DateTime, int>{};
    final dayStatus =
        statusAsync.valueOrNull ?? const <DateTime, Set<LessonStatus>>{};

    
    // 构建日历 + 筛选 + 列表的单一 ListView——来自Trae
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
      ),
      body: ListView(
        controller: _scrollCtrl,
        padding: EdgeInsets.zero,
        children: [
          // ① 日历——手指可上下滑动收缩/展开，AnimatedContainer 平滑吸附——来自Trae
          GestureDetector(
            // 手势只拦截日历区域的上下滑；不挡左右翻月 / 点选日期——来自Trae
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: AnimatedContainer(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              height: _calendarHeight,
              child: TableCalendar<LessonWithCourse>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2100),
              focusedDay: _focusedDay,
              locale: 'zh_CN',
              // 圆 + 底部标记需要更高一行才不重叠——2026-10-10
              rowHeight: 56,
              selectedDayPredicate: (day) =>
                  isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              availableCalendarFormats: const {
                CalendarFormat.month: '月',
                CalendarFormat.week: '周',
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                  _calendarHeight = format == CalendarFormat.week
                      ? _collapsedHeight
                      : _expandedHeight;
                });
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) =>
                  setState(() => _focusedDay = focusedDay),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                leftChevronIcon: Icon(Icons.chevron_left),
                rightChevronIcon: Icon(Icons.chevron_right),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                ),
                weekendStyle: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
              ),
              // 日期圆与数字标记的布局走 CalendarDayCell，
              // 圆固定 32px 靠上，底部留给标记，避免重叠——2026-10-10
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, date, _) => CalendarDayCell(
                  date: date,
                  textColor: CalendarDayCell.isWeekend(date)
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface,
                ),
                todayBuilder: (context, date, _) => CalendarDayCell(
                  date: date,
                  textColor: CalendarDayCell.isWeekend(date)
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface,
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
          ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),

          // ③ 当天课次列表（直接作为 ListView 的后续 children）——来自Trae
          selectedLessons.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('加载失败: $e')),
            ),
            data: (items) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateUtilsTool.formatDate(_selectedDay!)} · ${DateUtilsTool.chineseWeekday(_selectedDay!.weekday)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            '今天没有课 🎉',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: LessonCard(
                              item: item,
                              onStatusTap: (status) => ref
                                  .read(lessonActionsProvider)
                                  .updateStatus(item.lesson.id, status),
                              onDelete: () => ref
                                  .read(lessonActionsProvider)
                                  .deleteLesson(item.lesson.id),
                            ),
                          )),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
