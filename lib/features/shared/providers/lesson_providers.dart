import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/today_reminders.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/backup_auto_sync.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../courses/providers/course_providers.dart';
import '../../statistics/providers/stats_providers.dart';

/// 某天的课次（含课程信息），可按成员筛选
/// 来自Trae
final lessonsByDateProvider = FutureProvider.autoDispose
    .family<List<LessonWithCourse>, DateTime>((ref, date) {
  final memberId = ref.watch(calendarMemberFilterProvider);
  return ref
      .watch(lessonRepositoryProvider)
      .getLessonsWithCourseByDate(date, memberId: memberId);
});

/// 已结束但还没记「已上/未上」的课次（时刻粒度，含今天已过点的）
/// 今日页提醒条与每日催办通知共用它——来自Trae
final overduePendingProvider =
    FutureProvider.autoDispose<List<LessonWithCourse>>((ref) {
  final memberId = ref.watch(calendarMemberFilterProvider);
  return ref
      .watch(lessonRepositoryProvider)
      .getPendingUnrecorded(memberId: memberId);
});

/// 某月有课的日期列表（用于日历打点）
final lessonDatesProvider = FutureProvider.autoDispose
    .family<List<DateTime>, DateTime>((ref, month) {
  final memberId = ref.watch(calendarMemberFilterProvider);
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);
  return ref
      .watch(lessonRepositoryProvider)
      .getDatesWithLessons(monthStart, monthEnd, memberId: memberId);
});

/// 某月「日期 → 当天课次状态集合」，日历按状态给课次数字上色（已上绿/未上橘/待上蓝）。
/// 与 lessonDatesProvider 共用成员筛选。——来自Trae
final calendarDayStatusProvider = FutureProvider.autoDispose
    .family<Map<DateTime, Set<LessonStatus>>, DateTime>((ref, month) {
  final memberId = ref.watch(calendarMemberFilterProvider);
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);
  return ref
      .watch(lessonRepositoryProvider)
      .getStatusesByDate(monthStart, monthEnd, memberId: memberId);
});

/// 某月「日期 → 当天课次数」，日历在日期下方显示数字标记（替代原来的小圆点）。
/// 与 calendarDayStatusProvider 共用成员筛选，两者取到的日期集合一致。——2026-10-10
final calendarDayCountProvider = FutureProvider.autoDispose
    .family<Map<DateTime, int>, DateTime>((ref, month) {
  final memberId = ref.watch(calendarMemberFilterProvider);
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);
  return ref
      .watch(lessonRepositoryProvider)
      .getLessonCountByDate(monthStart, monthEnd, memberId: memberId);
});

/// 某课程的所有课次（按日期降序，时间轴展示用）——来自Trae
final lessonsByCourseProvider =
    FutureProvider.autoDispose.family<List<Lesson>, int>((ref, courseId) {
  // 时间轴用正序（日期从早到晚）——来自Trae
  return ref
      .watch(lessonRepositoryProvider)
      .getByCourseId(courseId);
});

/// 课次状态操作（更新后刷新相关 provider）
/// 来自Trae
class LessonActions {
  LessonActions(this.ref);
  final Ref ref;

  Future<void> updateStatus(int id, LessonStatus status) async {
    final repo = ref.read(lessonRepositoryProvider);
    final lesson = await repo.getById(id);
    await repo.updateStatus(id, status);
    ref.invalidate(lessonsByDateProvider);
    ref.invalidate(lessonDatesProvider);
    ref.invalidate(calendarDayStatusProvider);
    ref.invalidate(calendarDayCountProvider);
    // 今日页「有 N 节课已结束还没记」的提醒条靠它，处理完得自己消停
    // ——漏了这行就只能下拉刷新才消失，2026-10-10 修
    ref.invalidate(overduePendingProvider);
    ref.invalidate(coursesWithStatsProvider);
    ref.invalidate(statsProvider);
    // 上掉一节 → 尾部计划减一；撤销回待上 → 补回一节，
    // 计划自动收敛为"未来 = 剩余课时"——来自Trae
    if (lesson != null) {
      await ref.read(lessonPlannerProvider).syncCourse(lesson.courseId);
    }
    _rescheduleToday();
    ref.read(backupAutoSyncProvider).trigger();
  }

