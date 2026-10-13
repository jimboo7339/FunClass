import 'package:drift/drift.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/lesson_generator.dart';
import '../../data/models/enums.dart';
import '../database/app_database.dart';

/// 课次重排结果
class RescheduleResult {
  const RescheduleResult({required this.removed, required this.added});
  final int removed;
  final int added;
}

/// 课程仓库
/// 新增课程时自动按频率规则生成课次
/// 来自Trae
class CourseRepository {
  CourseRepository(this._db);

  final AppDatabase _db;

  /// 获取所有课程
  Future<List<Course>> getAll() {
    return (_db.select(_db.courses)..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .get();
  }

  /// 按成员 id 获取课程
  Future<List<Course>> getByMemberId(int memberId) {
    return (_db.select(_db.courses)
          ..where((c) => c.memberId.equals(memberId))
          ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .get();
  }

  /// 按 id 获取课程
  Future<Course?> getById(int id) {
    return (_db.select(_db.courses)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// 新增课程并自动生成课次，返回课程 id
  /// 事务保证：课程写入失败则课次也不写入
  Future<int> insertWithLessons(CoursesCompanion companion) async {
    return _db.transaction(() async {
      final courseId = await _db.into(_db.courses).insert(companion);

      // 需要完整的 Course 对象来生成课次，因此重新查询
      final course = await getById(courseId);
      if (course == null) return courseId;

      // 新排课模型：只排"未来"的课，且排满总课时数就停
      // （不再按频率铺满整个有效期——45 节课就该只有 45 条计划）——来自Trae
      final lessons = LessonGenerator.generate(
        course,
        skipUpTo: DateTime.now(),
        maxCount: course.totalLessons,
      );
      if (lessons.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.lessons, lessons);
        });
      }
      return courseId;
    });
  }

  /// 更新课程（注意：不自动重新生成课次，避免破坏已改状态的课次）
  Future<bool> updateCourse(CoursesCompanion companion) {
    return _db.update(_db.courses).replace(companion);
  }

  /// 统计某课程"尚未发生、可被重排"的课次数（编辑前给用户看影响范围）
  /// 判定标准同 [rescheduleOnUpdate]。
  Future<int> countReschedulable(int courseId, DateTime now) async {
    final lessons = await (_db.select(_db.lessons)
          ..where((l) => l.courseId.equals(courseId)))
        .get();
    return _reschedulable(lessons, now).length;
  }

  /// 更新课程，并按新计划重排"尚未发生"的课次。
  ///
  /// 冻结线是 [now]。任一条件命中即保留、不动：
  /// 1. 已上 / 已跳过（status != pending）——用户已经记录了
  /// 2. 手动加课（isExtra）——用户手加的，不在计划里
  /// 3. 开课时刻 <= now——时间上已经发生过的（含"今天但时段已过"）
  /// 其余的（pending、自动生成、未来）删掉并按新规则重新生成；
  /// 日期+开始时间都没变的课次，备注原样带回，时间被改掉的才可能丢备注。——来自Trae
  Future<RescheduleResult> rescheduleOnUpdate(
    CoursesCompanion companion, {
    required DateTime now,
  }) {
    return _db.transaction(() async {
      final courseId = companion.id.value;

      // 更新课程行；保留 createdAt（.replace 会把缺省字段重置成现在，
      // 否则课程列表按 createdAt 排序时会乱跳）——来自Trae
      final old = await getById(courseId);
      final toWrite = companion.copyWith(createdAt: Value(old?.createdAt ?? now));
      await (_db.update(_db.courses)..where((c) => c.id.equals(courseId)))
          .write(toWrite);

      // 找出要删的课次，并记下它们的位置和备注
      final existing = await (_db.select(_db.lessons)
            ..where((l) => l.courseId.equals(courseId)))
          .get();
      final doomed = _reschedulable(existing, now);
      final doomedIds = doomed.map((l) => l.id).toSet();
      final survivors = existing.where((l) => !doomedIds.contains(l.id)).toList();

      // 备注按（日期, 开始时间）建索引，新计划里同一格的课次把它捡回来
      final noteBySlot = <String, String?>{
        for (final l in doomed) _slotKey(l.date, l.startTime): l.note,
      };
      if (doomed.isNotEmpty) {
        await (_db.delete(_db.lessons)..where((l) => l.id.isIn(doomedIds))).go();
      }

      // 按新规则生成"未来"课次：只排满剩余课时数、回填备注、
      // 避免和保留下来的课次撞同一格——来自Trae
      final updated = await getById(courseId);
      if (updated == null) {
        return RescheduleResult(removed: doomed.length, added: 0);
      }
      final attended = existing
          .where((l) => l.status == LessonStatus.attended)
          .length;
      final target = updated.totalLessons > attended
          ? updated.totalLessons - attended
          : 0;
      // 过期未处理的 pending 也占"待上"名额（幸存行，重排不动它们），
      // 新计划只需补齐剩下的——已发生的行（已上/未上/过期待处理）永不改动——来自Trae
      final allAutoPending = existing
          .where((l) => l.status == LessonStatus.pending && !l.isExtra)
          .length;
      final unrecorded = allAutoPending - doomed.length;
      final cap = target > unrecorded ? target - unrecorded : 0;
      final occupied = {for (final l in survivors) _slotKey(l.date, l.startTime)};
      // 回填备注：LessonsCompanion 的字段是 final，要用 copyWith 重建
      final toInsert = LessonGenerator.generate(
        updated,
        skipUpTo: now,
        maxCount: cap,
      )
          .where((c) =>
              !occupied.contains(_slotKey(c.date.value, c.startTime.value)))
          .map((c) {
            final note = noteBySlot[_slotKey(c.date.value, c.startTime.value)];
            return note == null ? c : c.copyWith(note: Value(note));
          })
          .toList();
      if (toInsert.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.lessons, toInsert));
      }
      return RescheduleResult(removed: doomed.length, added: toInsert.length);
    });
  }

  /// 会因重排被删的课次：pending、非手动加课、开课时刻晚于 [now]
  List<Lesson> _reschedulable(List<Lesson> lessons, DateTime now) {
    final out = <Lesson>[];
    for (final l in lessons) {
      if (l.status != LessonStatus.pending || l.isExtra) continue;
      final startsAt =
          l.date.add(Duration(minutes: DateUtilsTool.parseMinutes(l.startTime)));
      if (!startsAt.isAfter(now)) continue; // 已经开过的
      out.add(l);
    }
    return out;
  }

  /// 一个课次的定位键：日期（抹掉时分）+ 开始时间
  static String _slotKey(DateTime date, String startTime) =>
      '${DateUtilsTool.formatDate(DateUtilsTool.dateOnly(date))}|$startTime';

  /// 删除课程及其所有课次
  Future<int> deleteWithLessons(int courseId) async {
    return _db.transaction(() async {
      await (_db.delete(_db.lessons)..where((l) => l.courseId.equals(courseId)))
          .go();
      return (_db.delete(_db.courses)..where((c) => c.id.equals(courseId))).go();
    });
  }
}
