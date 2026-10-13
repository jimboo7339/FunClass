import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';
import 'repository_providers.dart';

/// 最近一次自动同步的错误描述（null = 上次同步成功/未执行）。
/// 备份页展示红色提示条，App 层据此弹失败通知——2026-10-10
final lastSyncErrorProvider = StateProvider<String?>((ref) => null);

/// WebDAV 自动同步
///
/// 备份配置里开启「自动同步」并填了服务器地址后，
/// App 启动或成员/课程/课次数据变化时自动上传备份。
/// 带进行中守卫 + 1 分钟去抖。失败不再静默：记 [lastSyncErrorProvider]
/// 并弹一条通知（点通知直接进备份设置页）；下次成功自动清除——2026-10-10
class BackupAutoSync {
  BackupAutoSync(this.ref);

  final Ref ref;

  bool _inProgress = false;
  DateTime? _lastTriggered;

  /// 触发一次自动同步（条件不满足或正在同步/刚同步过则直接返回）
  void trigger() {
    if (_inProgress) return;
    final now = DateTime.now();
    final last = _lastTriggered;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _lastTriggered = now;
    _inProgress = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final repo = ref.read(backupRepositoryProvider);
      final cfg = await repo.getConfig();
      if (cfg == null || !cfg.autoSync) return;
      if (cfg.webdavUrl.trim().isEmpty) return;
      final service = ref.read(backupServiceProvider);
      await service.uploadToWebdav(cfg);
      await repo.updateLastSyncAt(cfg.id, DateTime.now());
      // 成功：清掉上次的错误提示与失败通知
      if (ref.read(lastSyncErrorProvider) != null) {
        ref.read(lastSyncErrorProvider.notifier).state = null;
        await NotificationService.instance.cancelSyncFailed();
      }
    } catch (e) {
      // 失败：不再完全静默——页面红条 + 一条通知——2026-10-10
      ref.read(lastSyncErrorProvider.notifier).state = e.toString();
      await NotificationService.instance.showSyncFailed('自动同步失败：$e');
    } finally {
      _inProgress = false;
    }
  }
}

final backupAutoSyncProvider = Provider<BackupAutoSync>(
    (ref) => BackupAutoSync(ref));