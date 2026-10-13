// 条件导入入口：原生平台用 NativeDatabase，Web 平台用 WasmDatabase
// 来自Trae
export 'database_connection_io.dart'
    if (dart.library.js_interop) 'database_connection_web.dart';
