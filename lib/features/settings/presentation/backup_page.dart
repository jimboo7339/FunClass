import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/backup_service.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/backup_auto_sync.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';

/// 备份与恢复页
/// 包含：本地导出/导入、WebDAV 配置与上传/下载
class BackupSettingsPage extends ConsumerStatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  ConsumerState<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends ConsumerState<BackupSettingsPage> {
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _autoSync = false;
  bool _busy = false; // WebDAV 操作进行中
  String _webdavError = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// 从数据库读取已有 WebDAV 配置填充表单
  Future<void> _loadConfig() async {
    final cfg = await ref.read(backupRepositoryProvider).getConfig();
    if (cfg == null || !mounted) return;
    _urlCtrl.text = cfg.webdavUrl;
    _userCtrl.text = cfg.username;
    _passCtrl.text = cfg.password;
    setState(() => _autoSync = cfg.autoSync);
  }

  /// 展示错误信息
  void _error(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('操作失败：$e')),
    );
  }

  void _info(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===== 本地备份 =====

  /// 导出：序列化后写入用户选择的位置
  /// file_picker v11 在 Android/iOS 上 saveFile 必须传 bytes——来自Trae
  /// 文件名带时间戳：连着导两次不会互相覆盖——2026-10-10
  Future<void> _exportLocal() async {
    setState(() => _busy = true);
    try {
      final json = await ref.read(backupServiceProvider).exportJson();
      final fileName = BackupService.versionedFileName(DateTime.now());
      final bytes = utf8.encode(json);
      final out = await FilePicker.saveFile(
        dialogTitle: '导出备份',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes, // 移动端必须提供 bytes 参数
      );
      if (out == null) return;
      _info('已导出到：$out');
    } catch (e) {
      _error(e);
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 导入：读取文件内容后整体覆盖恢复
  Future<void> _importLocal() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (res == null || res.files.isEmpty) return;

      final f = res.files.single;
      String content;
      if (f.bytes != null) {
        content = utf8.decode(f.bytes!);
      } else if (f.path != null) {
        content = await File(f.path!).readAsString();
      } else {
        _error('无法读取所选文件');
        return;
      }

      final summary =
          await ref.read(backupServiceProvider).restoreJson(content);
      _info('恢复完成：成员 ${summary.members}、课程 ${summary.courses}、课次 ${summary.lessons}');
    } catch (e) {
      _error(e);
    }
  }

  // ===== WebDAV =====

  /// 保存 WebDAV 配置
  Future<BackupConfig> _saveConfig() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      throw const FormatException('请输入 WebDAV 服务器地址');
    }
    final repo = ref.read(backupRepositoryProvider);
    await repo.saveConfig(BackupConfigsCompanion(
      webdavUrl: Value(url),
      username: Value(_userCtrl.text.trim()),
      password: Value(_passCtrl.text),
      autoSync: Value(_autoSync),
    ));
    return (await repo.getConfig())!;
  }

  /// 测试连接
  Future<void> _testWebdav() async {
    setState(() {
      _busy = true;
      _webdavError = '';
    });
    try {
      final cfg = await _saveConfig();
      await ref.read(backupServiceProvider).testWebdav(cfg);
      _info('连接成功');
    } catch (e) {
      setState(() => _webdavError = '$e');
      _error(e);
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 上传当前数据
  Future<void> _uploadWebdav() async {
    setState(() {
      _busy = true;
      _webdavError = '';
    });
    try {
      final cfg = await _saveConfig();
      final service = ref.read(backupServiceProvider);
      final bytes = await service.uploadToWebdav(cfg);
      await ref
          .read(backupRepositoryProvider)
          .updateLastSyncAt(cfg.id, DateTime.now());
      _info('已上传 ${(bytes / 1024).toStringAsFixed(1)} KB');
    } catch (e) {
      setState(() => _webdavError = '$e');
      _error(e);
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 下载并恢复到当前数据
  Future<void> _downloadWebdav() async {
    try {
      final cfg = await _saveConfig();
      final service = ref.read(backupServiceProvider);
      final summary = await service.downloadFromWebdav(cfg);
      if (summary == null) {
        _info('远端暂无备份文件');
        return;
      }
      await ref
          .read(backupRepositoryProvider)
          .updateLastSyncAt(cfg.id, DateTime.now());
      _info('已恢复：成员 ${summary.members}、课程 ${summary.courses}、课次 ${summary.lessons}');
    } catch (e) {
      setState(() => _webdavError = '$e');
      _error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final syncError = ref.watch(lastSyncErrorProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 自动同步失败红条：自动同步曾经完全静默，数据没传上去用户毫无感知——2026-10-10
          if (syncError != null) ...[
            Card(
              color: scheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.cloud_off_outlined,
                    color: scheme.onErrorContainer),
                title: Text('自动同步失败',
                    style:
                        TextStyle(color: scheme.onErrorContainer)),
                subtitle: Text(
                  syncError.length > 120
                      ? '${syncError.substring(0, 120)}…'
                      : syncError,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                trailing: TextButton(
                  onPressed: () => ref
                      .read(lastSyncErrorProvider.notifier)
                      .state = null,
                  child: const Text('知道了'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SectionTitle(title: '本地备份'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('导出备份'),
                  subtitle: const Text('把数据存为备份文件'),
                  enabled: !_busy,
                  onTap: _exportLocal,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('导入恢复'),
                  subtitle: const Text('从备份文件恢复（覆盖当前数据）'),
                  onTap: () => _confirmImport(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle(title: 'WebDAV 云备份'),
          const SizedBox(height: 8),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'https://example.com/dav',
                      prefixIcon: Icon(Icons.cloud_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userCtrl,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自动同步'),
                    subtitle: const Text('每次启动或数据变更时自动上传'),
                    value: _autoSync,
                    onChanged: (v) => setState(() => _autoSync = v),
                  ),
                  if (_webdavError.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _webdavError,
                      style: TextStyle(color: scheme.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _testWebdav,
                          icon: const Icon(Icons.wifi_tethering),
                          label: const Text('测试'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _uploadWebdav,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('上传'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _downloadWebdav,
                          icon: const Icon(Icons.cloud_download_outlined),
                          label: const Text('下载'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const _LastSyncLabel(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 远端历史版本：每次上传留一份带时间戳的快照，可挑着恢复——2026-10-10
          const _VersionHistorySection(),
          const SizedBox(height: 16),
          Text(
            '说明：导出文件为 JSON 格式，可在本应用或其它支持设备上导入恢复。'
            'WebDAV 密码保存在系统安全存储（Keystore/Keychain）里，不落明文。'
            '每次上传会在服务器保留最近 ${BackupService.keepVersions} 个历史版本。',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 导入前二次确认（覆盖会清空现有数据）
  Future<void> _confirmImport() async {
    final ok = await showConfirmSheet(
      context,
      title: '导入恢复',
      message: '导入会用备份数据覆盖当前全部成员、课程和课次。确定继续吗？',
      confirmLabel: '恢复',
      destructive: true,
    );
    if (ok == true) await _importLocal();
  }
}

/// 区块标题
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 显示最后同步时间
class _LastSyncLabel extends ConsumerStatefulWidget {
  const _LastSyncLabel();

  @override
  ConsumerState<_LastSyncLabel> createState() => _LastSyncLabelState();
}

class _LastSyncLabelState extends ConsumerState<_LastSyncLabel> {
  BackupConfig? _cfg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await ref.read(backupRepositoryProvider).getConfig();
    if (mounted) setState(() => _cfg = cfg);
  }

  @override
  Widget build(BuildContext context) {
    final t = _cfg?.lastSyncAt;
    final label = t == null
        ? '尚未同步'
        : '最近同步：${DateFormat('yyyy-MM-dd HH:mm').format(t)}';
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
/// 远端备份历史：上传时自动留快照，可恢复到任一版本或删除——2026-10-10
class _VersionHistorySection extends ConsumerStatefulWidget {
  const _VersionHistorySection();

  @override
  ConsumerState<_VersionHistorySection> createState() =>
      _VersionHistorySectionState();
}

class _VersionHistorySectionState
    extends ConsumerState<_VersionHistorySection> {
  bool _loading = false;
  bool _loaded = false;
  List<String> _versions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var versions = const <String>[];
    var loaded = false;
    try {
      final cfg = await ref.read(backupRepositoryProvider).getConfig();
      if (cfg != null && cfg.webdavUrl.trim().isNotEmpty) {
        versions = await ref.read(backupServiceProvider).listWebdavVersions(cfg);
      }
      loaded = true;
    } catch (e) {
      loaded = true; // 拉取失败时下方展示重试入口
    }
    if (!mounted) return;
    setState(() {
      _versions = versions;
      _loaded = loaded;
      _loading = false;
    });
  }

  /// funclass_backup_20261010_173000.json → 2026-10-10 17:30:00
  String _pretty(String name) {
    final m = RegExp(r'_(\d{8})_(\d{6})\.json$').firstMatch(name);
    if (m == null) return name;
    final d = m.group(1)!;
    final t = m.group(2)!;
    return '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)} '
        '${t.substring(0, 2)}:${t.substring(2, 4)}:${t.substring(4, 6)}';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _restore(String name) async {
    final ok = await showConfirmSheet(
      context,
      title: '恢复历史版本',
      message: '将用 ${_pretty(name)} 这份备份覆盖当前全部成员、课程和课次。确定继续吗？',
      confirmLabel: '恢复',
      destructive: true,
    );
    if (ok != true) return;
    try {
      final cfg = await ref.read(backupRepositoryProvider).getConfig();
      if (cfg == null) return;
      setState(() => _loading = true);
      final summary =
          await ref.read(backupServiceProvider).restoreWebdavVersion(cfg, name);
      if (summary == null) {
        _toast('远端已无该版本');
      } else {
        _toast('已恢复：成员 ${summary.members}、课程 ${summary.courses}、课次 ${summary.lessons}');
      }
    } catch (e) {
      _toast('恢复失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String name) async {
    final ok = await showConfirmSheet(
      context,
      title: '删除历史版本',
      message: '删除服务器上的 ${_pretty(name)} 这份备份？删了就找不回来了。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (ok != true) return;
    try {
      final cfg = await ref.read(backupRepositoryProvider).getConfig();
      if (cfg == null) return;
      await ref.read(backupServiceProvider).deleteWebdavVersion(cfg, name);
      _toast('已删除该版本');
      await _load();
    } catch (e) {
      _toast('删除失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle(title: '服务器备份历史')),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: '刷新',
            ),
          ],
        ),
        const SizedBox(height: 8),
        GlassCard(
          child: Column(
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!_loaded || _versions.isEmpty)
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text(_loaded ? '暂无历史版本' : '请先配置 WebDAV'),
                  subtitle: Text(_loaded
                      ? '点「上传」后会按时间戳自动留一份快照'
                      : '填好服务器地址后这里会列出远端备份'),
                  trailing: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                )
              else
                ..._versions.map((name) => ListTile(
                      leading: const Icon(Icons.history_outlined, size: 20),
                      title: Text(_pretty(name),
                          style: const TextStyle(fontSize: 14)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '恢复到这一份',
                            icon: Icon(Icons.restore, color: scheme.primary),
                            onPressed: () => _restore(name),
                          ),
                          IconButton(
                            tooltip: '删除这一份',
                            icon: Icon(Icons.delete_outline,
                                color: scheme.error),
                            onPressed: () => _delete(name),
                          ),
                        ],
                      ),
                    )),
              if (_versions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '共 ${_versions.length} 份，上传超过 ${BackupService.keepVersions} 份后自动删除最旧的',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
