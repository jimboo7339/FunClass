// drift web worker 入口文件
// 编译为 drift_worker.js 用于 Web 平台数据库支持
// 来自Trae
import 'package:drift/wasm.dart';

void main() {
  WasmDatabase.workerMainForOpen();
}
