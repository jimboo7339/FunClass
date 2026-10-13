import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';

/// 全局共享状态（Tab 导航、日历聚焦等）
/// 来自Trae

/// 当前底部 Tab 索引（0=今日 1=课程 2=统计 3=成员 4=设置）
final currentTabProvider = StateProvider<int>((ref) => 0);

/// 日历页聚焦日期（从今日页过期提醒跳转时设置）
/// 注：日历页已从底部导航收敛为今日页顶部的日期弹出选择器，
///     该 provider 仍被保留，用于今日页定位过期课次日期——来自Trae
final calendarFocusDateProvider = StateProvider<DateTime>(
    (ref) => DateUtilsTool.dateOnly(DateTime.now()));

/// 今日页当前展示的日期（默认今天）
/// 通过该 provider，可在任意位置（如过期提醒跳转）切换今日页展示的日期——来自Trae
final todaySelectedDateProvider = StateProvider<DateTime>(
    (ref) => DateUtilsTool.dateOnly(DateTime.now()));

/// 日历页选中的成员筛选 id（null=全部）
final calendarMemberFilterProvider = StateProvider<int?>((ref) => null);
