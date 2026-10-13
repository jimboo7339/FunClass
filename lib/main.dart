import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/providers/app_icon_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/today_reminders.dart';
import 'data/providers/backup_auto_sync.dart';
import 'data/providers/repository_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化中文日期格式化 来自Trae
  await initializeDateFormatting('zh_CN', null);
  // 初始化通知服务并请求权限
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermission();

  // 创建 ProviderScope 并加载持久化的主题设置
  final container = ProviderContainer();
  await container.read(appThemeProvider.notifier).load();
  await container.read(appSettingsProvider.notifier).load();
  _applyNotificationSettings(container.read(appSettingsProvider));

  runApp(UncontrolledProviderScope(
    container: container,
    child: const FunClassApp(),
  ));

  // 桌面图标自愈：启动后问一次系统当前生效的是哪个 alias。
  // 万一所有 alias 都被禁用了（系统重置过应用状态之类），桌面上就再没有启动入口，
  // 用户连 App 都打不开、更进不了设置页；原生侧读到这个情况会把默认图标重新启用。
  // 必须放在第一帧之后：method channel 要等引擎挂好才可用。——来自Trae
  WidgetsBinding.instance.addPostFrameCallback((_) {
    container.read(appIconProvider.notifier).load();
  });

  // 回到前台时重排当天提醒（覆盖 23:50 打开 App 挂到跨天、
  // 当天日程被新数据覆盖等场景）
  WidgetsBinding.instance.addObserver(_NotificationLifecycleObserver());

  // 先把排程收敛成「未来 = 剩余课时」：漏上的自动后延、上过的尾部裁减，
  // 旧版本铺满有效期的超量计划也会在这次被修剪干净——来自Trae
  await container.read(lessonPlannerProvider).syncAll();

  // 启动后排程当天的课次提醒
  await rescheduleTodayNotifications();
  // 启动时若开启自动同步则上传备份
  container.read(backupAutoSyncProvider).trigger();
}

void _applyNotificationSettings(AppSettings settings) {
  NotificationService.instance.setEnabled(settings.notificationsEnabled);
  NotificationService.instance.setLeadMinutes(settings.reminderLeadTime.minutes);
}

/// App 生命周期监听：回到前台时重排当天课次提醒
class _NotificationLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      rescheduleTodayNotifications();
    }
  }
}
