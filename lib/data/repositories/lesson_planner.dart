import '../../core/utils/date_utils.dart';
import '../../core/utils/lesson_generator.dart';
import '../models/enums.dart';
import '../database/app_database.dart';

/// 课次排程计划器：让每门课"未来的 pending 排程数"等于
/// 剩余课时 − 过期未处理数（target = totalLessons − attended）。
///
/// 排课模型（2026-10-10 与用户确认，v24 定稿）：
/// - 排程不按频率铺满整个有效期，**排满总课时数就停**（50 节就 50 条，排到哪算哪）；
/// - **已发生的一律冻结**：attended / skipped / 过期 pending（上完没记的）
///   都不删不改，编辑和重排只动"当前时刻之后"的；
/// - 过期 pending 保留为"待处理"，由今日页提醒条 + 每日通知催用户点
///   「已上课」或「未上课」；
/// - 点「未上课」→ 该节变 skipped（不占课时），本方法在计划末尾补一节（= 顺延）；
/// - 点「已上课」/加课 → attended 涨，尾部计划自动裁一节；
/// - 撤销为 pending → 反向补回。
/// 同步是幂等的：计划本来就正确时一行不动（保 id/备注/已排闹钟）。——来自Trae
class LessonPlanner {
  LessonPlanner(this._db);

  final AppDatabase _db;

  /// 全课程同步（App 启动时调用）——来自Trae
  Future<void> syncAll() async {
    final courses = await _db.select(_db.courses).get();
    for (final c in courses) {
      await syncCourse(c.id);
    }
  }

  /// 单课程排程同步。[now] 可注入用于测试。——来自Trae
  Future<void> syncCourse(int courseId, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    await _db.transaction(() async {
      final course = await (_db.select(_db.courses)
            ..where((c) => c.id.equals(courseId)))
          .getSingleOrNull();
      if (course == null) return;

      final lessons = await (_db.select(_db.lessons)
            ..where((l) => l.courseId.equals(courseId)))
          .get();

      int attended = 0;
      int unrecorded = 0; // 过期未处理：到点了还没记「已上/未上」，保留等用户处理
      final futurePending = <Lesson>[];
      for (final l in lessons) {
        if (l.status == LessonStatus.attended) {
          attended++;
          continue;
        }
        if (l.status == LessonStatus.skipped || l.isExtra) continue;
        if (_startOf(l).isAfter(at)) {
          futurePending.add(l);
        } else {
          unrecorded++;
        }
      }

      final target = course.totalLessons > attended
          ? course.totalLessons - attended
          : 0;
      // 过期未处理的那几节也是"待上"，未来排程只需补齐剩下的
      final expectedFuture =
          target > unrecorded ? target - unrecorded : 0;

      // 已经是目标形状 → 幂等退出，一行不动（保 id/备注/闹钟）
      if (futurePending.length == expectedFuture) return;

      futurePending.sort((a, b) => _startOf(a).compareTo(_startOf(b)));

      // 超出（加课/改总课时/处理了过期未处理）：从尾部裁——来自Trae
      if (futurePending.length > expectedFuture) {
        final doomed =
            futurePending.sublist(expectedFuture).map((l) => l.id).toSet();
        await (_db.delete(_db.lessons)..where((l) => l.id.isIn(doomed))).go();
        return;
      }

      // 不足（点了未上课/删了排程）：从最后一节排程之后续排 deficit 节——来自Trae
      final deficit = expectedFuture - futurePending.length;
      final anchor =
          futurePending.isEmpty ? at : _startOf(futurePending.last);
      final generated = LessonGenerator.generate(
        course,
        skipUpTo: anchor,
        maxCount: deficit,
      );
      // 避开已有行占用的格子（含过期未处理与未来已排的行）
      final occupied = {
        for (final l in lessons) _slotKey(l.date, l.startTime),
      };
      final toInsert = generated
          .where((c) =>
              !occupied.contains(_slotKey(c.date.value, c.startTime.value)))
          .toList();
      if (toInsert.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.lessons, toInsert));
      }
    });
  }

  static DateTime _startOf(Lesson l) =>
      l.date.add(Duration(minutes: DateUtilsTool.parseMinutes(l.startTime)));

  /// 课次定位键：日期（抹掉时分）+ 开始时间，同 CourseRepository 口径
  static String _slotKey(DateTime date, String startTime) =>
      '${DateUtilsTool.formatDate(DateUtilsTool.dateOnly(date))}|$startTime';
}
