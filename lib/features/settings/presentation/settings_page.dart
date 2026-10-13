import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/build_info.dart' as bi;
import '../../../core/providers/app_icon_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/today_reminders.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/page_shell.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';
import 'backup_page.dart';
import 'help_page.dart';

/// 设置页
/// 主题切换、课程提醒、强调色选择等
/// 来自Trae
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(appSettingsProvider);
    return PageShell(
      title: '设置',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 数据备份分组（置顶，确保一打开就能看到入口）——来自Trae
          _SectionTitle(title: '数据'),
          const SizedBox(height: 8),
          GlassCard(
            child: ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('备份与恢复'),
              subtitle: const Text('本地导出 / WebDAV 云备份'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BackupSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 课程提醒分组
          _SectionTitle(title: '课程提醒'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('上课前自动提醒'),
                  subtitle: Text(
                    settings.notificationsEnabled
                        ? '当前提前 ${settings.reminderLeadTime.label} 提醒'
                        : '已关闭',
                  ),
                  value: settings.notificationsEnabled,
                  onChanged: (v) => ref
                      .read(appSettingsProvider.notifier)
                      .setNotificationsEnabled(v),
                ),
                if (settings.notificationsEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text('提前量'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassSegmented<ReminderLeadTime>(
                            items: const [
                              GlassSegmentedItem<ReminderLeadTime>(
                                value: ReminderLeadTime.minutes30,
                                label: '30 分钟',
                              ),
                              GlassSegmentedItem<ReminderLeadTime>(
                                value: ReminderLeadTime.minutes60,
                                label: '1 小时',
                              ),
                              GlassSegmentedItem<ReminderLeadTime>(
                                value: ReminderLeadTime.minutes120,
                                label: '2 小时',
                              ),
                            ],
                            value: settings.reminderLeadTime,
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setReminderLeadTime(v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 开了提醒就挂诊断卡：让"排了但没发生"这类静默失败可见、可一键修——来自Trae
          if (settings.notificationsEnabled) ...[
            const SizedBox(height: 16),
            const _ReminderDiagnoseCard(),
          ],
          const SizedBox(height: 24),

          // 外观分组
          _SectionTitle(title: '外观'),
          const SizedBox(height: 8),
          _ThemeSegmentedCard(),
          const SizedBox(height: 16),
          const _AccentColorCard(),
          // 换桌面图标只有安卓做得到，其它平台连卡片都不出现——来自Trae
          if (AppIconNotifier.supported) ...[
            const SizedBox(height: 16),
            const _AppIconCard(),
          ],
          const SizedBox(height: 16),
          const _FloatingNavCard(),
          const SizedBox(height: 24),

          // 关于分组
          _SectionTitle(title: '关于'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                // 使用手册入口：完整操作说明，嵌在这里——来自Trae
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('使用手册'),
                  subtitle: const Text('排课顺延规则、提醒诊断、备份等完整说明'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpPage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('趣课 FunClass'),
                  subtitle: const Text('课外兴趣课管理 App'),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('v${bi.appVersion}',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                      // 构建哈希，用于核对安装包版本是否最新——来自Trae
                      Text(bi.buildHash,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          )),
                    ],
                  ),
                  onTap: () => _showBuildInfo(context),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('通知权限'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showNotificationInfo(context, settings);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 展示构建详细信息（提交号 / 构建时间 / 哈希），便于核对安装包——来自Trae
  void _showBuildInfo(BuildContext context) {
    showInfoSheet(
      context,
      title: '构建信息',
      message: '版本号：v${bi.appVersion}\n'
          '构建编号：${bi.buildNumber}\n'
          '完整版本：v${bi.fullVersion}\n'
          '构建哈希：${bi.buildHash}\n'
          '提交号：${bi.buildCommit}\n'
          '构建时间：${bi.buildTime}\n\n'
          '每次打包编号与哈希都会变化，手机上显示与最新安装包一致即为正确版本。',
    );
  }

  void _showNotificationInfo(BuildContext context, AppSettings settings) {
    final leadLabel =
        settings.notificationsEnabled ? settings.reminderLeadTime.label : '';
    showInfoSheet(
      context,
      title: '通知权限',
      message: settings.notificationsEnabled
          ? '上课前 $leadLabel 会自动推送提醒通知。\n如未收到，请在系统设置中检查通知权限。'
          : '课程提醒已关闭，可在「课程提醒」中开启。\n开启后上课前会自动推送通知。',
    );
  }
}

/// 区块标题
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 主题模式选择（SegmentedButton，代替三个 ListTile）——来自Trae
class _ThemeSegmentedCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSegmented<ThemeModeType>(
          items: const [
            GlassSegmentedItem<ThemeModeType>(
              value: ThemeModeType.light,
              icon: Icons.light_mode_outlined,
              label: '浅色',
            ),
            GlassSegmentedItem<ThemeModeType>(
              value: ThemeModeType.dark,
              icon: Icons.dark_mode_outlined,
              label: '深色',
            ),
            GlassSegmentedItem<ThemeModeType>(
              value: ThemeModeType.system,
              icon: Icons.brightness_auto_outlined,
              label: '系统',
            ),
          ],
          value: theme.mode,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            ref.read(appThemeProvider.notifier).setMode(v);
          },
        ),
      ),
    );
  }
}

/// 强调色选择：改这里的颜色会连锁更新 primary 体系、玻璃极光色、
/// 以及所有通用控件（普通按钮、分段控件、选中态、开关）的着色。
/// 课程色 / 成员色标是「内容色」，不跟着变——那是用户自己挑的——来自Trae
class _AccentColorCard extends ConsumerWidget {
  const _AccentColorCard();

  static const double _swatchSize = 40;
  static const double _spacing = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(appThemeProvider.notifier);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('强调色',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Text(
                  '影响按钮、分段控件、玻璃背景等通用配色',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: _spacing,
              runSpacing: _spacing,
              children: [
                for (final color in ThemeState.accentPalette)
                  _Swatch(
                    color: color,
                    selected: color.toARGB32() == theme.seedColor.toARGB32(),
                    size: _swatchSize,
                    ringColor: isDark ? Colors.white : Colors.black87,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      notifier.setSeedColor(color);
                    },
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆形色块
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.size,
    required this.ringColor,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final double size;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? ringColor : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? 0.45 : 0.22),
              blurRadius: selected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

/// 桌面图标选择卡片
///
/// 图标是原生侧的 activity-alias 开关，跟主题/强调色无关，所以不进 ThemeState；
/// 非安卓平台没有这个能力，由调用方直接不渲染。——来自Trae
class _AppIconCard extends ConsumerStatefulWidget {
  const _AppIconCard();

  @override
  ConsumerState<_AppIconCard> createState() => _AppIconCardState();
}

class _AppIconCardState extends ConsumerState<_AppIconCard> {
  @override
  void initState() {
    super.initState();
    // 选中哪一项要问系统（alias 的启用状态才是真相）。放到下一帧，
    // 免了在 build 期间改 provider 状态——来自Trae
    Future.microtask(() {
      if (mounted) ref.read(appIconProvider.notifier).load();
    });
  }

  Future<void> _pick(AppIconOption option) async {
    HapticFeedback.selectionClick();
    final error = await ref.read(appIconProvider.notifier).setIcon(option.id);
    if (!mounted || error == null) return;
    showInfoSheet(context, title: '切换失败', message: error);
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appIconProvider);
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('桌面图标',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '换完立即生效，不用重装',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final option in appIconOptions)
                  _IconChoice(
                    option: option,
                    selected: option.id == current,
                    onTap: () => _pick(option),
                  )
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '部分桌面要退回桌面、或等几秒才会刷新图标，属正常现象。',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个图标候选：预览图 + 名字，选中时描一圈主色并打勾
class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  static const double _preview = 52;

  final AppIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_preview * 0.28 + 3),
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(
                          alpha: selected ? 0.35 : 0),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Image.asset(
                  option.previewAsset,
                  width: _preview,
                  height: _preview,
                  // 预览图是构建期生成的，缺图时宁可留个占位也不能让设置页崩——来自Trae
                  errorBuilder: (_, __, ___) => Container(
                    width: _preview,
                    height: _preview,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(_preview * 0.28),
                    ),
                    child: const Icon(Icons.android, size: 28),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 1.5),
                    ),
                    child: const Icon(Icons.check,
                        size: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            option.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 悬浮导航开关：开 = 导航栏悬浮在页面底部，关 = 贴底标准导航栏
class _FloatingNavCard extends ConsumerWidget {
  const _FloatingNavCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    return GlassCard(
      child: SwitchListTile(
        title: const Text('悬浮导航'),
        subtitle: const Text('开启后导航栏悬浮在屏幕底部，关闭为贴底标准导航'),
        value: theme.isFloatingNav,
        onChanged: (v) =>
            ref.read(appThemeProvider.notifier).setFloatingNav(v),
      ),
    );
  }
}

/// 提醒诊断：把"通知没触发"的几种静默失败变成可见状态行，每行带修复入口。
/// 从系统设置授权页返回时自动刷新（监听 resumed）。——来自Trae
class _ReminderDiagnoseCard extends ConsumerStatefulWidget {
  const _ReminderDiagnoseCard();

  @override
  ConsumerState<_ReminderDiagnoseCard> createState() =>
      _ReminderDiagnoseCardState();
}

class _ReminderDiagnoseCardState extends ConsumerState<_ReminderDiagnoseCard>
    with WidgetsBindingObserver {
  ReminderDiagnosis? _diag;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 用户去系统设置页授权后返回，立刻重新读取状态
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final d = await NotificationService.instance.diagnose();
    if (!mounted) return;
    setState(() => _diag = d);
  }

  Future<void> _rescheduleNow() async {
    setState(() => _busy = true);
    await rescheduleTodayNotifications();
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  /// 当场发一条通知，验证链路通不通——不用等下一节课——2026-10-11
  Future<void> _sendTest() async {
    try {
      await NotificationService.instance.sendTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('测试通知已发出，看通知栏')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('测试通知失败：$e')),
      );
    }
  }

  Widget _row(String label, bool? ok, {String? hint, Widget? trailing}) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok == null
        ? scheme.onSurfaceVariant
        : ok
            ? const Color(0xFF2E7D32)
            : scheme.error;
    return ListTile(
      dense: true,
      leading: Icon(
        ok == false ? Icons.error_outline : Icons.check_circle_outline,
        color: color,
        size: 20,
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle:
          hint == null ? null : Text(hint, style: const TextStyle(fontSize: 12)),
      trailing: trailing ??
          Text(
            ok == null ? '未知' : (ok ? '正常' : '未开启'),
            style: TextStyle(color: color, fontSize: 13),
          ),
    );
  }

  Widget _fixButton(String label, Future<void> Function() onPressed) {
    return TextButton(
      onPressed: _busy ? null : onPressed,
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _diag;
    final error = d?.lastError ?? '';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('提醒诊断',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
          _row(
            '通知权限',
            d?.notificationsAllowed,
            hint: '关了的话提醒发了也看不见',
            trailing: d?.notificationsAllowed == false
                ? _fixButton('去开启', () async {
                    await NotificationService.instance
                        .requestNotificationsPermission();
                    _refresh();
                  })
                : null,
          ),
          // 低版本系统恒可用、查不到时整行不出现，免得"未知"看着像坏了
          if (d?.exactAlarmsAllowed != null)
            _row(
              '闹钟和提醒权限',
              d?.exactAlarmsAllowed,
              hint: '缺了到点会晚发或不发（Android 12+）',
              trailing: d?.exactAlarmsAllowed == false
                  ? _fixButton('去开启', () async {
                      await NotificationService.instance
                          .requestExactAlarmsPermission();
                    })
                  : null,
            ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.schedule_outlined, size: 20),
            title: Text('待触发提醒：${d?.pendingCount ?? 0} 条'),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _fixButton('立即重排', _rescheduleNow),
          ),
          // 排程链路通不通，当场试一条最直观——2026-10-11
          ListTile(
            dense: true,
            leading: const Icon(Icons.notifications_active_outlined, size: 20),
            title: const Text('发一条测试通知'),
            subtitle: const Text('能看到就说明权限和排程都正常',
                style: TextStyle(fontSize: 12)),
            trailing: _fixButton('发送', _sendTest),
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
