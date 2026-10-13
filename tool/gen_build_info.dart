import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// 每次打包前运行本脚本，生成唯一的构建哈希与递增的构建编号并写入 lib/core/build_info.g.dart
/// 用法：bash tool/build_apk.sh（会自动先跑本脚本）
/// 构建哈希由「git 短提交号 + 当前微秒时间戳」通过 SHA-256 派生，保证每次打包都不同；
/// 构建编号存放在 tool/.build_number，持久递增，配合 flutter build --build-number 使用，
/// 这样 Android 会把它当作新版本覆盖安装，不会再提示「已安装相同版本」。
/// 来自Trae
void main() {
  final outFile = File('lib/core/build_info.g.dart');
  final counterFile = File('tool/.build_number');

  // 1. 尽量读取 git 短提交号（无 git 环境时为空）
  var commit = '';
  try {
    final r = Process.runSync('git', ['rev-parse', '--short=8', 'HEAD']);
    if (r.exitCode == 0) commit = (r.stdout as String).trim();
  } catch (_) {
    // 无 git 时不阻塞打包，来自Trae
  }
  if (commit.isEmpty) {
    commit = 'nocommit';
  }

  // 2. 递增构建编号：优先用计数器文件，缺失时以 pubspec 的 versionCode 为起点
  final pubVersion = _pubspecVersion();
  final baseCode = pubVersion.buildNumber;
  var buildNumber = baseCode + 1;
  if (counterFile.existsSync()) {
    final saved = int.tryParse(counterFile.readAsStringSync().trim());
    if (saved != null && saved >= buildNumber) {
      buildNumber = saved + 1;
    }
  }
  counterFile.writeAsStringSync('$buildNumber\n');

  // 3. 用微秒时间戳保证每次打包哈希都不同（即使未产生新提交）
  final now = DateTime.now();
  final raw = '$commit|${now.microsecondsSinceEpoch}';
  final hex = sha256.convert(raw.codeUnits).toString();

  // 用户友好的短哈希：前 10 位十六进制
  final short = hex.substring(0, 10);

  // 4. 生成人可读的构建时间
  String two(int v) => v.toString().padLeft(2, '0');
  final buildTime =
      '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';

  final content = '''
/// 本文件由 tool/gen_build_info.dart 自动生成，每次打包都会被覆盖。
/// 请勿手动编辑。来自Trae
const String buildHash = '$short';
const String buildCommit = '$commit';
const String buildTime = '$buildTime';

/// 应用版本名（与 pubspec.yaml 一致）
const String appVersion = '${pubVersion.name}';

/// Android versionCode，每次打包递增，用于覆盖安装
const int buildNumber = $buildNumber;

/// 完整版本号，如 1.0.1+12
const String fullVersion = '\$appVersion+\$buildNumber';
''';

  outFile.writeAsStringSync(content);
  stdout.writeln(
      'build info generated: $short  version: ${pubVersion.name}+$buildNumber  ($buildTime)');
}

/// 从 pubspec.yaml 解析 version: x.y.z+N
({String name, int buildNumber}) _pubspecVersion() {
  var name = '1.0.0';
  var build = 0;
  final file = File('pubspec.yaml');
  if (file.existsSync()) {
    for (final line in const LineSplitter().convert(file.readAsStringSync())) {
      final m = RegExp(r'^version:\s*([0-9.]+)\+?(\d+)?\s*$').firstMatch(line);
      if (m != null) {
        name = m.group(1)!;
        build = int.tryParse(m.group(2) ?? '0') ?? 0;
        break;
      }
    }
  }
  return (name: name, buildNumber: build);
}