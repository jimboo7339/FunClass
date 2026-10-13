import 'package:drift/drift.dart';

import '../../models/enums.dart';

/// 成员表
/// 归档后仍在统计中可见，可切换查看归档成员
/// 来自Trae
class Members extends Table {
  /// 主键自增
  IntColumn get id => integer().autoIncrement()();

  /// 成员姓名
  TextColumn get name => text()();

  /// 成员类型：child / parent / other，存枚举名文本
  TextColumn get type => textEnum<MemberType>()();

  /// 颜色标签（十六进制颜色字符串，如 #FF2196F3）
  TextColumn get colorTag => text()();

  /// 是否已归档
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// 备注（可空）
  TextColumn get note => text().nullable()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
