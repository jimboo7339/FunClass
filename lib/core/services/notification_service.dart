import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/enums.dart';
import '../../data/repositories/lesson_repository.dart';
import '../utils/date_utils.dart';

/// 通知交互事件：用户点了通知本体（actionId 为空）或点了快捷按钮
/// [actionId] 为 mark_attended / mark_skipped——由 App 层（HomeShell）消费，
/// 负责切 Tab、定位日期、改状态——2026-10-10
class NotificationEvent {
  const NotificationEvent({required this.actionId, required this.payload});

  /// 空字符串 = 点通知本体；否则为快捷操作按钮 id
  final String actionId;
  final String payload;
}

/// 提醒诊断快照：把「权限没批 / 排程抛异常 / 一条都没排上」这类静默失败
/// 变成设置页可见的状态，并给出一键修复入口。——来自Trae
class ReminderDiagnosis {
  const ReminderDiagnosis({
    this.notificationsAllowed,
    this.exactAlarmsAllowed,
    this.pendingCount = 0,
    this.lastError,
  });

  /// 系统通知权限（null = 本平台查不到）
  final bool? notificationsAllowed;

  /// Android 12+ 精确闹钟（「闹钟和提醒」）权限，null = 查不到/低版本自动可用
  final bool? exactAlarmsAllowed;

  /// 当前已排程、尚未触发的提醒条数
  final int pendingCount;

  /// 最近一次排程失败的原因
  final String? lastError;
}

