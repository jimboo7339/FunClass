import 'package:drift/drift.dart';

/// WebDAV 备份配置表
/// 通常只有一条记录（id=1）
/// 来自Trae
class BackupConfigs extends Table {
  /// 主键自增
  IntColumn get id => integer().autoIncrement()();

  /// WebDAV 服务器地址
  TextColumn get webdavUrl => text()();

  /// 用户名
  TextColumn get username => text()();

  /// 密码（加密存储）
  TextColumn get password => text()();

  /// 最后同步时间（可空）
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  /// 是否开启自动同步
  BoolColumn get autoSync => boolean().withDefault(const Constant(false))();
}
