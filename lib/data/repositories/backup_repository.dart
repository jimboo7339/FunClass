import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/services/secure_store.dart';
import '../database/app_database.dart';

/// 备份配置仓库
/// WebDAV 配置通常只有一条记录（id=1）
///
/// WebDAV 密码不放数据库：2026-10-10 起写入 SecureStore（Keystore/Keychain），
/// 数据库 password 列恒为空串；老版本库里已有的明文密码在下次 getConfig 时
/// 自动搬进安全存储并清空原列。安全存储不可用（Web/测试/老系统）时回落到旧明文，
/// 保证备份功能不被加密存储拖死。
/// 来自Trae
class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  /// 获取备份配置（通常只有一条）
  Future<BackupConfig?> getConfig() async {
    final row = await (_db.select(_db.backupConfigs)
          ..orderBy([(b) => OrderingTerm.asc(b.id)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;

    final stored = await SecureStore.readWebdavPassword();
    if (stored != null) {
      return row.copyWith(password: stored);
    }

    // 迁移：旧版本把密码明文存在库里 → 搬进安全存储并清空原列
    if (row.password.isNotEmpty) {
      final ok = await SecureStore.writeWebdavPassword(row.password);
      if (ok) {
        await (_db.update(_db.backupConfigs)
              ..where((b) => b.id.equals(row.id)))
            .write(const BackupConfigsCompanion(password: Value('')));
        debugPrint('[BackupRepository] WebDAV 密码已迁移到安全存储');
        return row.copyWith(password: '');
      }
    }
    return row;
  }

  /// 保存备份配置（不存在则插入，存在则更新）
  Future<void> saveConfig(BackupConfigsCompanion companion) async {
    // companion 带密码时先写安全存储；写成功则库里留空串
    if (companion.password.present) {
      final password = companion.password.value;
      if (password.isEmpty) {
        await SecureStore.deleteWebdavPassword();
      } else if (await SecureStore.writeWebdavPassword(password)) {
        companion = companion.copyWith(password: const Value(''));
      }
      // 写安全存储失败 → 原样落库（保持旧行为，不丢密码）
    }

    final existing = await getConfig();
    if (existing == null) {
      await _db.into(_db.backupConfigs).insert(companion);
    } else {
      await (_db.update(_db.backupConfigs)
            ..where((b) => b.id.equals(existing.id)))
          .write(companion);
    }
  }

  /// 更新最后同步时间，返回受影响行数
  Future<int> updateLastSyncAt(int id, DateTime time) {
    return (_db.update(_db.backupConfigs)..where((b) => b.id.equals(id)))
        .write(BackupConfigsCompanion(lastSyncAt: Value(time)));
  }

  /// 切换自动同步，返回受影响行数
  Future<int> updateAutoSync(int id, bool autoSync) {
    return (_db.update(_db.backupConfigs)..where((b) => b.id.equals(id)))
        .write(BackupConfigsCompanion(autoSync: Value(autoSync)));
  }
}