import 'dart:convert';

/// 每周频率规则
/// 示例：每周五 17:30-19:00 -> ScheduleRule(weekday: 5, startTime: "17:30", endTime: "19:00")
/// weekday: 1(周一) ~ 7(周日)，与 Dart DateTime.weekday 一致
/// 来自Trae
class ScheduleRule {
  /// 星期几，1=周一 ... 7=周日
  final int weekday;

  /// 开始时间 "HH:mm"
  final String startTime;

  /// 结束时间 "HH:mm"
  final String endTime;

  const ScheduleRule({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  /// 拷贝并修改部分字段
  /// 来自Trae
  ScheduleRule copyWith({
    int? weekday,
    String? startTime,
    String? endTime,
  }) {
    return ScheduleRule(
      weekday: weekday ?? this.weekday,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  /// 从 Map 构造（用于 JSON 反序列化）
  factory ScheduleRule.fromMap(Map<String, dynamic> map) {
    return ScheduleRule(
      weekday: map['weekday'] as int,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
    );
  }

  /// 转为 Map（用于 JSON 序列化）
  Map<String, dynamic> toMap() {
    return {
      'weekday': weekday,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  /// 从 JSON 字符串列表构造规则列表
  static List<ScheduleRule> listFromJson(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => ScheduleRule.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// 将规则列表转为 JSON 字符串
  static String listToJson(List<ScheduleRule> rules) {
    return jsonEncode(rules.map((e) => e.toMap()).toList());
  }

  @override
  String toString() => 'ScheduleRule(weekday: $weekday, $startTime-$endTime)';
}
