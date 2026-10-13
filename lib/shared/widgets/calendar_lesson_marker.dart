import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/enums.dart';

/// 日历格子下方的课次数字标记：当天有课就把课次数显示在日期下面。
/// 原来是一个 5px 的小圆点，扫一眼看不出哪天有几节课，所以换成数字。
/// 颜色沿用原来的状态优先级：待上(蓝) > 未上(橘) > 已上(绿)——2026-10-10
class CalendarLessonMarker extends StatelessWidget {
  const CalendarLessonMarker({
    required this.count,
    required this.statuses,
    this.date,
    super.key,
  });

  /// 当天课次数，1~9 直接显示，更多显示 9+
  final int count;

  /// 当天课次出现过的状态集合，决定数字颜色
  final Set<LessonStatus> statuses;

  /// 标记所属日期（可选，供测试/调试定位）——2026-10-10
  final DateTime? date;

  /// 当天还有没上完的先标蓝提醒，全上完绿、有没去的橘——来自Trae
  static Color colorFor(Set<LessonStatus> statuses) =>
      statuses.contains(LessonStatus.pending)
          ? AppColors.primary
          : statuses.contains(LessonStatus.skipped)
              ? AppColors.skipped
              : AppColors.attended;

  @override
  Widget build(BuildContext context) {
    // 贴圆下沿排，而不是贴格子底：行高 56 时圆占 y=0~32，
    // bottom:2 会让数字离自己的日期 12px、离下一行圆只有 2px，
    // 看着像挂在下边日期上——2026-10-10 实测后改为 top:36
    return Positioned(
      top: 36,
      child: Text(
        count > 9 ? '9+' : '$count',
        style: TextStyle(
          fontSize: 10,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: colorFor(statuses),
        ),
      ),
    );
  }
}

/// 日历日期格子：今天/选中的圆固定 32×32 并靠上排，
/// 行高 56 时圆占 y=0~32，底部 y=36~46 留给数字标记——2026-10-10
/// （注意：table_calendar 对自定义 builder 不套 cellMargin，格子就是从行顶排起）
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    required this.date,
    required this.textColor,
    this.circleColor,
    super.key,
  });

  final DateTime date;

  /// 日期数字颜色（周末红、选中白等由调用方决定）
  final Color textColor;

  /// 有值才画圆底（今天淡蓝、选中实心蓝）
  final Color? circleColor;

  /// 周末日期数字标红，两个日历共用
  static bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  @override
  Widget build(BuildContext context) {
    // 自定义 builder 不会被套 cellMargin，圆直接顶到行顶；
    // 行高 56 时圆占 y=0~32，标记（top:36）占 y=36~46，与下一行圆留 10px
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: 32,
        height: 32,
        decoration: circleColor == null
            ? null
            : BoxDecoration(color: circleColor, shape: BoxShape.circle),
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