/// 本地通知服务
///
/// 排程入口 [scheduleUpcomingLessons]：对「未来几天 pending 课次」做一次
/// **幂等同步**——撤销过期的、补上缺失的、没变化的不动。
/// 早期版本每次重排先 `cancelAll()`，副作用是把通知栏里刚弹出、用户还没看到的
/// 提醒一起抹掉，看起来就像"通知没触发"；现在改成按课次 id 精确取消。——来自Trae
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'funclass_lesson_reminder';
  static const String _channelName = '课程提醒';
  static const String _channelDesc = '上课前提醒';

  /// 「过期未处理」每日催办通知的固定 id（课次 id 从 1 递增，不会撞）——来自Trae
  static const int _overdueReminderId = 9001;
  /// 每日催办的固定时刻
  static const int _overdueReminderHour = 9;

  /// 「课程到期 / 课时将尽」每日预警的固定 id，比催办晚 5 分钟——2026-10-10
  static const int _expiryWarningId = 9002;
  static const int _expiryWarningHour = 9;
  static const int _expiryWarningMinute = 5;

  /// 自动备份失败通知的固定 id（立即弹出，非排程）——2026-10-10
  static const int _syncFailedId = 9003;

  /// 固定 id 集合：这些不是课次排程，撤销时不能误删
  static const Set<int> _fixedIds = {
    _overdueReminderId,
    _expiryWarningId,
    _syncFailedId,
  };

  /// 快捷按钮 action id——2026-10-10
  static const String actionAttended = 'mark_attended';
  static const String actionSkipped = 'mark_skipped';

  /// payload 前缀——2026-10-10
  static const String payloadExpiry = 'expiry_warning';
  static const String payloadSyncFailed = 'sync_failed';

  /// 冷启动时点通知进来，App 层订阅可能还没挂上；
  /// 先缓存一条，等第一个监听者进来补发——2026-10-10
  NotificationEvent? _pendingEvent;

  // 用 late final：字段初始化器里不能引用实例成员（_pendingEvent），
  // 首次访问发生在构造完成之后，onListen 闭包这时才执行——2026-10-10
  late final StreamController<NotificationEvent> _events =
      StreamController<NotificationEvent>.broadcast(
    onListen: () {
      final pending = _pendingEvent;
      _pendingEvent = null;
      if (pending != null) {
        scheduleMicrotask(() => _events.add(pending));
      }
    },
  );

  /// 通知点击 / 快捷操作事件流（主 isolate），App 层订阅处理跳转与改状态
  Stream<NotificationEvent> get events => _events.stream;

  bool _initialized = false;
  bool _enabled = true;
  int _leadMinutes = 60;
  String? _lastError;

  void setEnabled(bool enabled) => _enabled = enabled;
  void setLeadMinutes(int minutes) => _leadMinutes = minutes;

  /// 单次排程保留的精确闹钟上限。排程窗口拉长后一次可能排出几十条，
  /// Android 对单 App 精确闹钟有配额、部分厂商更严，
  /// 超出时只留提醒时刻最近的这些——2026-10-11
  static const int maxScheduledAlarms = 48;

  /// 把 tz.local 设成和设备一致的时区。
  ///
  /// timezone 包的 tz.local 默认是 **UTC**，`initializeTimeZones()` 只装时区库、
  /// 不会解析设备时区（旧注释以为会自动解析，是错的）。一次性闹钟走
  /// `TZDateTime.from`（保留绝对时刻）不受影响，但"每天固定时刻"的重复通知
  /// 是按 tz.local 的墙上时钟算下一次的——不修的话国内每天 09:00 的催办
  /// 实际在 17:00 才响。这里按当前 UTC 偏移在时区库里挑一个匹配的时区。——2026-10-11
  void _syncLocalTimeZone() {
    final now = DateTime.now();
    try {
      // 判据用"墙上时钟是否和设备一致"：同一时刻在该时区读出来的时分相同，
      // 就是设备所在时区。再看半年后那一版，把"现在同偏移但夏令时规则不同"
      // 的别名时区筛掉（国内不实行夏令时，任何 +8 时区结果都等价）。
      final later = now.add(const Duration(days: 180));
      bool sameWallClock(tz.Location l, DateTime t) {
        final inLoc = tz.TZDateTime.from(t, l);
        return inLoc.hour == t.hour && inLoc.minute == t.minute;
      }

      final candidates = tz.timeZoneDatabase.locations.values
          .where((l) => sameWallClock(l, now) && sameWallClock(l, later))
          .toList();
      if (candidates.isEmpty) return;
      // 优先城市型时区名：Etc/GMT+8 这类 POSIX 别名符号是反的，别选到
      int score(String name) => name.startsWith('Asia/')
          ? 0
          : name.contains('/')
              ? 1
              : 2;
      candidates.sort((a, b) => score(a.name).compareTo(score(b.name)));
      tz.setLocalLocation(tz.getLocation(candidates.first.name));
    } catch (e) {
      debugPrint('[Notification] 设备时区解析失败，重复通知可能按 UTC 时钟触发: $e');
    }
  }

  /// 立刻发一条测试通知：设置页用它当场验证"通知到底能不能弹"，
  /// 不用等下一节课——2026-10-11
  Future<void> sendTestNotification() async {
    if (!_initialized) await init();
    if (kIsWeb) return;
    final now = DateTime.now();
    await _notifications.show(
      9100,
      '测试通知',
      '如果你能看到这条，说明通知链路是通的（${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}）',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// 初始化通知（设置时区、Android 渠道、权限）
  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    _syncLocalTimeZone();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        // 主 isolate 处理：点通知跳转 / 快捷按钮改状态
        _handleResponse(NotificationEvent(
          actionId: response.actionId ?? '',
          payload: response.payload ?? '',
        ));
      },
    );

    // 创建 Android 通知渠道
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ));

    _initialized = true;
  }

  /// 请求通知权限（含 Android 精确闹钟权限）
  Future<bool> requestPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      // Android 12+ 精确闹钟权限（用于 exactAllowWhileIdle）
      await android.requestExactAlarmsPermission();
      return granted;
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// 幂等同步提醒排程。
  /// [lessons] 为未来几天窗口内的课次（含课程信息）；[unrecordedCount] 为
  /// "已结束但还没记已上/未上"的课次数——>0 时挂每日 09:00 催办通知，
  /// 清零时自动取消。内部只处理 pending 且"提醒时刻还没过"的：
  /// - 已排程里过期的（改期/已标记上掉/提醒时刻已过）→ 按 id 取消
  /// - 目标里缺的 → 排程；payload 记着提醒时刻，时间没变就不重排
  Future<void> scheduleUpcomingLessons(
    List<LessonWithCourse> lessons, {
    int unrecordedCount = 0,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return; // Web 不支持本地通知排程

    final now = DateTime.now();

    // 目标态：希望系统里存在的提醒
    final desired =
        <int, ({DateTime remindAt, DateTime lessonDate, String body})>{};
    if (_enabled) {
      for (final item in lessons) {
        final lesson = item.lesson;
        if (lesson.status != LessonStatus.pending) continue;

        // 提醒时间 = 上课日 + 开始时间 - 提前量
        final lessonStart = lesson.date.add(
          Duration(minutes: DateUtilsTool.parseMinutes(lesson.startTime)),
        );
        final remindAt =
            lessonStart.subtract(Duration(minutes: _leadMinutes));

        // 提醒时刻已过就不排（避免"迟到提醒"）
        if (!remindAt.isAfter(now)) continue;

        desired[lesson.id] = (
          remindAt: remindAt,
          lessonDate: DateUtilsTool.dateOnly(lesson.date),
          body: '${item.course.name} 将在 ${lesson.startTime} 开始',
        );
      }
    }

    // 超出配额时只保留提醒时刻最近的 N 条——2026-10-11
    if (desired.length > maxScheduledAlarms) {
      final sorted = desired.entries.toList()
        ..sort((a, b) => a.value.remindAt.compareTo(b.value.remindAt));
      desired
        ..clear()
        ..addEntries(sorted.take(maxScheduledAlarms));
    }

    // 读取已排程列表可能失败（如 R8 剥掉 Gson 泛型签名）；失败时降级为
    // "只补排、不撤销"，别连累排程本身——提醒宁可多留一条过期闹钟也不能静默丢失——来自Trae
    List<PendingNotificationRequest> pending = const [];
    try {
      pending = await _notifications.pendingNotificationRequests();
    } catch (e) {
      _lastError = '读取已排程提醒失败（本次只补排不撤销）：$e';
      debugPrint('[Notification] $_lastError');
    }
    final pendingById = {for (final p in pending) p.id: p};

    // 1) 撤掉过期的。只 cancel 具体课次 id 的"排程闹钟"，
    //    不用 cancelAll——那会把通知栏里刚触发、还没看的提醒一起抹掉。
    //    固定 id（催办/到期预警/同步失败）不在 desired 里，要豁免——来自Trae
    for (final p in pending) {
      if (!_fixedIds.contains(p.id) && !desired.containsKey(p.id)) {
        await _notifications.cancel(p.id);
      }
    }

    // 2) 补上缺的（提醒时刻没变则跳过，保持幂等，避免每次回前台重设闹钟）
    for (final entry in desired.entries) {
      final target = entry.value;
      // payload：前两段供点击/快捷操作定位（课次 id + 上课日期），
      // 最后一段提醒时刻用于幂等比较——2026-10-10
      final payload = _lessonPayload(entry.key, target.lessonDate, target.remindAt);
      final existing = pendingById[entry.key];
      if (existing != null && existing.payload == payload) continue;
      try {
        await _notifications.zonedSchedule(
          entry.key, // 用课次 id 作为通知 id
          '上课提醒',
          target.body,
          tz.TZDateTime.from(target.remindAt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
              // 通知栏直接标课：点「已上课/未上课」不用进 App——2026-10-10
              actions: [
                AndroidNotificationAction(actionAttended, '已上课'),
                AndroidNotificationAction(actionSkipped, '未上课'),
              ],
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        _lastError = null;
      } catch (e) {
        _lastError = _describeScheduleFailure(e);
        debugPrint('[Notification] 排程课次 ${entry.key} 失败: $e');
      }
    }

    // 3) 过期未处理 → 每天 09:00 催办一次（重复通知）；处理完自动取消——来自Trae
    try {
      if (_enabled && unrecordedCount > 0) {
        var next = DateTime(
            now.year, now.month, now.day, _overdueReminderHour);
        if (!next.isAfter(now)) {
          next = next.add(const Duration(days: 1));
        }
        await _notifications.zonedSchedule(
          _overdueReminderId,
          '上课记录待处理',
          '有 $unrecordedCount 节课已结束，还没记「已上课/未上课」',
          tz.TZDateTime.from(next, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } else {
        await _notifications.cancel(_overdueReminderId);
      }
    } catch (e) {
      debugPrint('[Notification] 过期催办通知排程失败: $e');
    }
  }

  /// 「课程到期 / 课时将尽」每日预警：每天 09:05 一条摘要，无预警课程时自动取消
  /// 课程一旦新增/续期/改有效期，随后的重排会重新计算 body——2026-10-10
  Future<void> scheduleExpiryWarning(String body) async {
    if (!_initialized) await init();
    if (kIsWeb) return;
    try {
      if (!_enabled || body.isEmpty) {
        await _notifications.cancel(_expiryWarningId);
        return;
      }
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, _expiryWarningHour,
          _expiryWarningMinute);
      if (!next.isAfter(now)) {
        next = next.add(const Duration(days: 1));
      }
      await _notifications.zonedSchedule(
        _expiryWarningId,
        '课程到期与课时提醒',
        body,
        tz.TZDateTime.from(next, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '课程到期与课时预警',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payloadExpiry,
      );
    } catch (e) {
      debugPrint('[Notification] 到期预警通知排程失败: $e');
    }
  }

  /// 自动同步失败时立即弹一条通知，点它直接进备份设置页——2026-10-10
  Future<void> showSyncFailed(String error) async {
    if (!_initialized) await init();
    if (kIsWeb || !_enabled) return;
    try {
      await _notifications.show(
        _syncFailedId,
        '自动备份失败',
        _shorten(error, 120),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payloadSyncFailed,
      );
    } catch (e) {
      debugPrint('[Notification] 备份失败通知发送失败: $e');
    }
  }

  /// 下一次自动同步成功后撤掉失败通知——2026-10-10
  Future<void> cancelSyncFailed() async {
    if (!_initialized) await init();
    if (kIsWeb) return;
    try {
      await _notifications.cancel(_syncFailedId);
    } catch (_) {}
  }

  /// 投递一次通知交互事件：还没人订阅（冷启动）就先缓存一条
  void _handleResponse(NotificationEvent event) {
    if (_events.hasListener) {
      _events.add(event);
    } else {
      _pendingEvent = event;
    }
  }

  /// 上课提醒的 payload：lesson|<课次 id>|<上课日期 ISO>|<提醒时刻 ISO>
  /// 末段供幂等比较，前两段供点击/快捷操作定位——2026-10-10
  static String _lessonPayload(int lessonId, DateTime date, DateTime remindAt) =>
      'lesson|$lessonId|${date.toIso8601String()}|${remindAt.toIso8601String()}';

  /// 解析上课提醒 payload；不是课次 payload（如 expiry_warning）返回 null
  static ({int lessonId, DateTime date})? parseLessonPayload(String payload) {
    final parts = payload.split('|');
    if (parts.length < 3 || parts[0] != 'lesson') return null;
    final id = int.tryParse(parts[1]);
    if (id == null) return null;
    final date = DateTime.tryParse(parts[2]);
    if (date == null) return null;
    return (lessonId: id, date: DateUtilsTool.dateOnly(date));
  }

  static String _shorten(String s, int max) => s.length <= max
      ? s
      : '${s.substring(0, max)}…';

  static String _describeScheduleFailure(Object e) {
    final s = e.toString();
    if (s.contains('xact') || s.contains('SCHEDULE_EXACT_ALARM')) {
      return '缺「闹钟和提醒」权限，无法准时排程；在下方诊断里点「去开启」';
    }
    return '排程提醒失败：$s';
  }

  /// 提醒诊断快照（设置页诊断卡用）
  Future<ReminderDiagnosis> diagnose() async {
    bool? notificationsAllowed;
    bool? exactAlarmsAllowed;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      try {
        notificationsAllowed = await android.areNotificationsEnabled();
      } catch (_) {}
      try {
        exactAlarmsAllowed = await android.canScheduleExactNotifications();
      } catch (_) {}
    }
    var pendingCount = 0;
    try {
      pendingCount =
          (await _notifications.pendingNotificationRequests()).length;
    } catch (_) {}
    return ReminderDiagnosis(
      notificationsAllowed: notificationsAllowed,
      exactAlarmsAllowed: exactAlarmsAllowed,
      pendingCount: pendingCount,
      lastError: _lastError,
    );
  }

  /// 打开系统「闹钟和提醒」授权页（Android 12+；低版本直接返回 true）
  Future<bool?> requestExactAlarmsPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return android?.requestExactAlarmsPermission();
  }

  /// 请求通知权限（Android 13+；被永久拒绝时只会返回 false，需去系统设置开）
  Future<bool?> requestNotificationsPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return android?.requestNotificationsPermission();
  }

  /// 取消所有通知（关闭提醒开关时整体清空用）
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
