import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/page_shell.dart';
import 'data/models/enums.dart';
import 'features/courses/presentation/course_list_page.dart';
import 'features/members/presentation/member_list_page.dart';
import 'features/settings/presentation/backup_page.dart';
import 'features/statistics/presentation/statistics_page.dart';
import 'features/shared/providers/lesson_providers.dart';
import 'features/today/presentation/today_page.dart';
import 'shared/providers/app_state_providers.dart';
import 'shared/providers/notification_providers.dart';

/// 趣课 App 根组件
class FunClassApp extends ConsumerWidget {
  const FunClassApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final brightness = switch (theme.mode) {
      ThemeModeType.light => Brightness.light,
      ThemeModeType.dark => Brightness.dark,
      ThemeModeType.system => platformBrightness,
    };

    final themeData = AppTheme.build(brightness, theme.seedColor);

    return MaterialApp(
      title: '趣课',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}

/// 底部导航主框架（4 Tab：今日 / 课程 / 统计 / 成员；设置走各页 AppBar 齿轮）
/// 来自Trae
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const List<Widget> _pages = [
    TodayPage(),
    CourseListPage(),
    StatisticsPage(),
    MemberListPage(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today),
      label: '今日',
    ),
    NavigationDestination(
      icon: Icon(Icons.list_alt_outlined),
      selectedIcon: Icon(Icons.list_alt),
      label: '课程',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: '统计',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: '成员',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabProvider);
    final isFloatingNav = ref.watch(isFloatingNavProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 点通知/快捷按钮 → 切 Tab、定位日期、改课次状态——2026-10-10
    ref.listen(notificationEventProvider, (prev, next) {
      next.whenData((event) => _onNotificationEvent(context, ref, event));
    });

    final child = IndexedStack(index: currentIndex, children: _pages);

    // 普通导航：贴底标准 Material 导航栏——来自Trae
    if (!isFloatingNav) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (i) => _onTabSelected(ref, i),
          destinations: _destinations,
        ),
      );
    }

    // 悬浮导航：圆角悬浮条浮在内容上方（纯 Material，无玻璃效果）——来自Trae
    // 底部留白：有 Home 指示条/安全区时按实际 inset 适配，避免贴边或遮挡
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = bottomInset > 0 ? bottomInset + 12.0 : 24.0;

    // 导航栏整体占用的高度（含安全区留白），页面 FAB 要据此上抬
    final navBarHeight = 58.0 + bottomPadding;

    return Scaffold(
      // 让 body 铺满到屏幕底部、从悬浮导航条下方穿过：
      // 不开 extendBody 的话 body 会在导航条顶边被切断，内容列表在那条线处被切一刀，
      // 看着就像有东西卡在导航栏下面；列表底部已预留留白，内容仍能完整滚到可见区
      extendBody: true,
      body: BottomNavInset(
        height: navBarHeight,
        child: child,
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: scheme.surfaceContainerHigh,
            // 深色下阴影加重，给悬浮条增加浮起感
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: NavigationBar(
            height: 58,
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: scheme.primaryContainer,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: currentIndex,
            onDestinationSelected: (i) => _onTabSelected(ref, i),
            destinations: _destinations,
          ),
        ),
      ),
    );
  }

  void _onTabSelected(WidgetRef ref, int index) {
    HapticFeedback.selectionClick();
    ref.read(currentTabProvider.notifier).state = index;
  }

  /// 通知交互处理：
  ///  - 备份失败通知 → 直接打开备份设置页
  ///  - 到期预警通知 → 切到课程 Tab
  ///  - 上课提醒（点本体或快捷按钮）→ 切到今日页并定位到那节课的日期；
  ///    带 actionId 时顺手把课次标成已上/未上（复用 LessonActions，含顺延与备份联动）
  void _onNotificationEvent(
      BuildContext context, WidgetRef ref, NotificationEvent event) {
    final tab = ref.read(currentTabProvider.notifier);

    if (event.payload == NotificationService.payloadSyncFailed) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BackupSettingsPage()),
      );
      return;
    }
    if (event.payload == NotificationService.payloadExpiry) {
      tab.state = 1; // 课程 Tab
      return;
    }

    final lesson = NotificationService.parseLessonPayload(event.payload);
    if (lesson == null) return;
    ref.read(todaySelectedDateProvider.notifier).state = lesson.date;
    tab.state = 0; // 今日 Tab

    final actions = ref.read(lessonActionsProvider);
    if (event.actionId == NotificationService.actionAttended) {
      unawaited(actions.updateStatus(lesson.lessonId, LessonStatus.attended));
    } else if (event.actionId == NotificationService.actionSkipped) {
      unawaited(actions.updateStatus(lesson.lessonId, LessonStatus.skipped));
    }
  }
}
