// Web 平台数据库连接
// 使用 WasmDatabase（需要 sqlite3.wasm + drift_worker.js）
// 来自Trae
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web 平台：打开 WasmDatabase 连接
QueryExecutor createDatabaseConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'funclass',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  }));
}

/// Web 平台：内存数据库（暂不支持，仅原生测试用）
QueryExecutor createMemoryConnection() {
  throw UnsupportedError('内存数据库仅在原生平台测试中使用');
}
