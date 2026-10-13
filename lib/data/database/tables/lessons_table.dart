import 'package:drift/drift.dart';

import '../../models/enums.dart';
import 'courses_table.dart';

/// 课次表
/// 一条记录代表某课程在某天的一次课
/// 来自Trae
class Lessons extends Table {
  /// 主键自增
  IntColumn get id => integer().autoIncrement()();

  /// 所属课程 id，级联删除：删课程时自动删其所有课次——来自Trae
  IntColumn get courseId => integer().references(Courses, #id,
      onDelete: KeyAction.cascade)();

  /// 上课日期
  DateTimeColumn get date => dateTime()();

  /// 开始时间 "HH:mm"
  TextColumn get startTime => text()();

  /// 结束时间 "HH:mm"
  TextColumn get endTime => text()();

  /// 状态：pending / attended / skipped
  TextColumn get status => textEnum<LessonStatus>()();

  /// 是否手动加课（独立于频率规则）
  BoolColumn get isExtra => boolean().withDefault(const Constant(false))();

  /// 备注（可空）
  TextColumn get note => text().nullable()();

  /// 实际操作时间（可空，attended 时记录）
  DateTimeColumn get attendedAt => dateTime().nullable()();
}
