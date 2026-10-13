import 'package:flutter/material.dart';

/// 日期工具
/// 来自Trae
class DateUtilsTool {
  DateUtilsTool._();

  /// 取日期部分（时分秒清零），用于按天比较
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 解析 "HH:mm" 为今天的 DateTime（仅取时分用于计算分钟数）
  static int parseMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// 判断两个日期是否为同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 格式化日期为 yyyy-MM-dd
  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 中文星期
  static String chineseWeekday(int weekday) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${names[weekday - 1]}';
  }
}

/// Color 与 hex 字符串互转
extension ColorHex on Color {
  /// 转 #AARRGGBB 字符串
  String toHex() {
    return '#${toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// 从 #AARRGGBB 或 #RRGGBB 构造 Color
  static Color fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7 || hex.length == 6) {
      buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
    } else {
      buffer.write(hex.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
