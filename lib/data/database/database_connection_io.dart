// 原生平台数据库连接（iOS/Android/桌面）
// 使用 NativeDatabase + sqlite3_flutter_libs
// 来自Trae
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 原生平台：打开 SQLite 文件连接
QueryExecutor createDatabaseConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'funclass.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// 原生平台：内存数据库（仅测试用）
QueryExecutor createMemoryConnection() {
  return NativeDatabase.memory();
}