  /// 在今天的日期上为课程生成一条已上课记录（用于课程卡片"记一节"快捷操作）
  /// 默认备注为"加课" 来自Trae
  Future<int> markNextPendingAttended(int courseId) async {
    final course = await ref.read(courseRepositoryProvider).getById(courseId);
    if (course == null || course.schedules.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayWeekday = today.weekday;

    final matchedRules = course.schedules
        .where((r) => r.weekday == todayWeekday)
        .toList();
    final rulesToUse =
        matchedRules.isEmpty ? course.schedules.take(1).toList() : matchedRules;

    final lessonRepo = ref.read(lessonRepositoryProvider);
    var insertedCount = 0;
    for (final rule in rulesToUse) {
      await lessonRepo.insertExtra(
        LessonsCompanion.insert(
          courseId: courseId,
          date: today,
          startTime: rule.startTime,
          endTime: rule.endTime,
          status: LessonStatus.attended,
          isExtra: const Value(true),
          note: const Value('加课'),
          attendedAt: Value(now),
        ),
      );
      insertedCount++;
    }

    if (insertedCount > 0) {
      _invalidateAll();
      // 加课消耗一节 → 尾部排程少一节——来自Trae
      await ref.read(lessonPlannerProvider).syncCourse(courseId);
      _rescheduleToday();
    }

    return insertedCount;
  }

  /// 为课程在指定日期生成一条已上课记录（用于今日页"加一节"补录）
  /// 可选择任意日期（包括过去日期），方便漏记时补录——来自Trae
  Future<int> markAttendedForDate(int courseId, DateTime date) async {
    final course = await ref.read(courseRepositoryProvider).getById(courseId);
    if (course == null || course.schedules.isEmpty) return 0;

    final targetDate = DateTime(date.year, date.month, date.day);
    final targetWeekday = targetDate.weekday;

    // 优先用目标日期对应的排课规则，没有则取第一条——来自Trae
    final matchedRules = course.schedules
        .where((r) => r.weekday == targetWeekday)
        .toList();
    final rulesToUse =
        matchedRules.isEmpty ? course.schedules.take(1).toList() : matchedRules;

    final now = DateTime.now();
    final lessonRepo = ref.read(lessonRepositoryProvider);
    var insertedCount = 0;
    for (final rule in rulesToUse) {
      await lessonRepo.insertExtra(
        LessonsCompanion.insert(
          courseId: courseId,
          date: targetDate,
          startTime: rule.startTime,
          endTime: rule.endTime,
          status: LessonStatus.attended,
          isExtra: const Value(true),
          note: const Value('加课'),
          attendedAt: Value(now),
        ),
      );
      insertedCount++;
    }

    if (insertedCount > 0) {
      _invalidateAll();
      await ref.read(lessonPlannerProvider).syncCourse(courseId);
      _rescheduleToday();
    }

    return insertedCount;
  }

  /// 删除课次（用于日历/今日页删除手动补记的课次）
  Future<void> deleteLesson(int id) async {
    final repo = ref.read(lessonRepositoryProvider);
    final lesson = await repo.getById(id);
    await repo.deleteById(id);
    _invalidateAll();
    // 删的是未来排程 → 补回一节（等于这节顺延）；撤掉它的提醒——来自Trae
    if (lesson != null) {
      await ref.read(lessonPlannerProvider).syncCourse(lesson.courseId);
    }
    _rescheduleToday();
  }

  /// 更新课次备注——来自Trae
  Future<void> updateNote(int id, String? note) async {
    await ref.read(lessonRepositoryProvider).updateNote(id, note);
    _invalidateAll();
  }

  /// 重新排程提醒（走与启动/设置变化同一套：未来 3 天窗口 + 幂等同步）——来自Trae
  Future<void> _rescheduleToday() => rescheduleTodayNotifications();

  /// 刷新所有课次相关 provider——来自Trae
  void _invalidateAll() {
    ref.invalidate(lessonsByDateProvider);
    ref.invalidate(lessonDatesProvider);
    ref.invalidate(calendarDayStatusProvider);
    ref.invalidate(calendarDayCountProvider);
    ref.invalidate(overduePendingProvider);
    ref.invalidate(lessonsByCourseProvider);
    ref.invalidate(coursesWithStatsProvider);
    ref.invalidate(statsProvider);
    ref.read(backupAutoSyncProvider).trigger();
  }
}

final lessonActionsProvider = Provider<LessonActions>((ref) => LessonActions(ref));
