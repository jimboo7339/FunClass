import 'package:flutter/foundation.dart' show debugPrint;

import '../../data/database/app_database.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/lesson_repository.dart';
import 'notification_service.dart';

/// 课程有效期临近天数阈值（与今日页横幅一致）——来自Trae
const int kExpiryThresholdDays = 30;

/// 「剩余课时」低水位阈值：低到这个程度就该考虑续费了——2026-10-10
const int kLowLessonsThreshold = 3;

/// 重排未来几天 pending 课次的上课提醒。
///
/// 窗口 = 今天 0 点起 7 天：前一晚打开 App 就会把明天的课排上，
/// 一周内不用天天打开也有提醒（早先只排 3 天，周末出门一趟回来，
/// 下周的课一节都没排上）；条数由 NotificationService.maxScheduledAlarms 兜底。
/// 几天没打开，下次启动也会把窗口内的课补齐（早先只排"今天"，
/// 晚上开过一次 App 后、第二天早上的课根本没被排程过）。
/// 调用时机：App 启动、提醒设置变化、课次/课程变更、App 从后台回到前台。
/// 失败不再静默：debugPrint 留痕，设置页「提醒诊断」卡可见可修。——来自Trae
Future<void> rescheduleTodayNotifications() async {
  try {
    final db = AppDatabase();
    final lessonRepo = LessonRepository(db);
    final courseRepo = CourseRepository(db);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final lessons = await lessonRepo.getLessonsWithCourseByDateRange(
      start,
      start.add(const Duration(days: 7)),
    );
    // 过期未处理的课次单独查一次（不在 3 天窗口内），用于每日催办通知——来自Trae
    final unrecorded = await lessonRepo.getPendingUnrecorded();
    await NotificationService.instance
        .scheduleUpcomingLessons(lessons, unrecordedCount: unrecorded.length);

    // 课程到期 / 课时将尽的每日预警——2026-10-10
    final warning = await buildExpiryWarningBody(courseRepo, lessonRepo);
    await NotificationService.instance.scheduleExpiryWarning(warning);
  } catch (e) {
    debugPrint('[提醒重排失败] $e');
  }
}

/// 汇总「快到期 / 快没课时」的课程，拼成一条通知文案；
/// 没有预警课程时返回空串（调用方据此取消通知）。
/// 与今日页横幅口径一致：有效期 30 天内到期、剩余课时 ≤ 3 节——2026-10-10
Future<String> buildExpiryWarningBody(
  CourseRepository courseRepo,
  LessonRepository lessonRepo,
) async {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final courses = await courseRepo.getAll();

  final expiring = <String>[];
  final lowLessons = <String>[];
  for (final c in courses) {
    final days = c.validTo.difference(todayStart).inDays;
    if (days >= 0 && days <= kExpiryThresholdDays) {
      expiring.add('${c.name} $days 天后到期');
    }
    final attended = await lessonRepo.countAttended(c.id);
    final remaining = c.totalLessons - attended;
    if (remaining > 0 && remaining <= kLowLessonsThreshold) {
      lowLessons.add('${c.name} 仅剩 $remaining 节');
    }
  }

  final parts = <String>[
    ...expiring,
    ...lowLessons,
  ];
  if (parts.isEmpty) return '';
  return parts.take(3).join('；');
}