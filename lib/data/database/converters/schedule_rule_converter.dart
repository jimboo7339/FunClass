import 'package:drift/drift.dart';

import '../../models/schedule_rule.dart';

/// ScheduleRule 列表 <-> JSON 字符串 的 TypeConverter
/// 用于 Courses.schedules 字段
/// 来自Trae
class ScheduleRuleConverter extends TypeConverter<List<ScheduleRule>, String> {
  const ScheduleRuleConverter();

  @override
  List<ScheduleRule> fromSql(String fromDb) {
    return ScheduleRule.listFromJson(fromDb);
  }

  @override
  String toSql(List<ScheduleRule> value) {
    return ScheduleRule.listToJson(value);
  }
}
