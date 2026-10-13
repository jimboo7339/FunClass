import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../constants/app_constants.dart';
import 'date_utils.dart';

/// 课次生成器
/// 按课程频率规则，从有效期起点逐日匹配应上课日，生成 pending 课次。
///
/// 规则：
/// - 闭区间 [validFrom, validTo]，到期日当天若匹配规则仍生成
/// - 按 weekday 自然匹配，不做特殊处理
///   （如有效期从周三开始、规则是周五，则第一节就是那周五）
/// - [maxCount]：本次最多生成多少节（新排课模型用——排满剩余课时就停，
///   不再按频率铺满整个有效期）
/// 来自Trae
class LessonGenerator {
  LessonGenerator._();

  /// 根据课程生成课次列表（仅内存对象，未写入数据库）
  /// 返回 LessonsCompanion 列表，供 Repository 批量插入
  ///
  /// [skipUpTo]：只生成开课时刻晚于该时间的课次。
  /// 用于「编辑课程后重排未发生课次」与「按剩余课时排未来计划」——
  /// 已开过的时段（含当天已到点的）不再生成，
  /// 判断标准与通知排程一致（开课时刻 <= skipUpTo 即视为已发生）——来自Trae
  static List<LessonsCompanion> generate(
    Course course, {
    DateTime? skipUpTo,
    int? maxCount,
  }) {
    final rules = course.schedules;
    if (rules.isEmpty) return [];

    final lessons = <LessonsCompanion>[];
    final start = DateUtilsTool.dateOnly(course.validFrom);
    // "永久"课程：以 maxLessonGenerationDays 为上限，避免无限生成
    final maxEnd =
        start.add(const Duration(days: AppConstants.maxLessonGenerationDays));
    final rawEnd = DateUtilsTool.dateOnly(course.validTo);
    final end = rawEnd.isAfter(maxEnd) ? maxEnd : rawEnd;

    // 按天遍历有效期，命中规则的日子生成课次
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (maxCount != null && lessons.length >= maxCount) break;
      for (final rule in rules) {
        if (maxCount != null && lessons.length >= maxCount) break;
        if (cursor.weekday == rule.weekday) {
          // 该节课的开课时刻（当天 0 点 + 开始时间）
          final startsAt =
              cursor.add(Duration(minutes: DateUtilsTool.parseMinutes(rule.startTime)));
          // 已发生的时段跳过；没传 skipUpTo 时保持原行为（生成全部历史+未来）
          if (skipUpTo != null && !startsAt.isAfter(skipUpTo)) {
            continue;
          }
          lessons.add(
            LessonsCompanion.insert(
              courseId: course.id,
              date: cursor,
              startTime: rule.startTime,
              endTime: rule.endTime,
              status: LessonStatus.pending,
              isExtra: const Value(false),
            ),
          );
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return lessons;
  }
}
