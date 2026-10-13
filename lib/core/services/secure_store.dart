import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 敏感凭据的安全存储（Android Keystore / iOS Keychain）。
///
/// 平台不支持、Web、或测试环境（无平台通道）时读写失败一律吞掉返回 null，
/// 由调用方回落到数据库里的旧明文值——不因为加密存储不可用就挡住用户备份——2026-10-10
class SecureStore {
  SecureStore._();

  static const String _webdavPasswordKey = 'funclass_webdav_password';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// 读 WebDAV 密码；不可用时返回 null
  static Future<String?> readWebdavPassword() async {
    if (kIsWeb) return null;
    try {
      final value = await _storage.read(key: _webdavPasswordKey);
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (e) {
      debugPrint('[SecureStore] 读取失败（回落数据库）: $e');
      return null;
    }
  }

  /// 写 WebDAV 密码；返回是否写入成功（失败时调用方保留数据库明文）
  static Future<bool> writeWebdavPassword(String password) async {
    if (kIsWeb) return false;
    try {
      await _storage.write(key: _webdavPasswordKey, value: password);
      return true;
    } catch (e) {
      debugPrint('[SecureStore] 写入失败（保留数据库明文）: $e');
      return false;
    }
  }

  /// 删除 WebDAV 密码（配置清空时用）
  static Future<void> deleteWebdavPassword() async {
    if (kIsWeb) return;
    try {
      await _storage.delete(key: _webdavPasswordKey);
    } catch (_) {}
  }
}