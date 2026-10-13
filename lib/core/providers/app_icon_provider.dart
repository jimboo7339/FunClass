import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一款可选的桌面启动图标
///
/// [id] 要同时对上三处：AndroidManifest.xml 里的 activity-alias 名、
/// MainActivity.kt 的 iconAliases 映射、以及 `assets/icons/launcher/<id>.png`
/// 预览图（后两者由 tool/icon_design 下的脚本生成）。——来自Trae
class AppIconOption {
  const AppIconOption(this.id, this.label);

  final String id;
  final String label;

  /// 设置页里显示的预览图
  String get previewAsset => 'assets/icons/launcher/$id.png';
}

/// 候选图标，顺序即设置页里的排列顺序
const List<AppIconOption> appIconOptions = [
  AppIconOption('classic', '经典'),
  AppIconOption('puzzle', '拼图'),
  AppIconOption('smile', '笑脸'),
  AppIconOption('book', '书本'),
  AppIconOption('spark', '星火'),
];

/// 桌面图标选择
///
/// 状态不在 SharedPreferences 里另存一份：Android 那边「哪个 activity-alias 被启用」
/// 本身就是持久化的真相，再存一份只会在两者不一致时（比如用户在系统里重置过应用）
/// 显示一个和桌面不符的选中项。每次进设置页直接问系统。——来自Trae
class AppIconNotifier extends StateNotifier<String> {
  AppIconNotifier() : super('classic');

  static const MethodChannel _channel =
      MethodChannel('com.funclass.funclass/app_icon');

  /// 只有安卓能换桌面图标，其它平台直接隐藏这个设置项
  static bool get supported => defaultTargetPlatform == TargetPlatform.android;

  /// 读取桌面当前生效的图标
  Future<void> load() async {
    if (!supported) return;
    try {
      final id = await _channel.invokeMethod<String>('getIcon');
      if (id != null && appIconOptions.any((o) => o.id == id)) {
        state = id;
      }
    } on PlatformException {
      // 读失败就维持默认值，不影响正常使用
    } on MissingPluginException {
      // 非安卓构建或插件未注册，同样静默忽略
    }
  }

  /// 切换桌面图标；返回 null 表示成功，否则返回可以直接展示的原因
  Future<String?> setIcon(String id) async {
    if (!supported) return '当前平台不支持更换桌面图标';
    if (id == state) return null;
    try {
      // 以原生侧回读的结果为准，避免「界面说切好了、桌面没切」——来自Trae
      final applied = await _channel.invokeMethod<String>('setIcon', {'id': id});
      state = applied ?? id;
      return null;
    } on PlatformException catch (e) {
      return e.message ?? '切换图标失败';
    } on MissingPluginException {
      return '当前构建不支持更换桌面图标';
    }
  }
}

/// 桌面图标 Provider
final appIconProvider = StateNotifierProvider<AppIconNotifier, String>((ref) {
  return AppIconNotifier();
});
