import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';

/// 通知交互事件流（点通知本体 / 通知栏「已上课/未上课」快捷按钮）。
/// HomeShell 订阅后负责切 Tab、定位日期、更新课次状态——2026-10-10
final notificationEventProvider = StreamProvider<NotificationEvent>(
  (ref) => NotificationService.instance.events,
);