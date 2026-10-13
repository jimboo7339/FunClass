import 'package:drift/drift.dart';

import '../converters/schedule_rule_converter.dart';
import 'members_table.dart';

/// 课程表
/// schedules 字段以 JSON 字符串存储 ScheduleRule 列表
/// 来自Trae
class Courses extends Table {
  /// 主键自增
  IntColumn get id => integer().autoIncrement()();

  /// 所属成员 id，级联删除：删成员时自动删其所有课程——来自Trae
  IntColumn get memberId => integer().references(Members, #id,
      onDelete: KeyAction.cascade)();

  /// 课程名称
  TextColumn get name => text()();

  /// 颜色标签（可空，为空则继承成员颜色）
  TextColumn get colorTag => text().nullable()();

  /// 总金额
  RealColumn get totalAmount => real()();

  /// 总课时
  IntColumn get totalLessons => integer()();

  /// 有效期起（日期）
  DateTimeColumn get validFrom => dateTime()();

  /// 有效期止（日期，含当天）
  DateTimeColumn get validTo => dateTime()();

  /// 每周频率规则（JSON 字符串）
  TextColumn get schedules => text().map(const ScheduleRuleConverter())();

  /// 备注（可空）
  TextColumn get note => text().nullable()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
