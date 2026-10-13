import 'package:drift/drift.dart';

import '../../core/utils/date_utils.dart';
import '../database/app_database.dart';
import '../models/enums.dart';

/// 课次仓库
/// 提供课次查询、状态更新、加课等
/// 来自Trae
class LessonRepository {
  LessonRepository(this._db);

  final AppDatabase _db;

  /// 获取某课程的所有课次（按日期升序）
  Future<List<Lesson>> getByCourseId(int courseId) {
    return (_db.select(_db.lessons)
          ..where((l) => l.courseId.equals(courseId))
          ..orderBy([(l) => OrderingTerm.asc(l.date)]))
        .get();
  }

  /// 获取某课程的所有课次（按日期降序，时间轴展示最新在上）——来自Trae
  Future<List<Lesson>> getByCourseIdDesc(int courseId) {
    return (_db.select(_db.lessons)
          ..where((l) => l.courseId.equals(courseId))
          ..orderBy([
            (l) => OrderingTerm.desc(l.date),
            (l) => OrderingTerm.desc(l.startTime),
          ]))
        .get();
  }

  /// 获取某天的所有课次（可指定成员筛选，需连表；此处先按课程 id 列表）
  Future<List<Lesson>> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.lessons)
          ..where((l) => l.date.isBiggerOrEqualValue(start) & l.date.isSmallerThanValue(end))
          ..orderBy([(l) => OrderingTerm.asc(l.startTime)]))
        .get();
  }

  /// 获取某天某课程的课次
  Future<List<Lesson>> getByCourseAndDate(int courseId, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.lessons)
          ..where((l) =>
              l.courseId.equals(courseId) &
              l.date.isBiggerOrEqualValue(start) &
              l.date.isSmallerThanValue(end)))
        .get();
  }

  /// 按 id 获取单条课次
  Future<Lesson?> getById(int id) {
    return (_db.select(_db.lessons)..where((l) => l.id.equals(id)))
        .getSingleOrNull();
  }

  /// 更新课次状态，返回受影响行数
  /// 注意：改回 pending/skipped 时会清空 attendedAt，避免残留旧的"记录于"时间
  Future<int> updateStatus(int id, LessonStatus status) {
    final companion = LessonsCompanion(
      status: Value(status),
      attendedAt: status == LessonStatus.attended
          ? Value(DateTime.now())
          : Value(null),
    );
    return (_db.update(_db.lessons)..where((l) => l.id.equals(id)))
        .write(companion);
  }

  /// 更新课次备注——来自Trae
  Future<int> updateNote(int id, String? note) {
    return (_db.update(_db.lessons)..where((l) => l.id.equals(id)))
        .write(LessonsCompanion(note: Value(note)));
  }

  /// 手动加课（isExtra=true）
  Future<int> insertExtra(LessonsCompanion companion) {
    return _db.into(_db.lessons).insert(companion);
  }

  /// 删除课次
  Future<int> deleteById(int id) {
    return (_db.delete(_db.lessons)..where((l) => l.id.equals(id))).go();
  }

  /// 统计当月已上课时数（attended 状态）
  Future<int> countAttendedInMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final result = await (_db.selectOnly(_db.lessons)
          ..where(_db.lessons.status.equalsValue(LessonStatus.attended) &
              _db.lessons.date.isBiggerOrEqualValue(start) &
              _db.lessons.date.isSmallerThanValue(end))
          ..addColumns([_db.lessons.id.count()]))
        .getSingle();
    return result.read<int>(_db.lessons.id.count()) ?? 0;
  }

  /// 统计某课程已上课时数
  Future<int> countAttended(int courseId) async {
    final result = await (_db.selectOnly(_db.lessons)
          ..where(_db.lessons.courseId.equals(courseId) &
              _db.lessons.status.equalsValue(LessonStatus.attended))
          ..addColumns([_db.lessons.id.count()]))
        .getSingle();
    return result.read<int>(_db.lessons.id.count()) ?? 0;
  }

  /// 统计某课程总课次数（出勤率分母）
  Future<int> countByCourseId(int courseId) async {
    final result = await (_db.selectOnly(_db.lessons)
          ..where(_db.lessons.courseId.equals(courseId))
          ..addColumns([_db.lessons.id.count()]))
        .getSingle();
    return result.read<int>(_db.lessons.id.count()) ?? 0;
  }

  /// 获取日期范围内有课的日期（用于日历打点）
  /// [memberId] 可选，按成员筛选
  Future<List<DateTime>> getDatesWithLessons(
    DateTime monthStart,
    DateTime monthEnd, {
    int? memberId,
  }) async {
    final query = _db.selectOnly(_db.lessons)
      ..addColumns([_db.lessons.date])
      ..where(_db.lessons.date.isBiggerOrEqualValue(monthStart) &
          _db.lessons.date.isSmallerOrEqualValue(monthEnd))
      ..groupBy([_db.lessons.date]);

    // 按成员筛选需要连表
    if (memberId != null) {
      query.addColumns([_db.courses.memberId]);
      query.join([
        innerJoin(_db.courses, _db.courses.id.equalsExp(_db.lessons.courseId)),
      ]);
      query.where(_db.lessons.date.isBiggerOrEqualValue(monthStart) &
          _db.lessons.date.isSmallerOrEqualValue(monthEnd) &
          _db.courses.memberId.equals(memberId));
    }

    final rows = await query.get();
    return rows
        .map((r) => r.read(_db.lessons.date)!)
        .toSet()
        .toList()
      ..sort();
  }

  /// 按月把课次按日期聚合成「该日出现过哪些状态」，供日历打点按状态上色。
  /// 同一天可能有多节（已上/未上/待上混合），这里原样收集状态集合，
  /// 颜色优先级在 UI 侧决定。[memberId] 可选按成员筛选。——来自Trae
  Future<Map<DateTime, Set<LessonStatus>>> getStatusesByDate(
    DateTime monthStart,
    DateTime monthEnd, {
    int? memberId,
  }) async {
    final query = _db.selectOnly(_db.lessons)
      ..addColumns([_db.lessons.date, _db.lessons.status]);

    if (memberId != null) {
      query.join([
        innerJoin(_db.courses, _db.courses.id.equalsExp(_db.lessons.courseId)),
      ]);
      query.where(_db.lessons.date.isBiggerOrEqualValue(monthStart) &
          _db.lessons.date.isSmallerOrEqualValue(monthEnd) &
          _db.courses.memberId.equals(memberId));
    } else {
      query.where(_db.lessons.date.isBiggerOrEqualValue(monthStart) &
          _db.lessons.date.isSmallerOrEqualValue(monthEnd));
    }

    final rows = await query.get();
    final result = <DateTime, Set<LessonStatus>>{};
    for (final r in rows) {
      final date = DateUtilsTool.dateOnly(r.read(_db.lessons.date)!);
      // status 列带枚举转换器：selectOnly 的 read() 解析到的是 SQL 侧的 String
      final status = LessonStatus.values.byName(r.read(_db.lessons.status)!);
      (result[date] ??= <LessonStatus>{}).add(status);
    }
    return result;
  }

  /// 按月统计「该日有几节课」，供日历在日期下方显示数字标记。
  /// 与 [getStatusesByDate] 同一套成员筛选口径，两者取到的日期集合一致。——2026-10-10
  Future<Map<DateTime, int>> getLessonCountByDate(
    DateTime monthStart,
    DateTime monthEnd, {
    int? memberId,
  }) async {
    final query = _db.selectOnly(_db.lessons)
      ..addColumns([_db.lessons.date]);

    if (memberId != null) {
      query.join([
        innerJoin(_db.courses, _db.courses.id.equalsExp(_db.lessons.courseId)),
      ]);
      query.where(_db.lessons.date.isBiggerOrEqualValue(monthStart) &
          _db.lessons.date.isSmallerOrEqualValue(monthEnd) &
          _db.courses.memberId.equals(memberId));
    } else {
      query.where(_db.lessons.date.isBiggerOrEqualValue(monthStart) &
          _db.lessons.date.isSmallerOrEqualValue(monthEnd));
    }

    final rows = await query.get();
    final result = <DateTime, int>{};
    for (final r in rows) {
      final date = DateUtilsTool.dateOnly(r.read(_db.lessons.date)!);
      result[date] = (result[date] ?? 0) + 1;
    }
    return result;
  }

  /// 获取某天的课次（连表课程，可选成员筛选）
  /// 返回 (Lesson, Course) 列表
  Future<List<LessonWithCourse>> getLessonsWithCourseByDate(
    DateTime date, {
    int? memberId,
  }) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final query = _db.select(_db.lessons).join([
      innerJoin(_db.courses, _db.courses.id.equalsExp(_db.lessons.courseId)),
    ])
      ..where(_db.lessons.date.isBiggerOrEqualValue(start) &
          _db.lessons.date.isSmallerThanValue(end))
      ..orderBy([OrderingTerm.asc(_db.lessons.startTime)]);

    if (memberId != null) {
      query.where(_db.lessons.date.isBiggerOrEqualValue(start) &
          _db.lessons.date.isSmallerThanValue(end) &
          _db.courses.memberId.equals(memberId));
    }

    final rows = await query.get();
    return rows.map((r) {
      return LessonWithCourse(
        lesson: r.readTable(_db.lessons),
        course: r.readTable(_db.courses),
      );
    }).toList();
  }

  /// 按日期范围 [from, to)（含头不含尾）获取课次（连表课程）
  /// 提醒排程用它往前看几天，而不是只看"今天"——来自Trae
  Future<List<LessonWithCourse>> getLessonsWithCourseByDateRange(
    DateTime from,
    DateTime to,
  ) async {
    final rows = await (_db.select(_db.lessons).join([
      innerJoin(_db.courses, _db.courses.id.equalsExp(_db.lessons.courseId)),
    ])
      ..where(_db.lessons.date.isBiggerOrEqualValue(from) &
          _db.lessons.date.isSmallerThanValue(to))
      ..orderBy([
        OrderingTerm.asc(_db.lessons.date),
        OrderingTerm.asc(_db.lessons.startTime),
      ]))
        .get();
    return rows.map((r) {
      return LessonWithCourse(
        lesson: r.readTable(_db.lessons),
        course: r.readTable(_db.courses),
      );
    }).toList();
  }

  /// 获取"已结束但还没记已上/未上"的课次（pending、非加课、开课时刻已过）
  /// 时刻粒度：今天 10 点的课，11 点打开也算未处理——与排程器口径一致。
  /// 用于今日页提醒条与每日催办通知。[memberId] 可选按成员筛选——来自Trae
  Future<List<LessonWithCourse>> getPendingUnrecorded({int? memberId}) async {
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    final query = _db.select(_db.lessons).join([
      innerJoin(_db.courses, _db.courses.id.equalsExp(_db.lessons.courseId)),
    ])
      ..where(_db.lessons.date.isSmallerThanValue(tomorrow) &
          _db.lessons.status.equalsValue(LessonStatus.pending) &
          _db.lessons.isExtra.equals(false))
      ..orderBy([
        OrderingTerm.desc(_db.lessons.date),
        OrderingTerm.asc(_db.lessons.startTime),
      ]);

    if (memberId != null) {
      query.where(_db.lessons.date.isSmallerThanValue(tomorrow) &
          _db.lessons.status.equalsValue(LessonStatus.pending) &
          _db.lessons.isExtra.equals(false) &
          _db.courses.memberId.equals(memberId));
    }

    final rows = await query.get();
    return rows.where((r) {
      final l = r.readTable(_db.lessons);
      final startsAt =
          l.date.add(Duration(minutes: DateUtilsTool.parseMinutes(l.startTime)));
      return !startsAt.isAfter(now);
    }).map((r) {
      return LessonWithCourse(
        lesson: r.readTable(_db.lessons),
        course: r.readTable(_db.courses),
      );
    }).toList();
  }
}

/// 课次 + 课程 的聚合模型（连表查询结果）
/// 来自Trae
class LessonWithCourse {
  final Lesson lesson;
  final Course course;
  const LessonWithCourse({required this.lesson, required this.course});
}
