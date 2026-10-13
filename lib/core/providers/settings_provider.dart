import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/today_reminders.dart';

/// 通知提前量（分钟）
enum ReminderLeadTime {
  minutes30(30, '30 分钟'),
  minutes60(60, '1 小时'),
  minutes120(120, '2 小时');

  const ReminderLeadTime(this.minutes, this.label);
  final int minutes;
  final String label;
}

/// 应用设置（通知等）
class AppSettings {
  final ReminderLeadTime reminderLeadTime;
  final bool notificationsEnabled;

  const AppSettings({
    this.reminderLeadTime = ReminderLeadTime.minutes60,
    this.notificationsEnabled = true,
  });

  AppSettings copyWith({
    ReminderLeadTime? reminderLeadTime,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      reminderLeadTime: reminderLeadTime ?? this.reminderLeadTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const _keyLeadTime = 'reminder_lead_minutes';
  static const _keyNotifications = 'notifications_enabled';

  AppSettingsNotifier() : super(const AppSettings());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_keyLeadTime) ?? 60;
    final enabled = prefs.getBool(_keyNotifications) ?? true;
    final lead = ReminderLeadTime.values.firstWhere(
      (e) => e.minutes == minutes,
      orElse: () => ReminderLeadTime.minutes60,
    );
    state = AppSettings(
      reminderLeadTime: lead,
      notificationsEnabled: enabled,
    );
  }

  Future<void> setReminderLeadTime(ReminderLeadTime lead) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLeadTime, lead.minutes);
    state = state.copyWith(reminderLeadTime: lead);
    await _applyNotifications();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, enabled);
    state = state.copyWith(notificationsEnabled: enabled);
    await _applyNotifications();
  }

  /// 把当前设置即时应用到通知服务：
  /// 关闭 → 取消所有已排程提醒；开启/改提前量 → 立刻重排当天提醒
  Future<void> _applyNotifications() async {
    NotificationService.instance.setEnabled(state.notificationsEnabled);
    NotificationService.instance.setLeadMinutes(state.reminderLeadTime.minutes);
    if (!state.notificationsEnabled) {
      await NotificationService.instance.cancelAll();
    } else {
      await rescheduleTodayNotifications();
    }
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});
