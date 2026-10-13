import 'package:drift/drift.dart';

import '../models/enums.dart';
import '../models/schedule_rule.dart';
import 'converters/schedule_rule_converter.dart';
import 'database_connection.dart';
import 'tables/backup_configs_table.dart';
import 'tables/courses_table.dart';
import 'tables/lessons_table.dart';
import 'tables/members_table.dart';

part 'app_database.g.dart';

/// 应用数据库（Drift / SQLite）
/// 包含四张表：成员、课程、课次、备份配置
/// 使用条件导入支持原生（NativeDatabase）和 Web（WasmDatabase）
/// 来自Trae
@DriftDatabase(tables: [
  Members,
  Courses,
  Lessons,
  BackupConfigs,
])
class AppDatabase extends _$AppDatabase {
  /// 单例
  static AppDatabase? _instance;

  AppDatabase._() : super(createDatabaseConnection());

  factory AppDatabase() {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  /// 测试用：内存数据库（仅原生平台）来自Trae
  factory AppDatabase.memory() {
    return AppDatabase._forTest(createMemoryConnection());
  }

  /// 测试用：自定义连接
  AppDatabase._forTest(super.executor);

  /// 数据库版本（表结构变更时递增）
  /// v2: 外键加级联删除（删成员→课程→课次自动清理）——来自Trae
  @override
  int get schemaVersion => 2;

  /// 版本迁移策略：v1→v2 需要重建外键（SQLite 不支持 ALTER FOREIGN KEY）
  /// 策略：先备份旧表数据 → 原生 SQL DROP → Migration API create → 恢复数据——来自Trae
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // 1. 备份旧数据（从旧版本表读出，此时仍是旧 schema）
            final oldMembers = await select(members).get();
            final oldCourses = await select(courses).get();
            final oldLessons = await select(lessons).get();
            final oldBackupConfigs = await select(backupConfigs).get();

            // 2. 原生 SQL 删表（外键级联无法用 Dart API）
            // Migrator.database 就是 GeneratedDatabase，可直接跑 customStatement——来自Trae
            final db = m.database;
            await db.customStatement('DROP TABLE IF EXISTS lessons');
            await db.customStatement('DROP TABLE IF EXISTS courses');
            await db.customStatement('DROP TABLE IF EXISTS members');
            await db.customStatement('DROP TABLE IF EXISTS backup_configs');

            // 3. 用 Migration API 重新建表（已带 ON DELETE CASCADE）
            await m.createTable(members);
            await m.createTable(courses);
            await m.createTable(lessons);
            await m.createTable(backupConfigs);

            // 4. 恢复数据
            for (final row in oldMembers) {
              await into(members).insert(row.toCompanion(false));
            }
            for (final row in oldCourses) {
              await into(courses).insert(row.toCompanion(false));
            }
            for (final row in oldLessons) {
              await into(lessons).insert(row.toCompanion(false));
            }
            for (final row in oldBackupConfigs) {
              await into(backupConfigs).insert(row.toCompanion(false));
            }
          }
        },
      );
}
