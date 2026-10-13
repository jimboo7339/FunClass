import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:webdav_client/webdav_client.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/schedule_rule.dart';

/// 备份/恢复服务
///
/// 备份采用跨平台的 JSON 快照：导出 成员/课程/课次 三张业务表，
/// 保留主键 id（保持课次->课程、课程->成员的外键关系）。
/// 支持：
///  - 本地：由上层用 FilePicker 落盘/读取（本服务只负责数据序列化）
///  - WebDAV：通过 webdav_client 上传/下载 JSON 快照
/// 来自Trae
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// 备份文件名（固定，WebDAV 与本地通用）
  static const String fileName = 'funclass_backup.json';

  /// WebDAV 远端目录——来自Trae
  static const String remoteDir = '/FunClass/';

  /// 远端保留的历史版本数（超出按时间倒序删除最旧的）——2026-10-10
  static const int keepVersions = 10;

  /// 历史版本文件名：funclass_backup_20261010_173000.json
  static String versionedFileName(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'funclass_backup_${at.year}${two(at.month)}${two(at.day)}'
        '_${two(at.hour)}${two(at.minute)}${two(at.second)}.json';
  }

  static final RegExp _versionPattern =
      RegExp(r'^funclass_backup_\d{8}_\d{6}\.json$');

  /// 导出一份 JSON 字符串（成员 + 课程 + 课次）
  Future<String> exportJson() async {
    final members = await _db.select(_db.members).get();
    final courses = await _db.select(_db.courses).get();
    final lessons = await _db.select(_db.lessons).get();

    final data = <String, dynamic>{
      'app': 'funclass',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'members': members.map(_memberToMap).toList(),
      'courses': courses.map(_courseToMap).toList(),
      'lessons': lessons.map(_lessonToMap).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 从备份 JSON 恢复数据。
  /// [replace] 为 true 时整体覆盖（清空三类业务表再写入）；否则合并（按 id 去重 upsert）。
  /// 返回导入后的行数统计。
  Future<BackupSummary> restoreJson(
    String json, {
    bool replace = true,
  }) async {
    final map = jsonDecode(json) as Map<String, dynamic>;
    if (map['app'] != 'funclass') {
      throw const FormatException('不是有效的趣课备份文件');
    }

    final members =
        (map['members'] as List? ?? []).cast<Map<String, dynamic>>();
    final courses =
        (map['courses'] as List? ?? []).cast<Map<String, dynamic>>();
    final lessons =
        (map['lessons'] as List? ?? []).cast<Map<String, dynamic>>();

    return _db.transaction(() async {
      if (replace) {
        // 清空现有数据（先删子表，避免外键冲突）——来自Trae
        await _db.delete(_db.lessons).go();
        await _db.delete(_db.courses).go();
        await _db.delete(_db.members).go();
      }

      await _db.batch((batch) {
        batch.insertAll(_db.members,
            members.map(_memberFromMap).toList(growable: false),
            mode: InsertMode.insertOrReplace);
        batch.insertAll(_db.courses,
            courses.map(_courseFromMap).toList(growable: false),
            mode: InsertMode.insertOrReplace);
        batch.insertAll(_db.lessons,
            lessons.map(_lessonFromMap).toList(growable: false),
            mode: InsertMode.insertOrReplace);
      });

      return BackupSummary(
        members: members.length,
        courses: courses.length,
        lessons: lessons.length,
      );
    });
  }

  // ===== WebDAV =====

  /// 用当前配置连接 WebDAV
  Client _client(BackupConfig cfg) {
    return newClient(
      cfg.webdavUrl,
      user: cfg.username,
      password: cfg.password,
    );
  }

  /// WebDAV 远端存储路径（最新一份固定名，恢复默认拉它）
  String _remotePath() => '$remoteDir$fileName';

  /// 测试 WebDAV 连接是否可用
  Future<void> testWebdav(BackupConfig cfg) async {
    await _client(cfg).ping();
  }

  /// 上传 JSON 快照到 WebDAV：
  ///  ① 最新快照写固定名（保持老习惯：恢复默认读它）
  ///  ② 同时按时间戳存一份历史版本，远端只保留最近 [keepVersions] 份
  /// 返回上传字节数
  Future<int> uploadToWebdav(BackupConfig cfg) async {
    final json = await exportJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    final client = _client(cfg);
    await client.mkdirAll(remoteDir);
    await client.write(_remotePath(), bytes);
    await client.write(
        '$remoteDir${versionedFileName(DateTime.now())}', bytes);
    await _pruneOldVersions(client);
    return bytes.length;
  }

  /// 历史版本列表（新 → 旧），只含带时间戳的版本文件
  Future<List<String>> listWebdavVersions(BackupConfig cfg) async {
    final entries = await _client(cfg).readDir(remoteDir);
    final names = entries
        .map((f) => f.name ?? '')
        .where((name) => _versionPattern.hasMatch(name))
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return names;
  }

  /// 恢复指定历史版本；文件不存在返回 null
  Future<BackupSummary?> restoreWebdavVersion(
      BackupConfig cfg, String versionFileName) async {
    final bytes = await _client(cfg).read('$remoteDir$versionFileName');
    if (bytes.isEmpty) return null;
    return restoreJson(utf8.decode(bytes));
  }

  /// 删除远端历史版本（不动固定名的最新快照）
  Future<void> deleteWebdavVersion(BackupConfig cfg, String versionFileName) async {
    await _client(cfg).remove('$remoteDir$versionFileName');
  }

  /// 远端历史版本超过上限时，从最旧的开始删
  Future<void> _pruneOldVersions(Client client) async {
    try {
      final entries = await client.readDir(remoteDir);
      final versions = entries
          .map((f) => f.name ?? '')
          .where((name) => _versionPattern.hasMatch(name))
          .toList()
        ..sort((a, b) => b.compareTo(a)); // 新 → 旧
      for (final stale in versions.skip(keepVersions)) {
        await client.remove('$remoteDir$stale');
      }
    } catch (e) {
      // 清理失败不影响本次上传
    }
  }

  /// 从 WebDAV 下载 JSON 快照并恢复
  /// 返回恢复统计；远端无文件时返回 null
  Future<BackupSummary?> downloadFromWebdav(BackupConfig cfg) async {
    final bytes = await _client(cfg).read(_remotePath());
    if (bytes.isEmpty) return null;
    return restoreJson(utf8.decode(bytes));
  }

  // ===== 序列化 / 反序列化 =====

  /// 成员 -> Map
  Map<String, dynamic> _memberToMap(Member m) {
    return {
      'id': m.id,
      'name': m.name,
      'type': m.type.name,
      'colorTag': m.colorTag,
      'archived': m.archived,
      'note': m.note,
      'createdAt': m.createdAt.toIso8601String(),
    };
  }

  /// Map -> 成员（保留原 id）
  Member _memberFromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as int,
      name: map['name'] as String,
      type: MemberType.values.byName(map['type'] as String),
      colorTag: map['colorTag'] as String,
      archived: map['archived'] as bool? ?? false,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// 课程 -> Map
  Map<String, dynamic> _courseToMap(Course c) {
    return {
      'id': c.id,
      'memberId': c.memberId,
      'name': c.name,
      'colorTag': c.colorTag,
      'totalAmount': c.totalAmount,
      'totalLessons': c.totalLessons,
      'validFrom': c.validFrom.toIso8601String(),
      'validTo': c.validTo.toIso8601String(),
      'schedules': c.schedules.map((r) => r.toMap()).toList(),
      'note': c.note,
      'createdAt': c.createdAt.toIso8601String(),
    };
  }

  /// Map -> 课程（保留原 id）
  Course _courseFromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as int,
      memberId: map['memberId'] as int,
      name: map['name'] as String,
      colorTag: map['colorTag'] as String?,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      totalLessons: map['totalLessons'] as int,
      validFrom: DateTime.parse(map['validFrom'] as String),
      validTo: DateTime.parse(map['validTo'] as String),
      schedules: (map['schedules'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ScheduleRule.fromMap)
          .toList(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// 课次 -> Map
  Map<String, dynamic> _lessonToMap(Lesson l) {
    return {
      'id': l.id,
      'courseId': l.courseId,
      'date': l.date.toIso8601String(),
      'startTime': l.startTime,
      'endTime': l.endTime,
      'status': l.status.name,
      'isExtra': l.isExtra,
      'note': l.note,
      'attendedAt': l.attendedAt?.toIso8601String(),
    };
  }

  /// Map -> 课次（保留原 id）
  Lesson _lessonFromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'] as int,
      courseId: map['courseId'] as int,
      date: DateTime.parse(map['date'] as String),
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      status: LessonStatus.values.byName(map['status'] as String),
      isExtra: map['isExtra'] as bool? ?? false,
      note: map['note'] as String?,
      attendedAt: map['attendedAt'] == null
          ? null
          : DateTime.parse(map['attendedAt'] as String),
    );
  }
}

/// 恢复结果统计
class BackupSummary {
  final int members;
  final int courses;
  final int lessons;
  const BackupSummary({
    required this.members,
    required this.courses,
    required this.lessons,
  });
}