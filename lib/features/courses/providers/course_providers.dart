import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/today_reminders.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/backup_auto_sync.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/course_repository.dart';
import '../../members/providers/member_providers.dart';
import '../../shared/providers/lesson_providers.dart';

/// 课程列表
/// 来自Trae
final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) {
  return ref.watch(courseRepositoryProvider).getAll();
});

/// 单个课程
final courseProvider = FutureProvider.autoDispose.family<Course?, int>((ref, id) {
  return ref.watch(courseRepositoryProvider).getById(id);
});

/// 某课程的已上课时数
final attendedCountProvider = FutureProvider.autoDispose.family<int, int>((ref, courseId) {
  return ref.watch(lessonRepositoryProvider).countAttended(courseId);
});

/// 课程 + 已上课时数 的聚合数据
class CourseWithStats {
  final Course course;
  final int attendedCount;
  const CourseWithStats(this.course, this.attendedCount);

  /// 剩余课时（加课较多时已上数可能超过总课时，收口到 0）——来自Trae
  int get remaining =>
      course.totalLessons > attendedCount
          ? course.totalLessons - attendedCount
          : 0;

  /// 已上课时占比（0~1）
  double get progress =>
      course.totalLessons == 0 ? 0 : attendedCount / course.totalLessons;

  /// 均价（每节）
  double get unitPrice =>
      course.totalLessons == 0 ? 0 : course.totalAmount / course.totalLessons;
}

/// 当月已上课时数
final monthlyAttendedCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(lessonRepositoryProvider).countAttendedInMonth(DateTime.now());
});

/// 课程列表（含统计）
final coursesWithStatsProvider =
    FutureProvider.autoDispose<List<CourseWithStats>>((ref) async {
  final courses = await ref.watch(coursesProvider.future);
  final result = <CourseWithStats>[];
  for (final c in courses) {
    final attended = await ref.watch(attendedCountProvider(c.id).future);
    result.add(CourseWithStats(c, attended));
  }
  return result;
});

/// 课程操作（新增/更新/删除）
/// 来自Trae
class CourseActions {
  CourseActions(this.ref);
  final Ref ref;

  Future<int> insertWithLessons(CoursesCompanion companion) async {
    final id = await ref.read(courseRepositoryProvider).insertWithLessons(companion);
    _invalidateLessonStuff();
    ref.read(backupAutoSyncProvider).trigger();
    return id;
  }

  Future<void> update(CoursesCompanion companion) async {
    await ref.read(courseRepositoryProvider).updateCourse(companion);
    // 总课时/有效期变了 → 未来排程收敛到"剩余课时数"——来自Trae
    await ref.read(lessonPlannerProvider).syncCourse(companion.id.value);
    _invalidateLessonStuff();
    ref.read(backupAutoSyncProvider).trigger();
  }

  /// 编辑课程后重排"尚未发生"的课次（已上/已到点的保持不变）
  /// 完成后顺带重排当天提醒，让它跟着新计划走——来自Trae
  Future<RescheduleResult> reschedule(
    CoursesCompanion companion,
  ) async {
    final result =
        await ref.read(courseRepositoryProvider).rescheduleOnUpdate(
              companion,
              now: DateTime.now(),
            );
    // 重排已按剩余课时封顶，这里只清历史遗留的过期 pending 行——来自Trae
    await ref.read(lessonPlannerProvider).syncCourse(companion.id.value);
    _invalidateLessonStuff();
    ref.read(backupAutoSyncProvider).trigger();
    await rescheduleTodayNotifications();
    return result;
  }

  /// 该课程尚未发生、可被重排的课次数（用于编辑前的确认弹窗）
  Future<int> countReschedulable(int courseId) {
    return ref
        .read(courseRepositoryProvider)
        .countReschedulable(courseId, DateTime.now());
  }

  Future<void> delete(int courseId) async {
    await ref.read(courseRepositoryProvider).deleteWithLessons(courseId);
    _invalidateLessonStuff();
    ref.read(backupAutoSyncProvider).trigger();
  }

  void _invalidateLessonStuff() {
    ref.invalidate(coursesProvider);
    ref.invalidate(coursesWithStatsProvider);
    // 课程变更后刷新课次相关数据（日历打点、今日页等）来自Trae
    ref.invalidate(lessonsByDateProvider);
    ref.invalidate(lessonDatesProvider);
    ref.invalidate(calendarDayStatusProvider);
    ref.invalidate(calendarDayCountProvider);
  }
}

/// 课程操作 Provider
final courseActionsProvider = Provider<CourseActions>((ref) => CourseActions(ref));

/// 即将到期的课程（有效期剩余 <= 30 天）
/// 来自Trae
class ExpiringCourse {
  final Course course;
  final String memberName;
  final int daysRemaining;
  const ExpiringCourse({
    required this.course,
    required this.memberName,
    required this.daysRemaining,
  });
}

final expiringCoursesProvider =
    FutureProvider.autoDispose<List<ExpiringCourse>>((ref) async {
  const thresholdDays = 30;
  final courses = await ref.watch(coursesProvider.future);
  final members = await ref.watch(membersProvider.future);
  final memberMap = {for (final m in members) m.id: m};
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);

  final result = <ExpiringCourse>[];
  for (final c in courses) {
    final days = c.validTo.difference(todayStart).inDays;
    if (days >= 0 && days <= thresholdDays) {
      result.add(ExpiringCourse(
        course: c,
        memberName: memberMap[c.memberId]?.name ?? '未知成员',
        daysRemaining: days,
      ));
    }
  }
  result.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
  return result;
});
