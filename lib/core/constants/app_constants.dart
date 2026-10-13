import '../../data/models/enums.dart';

/// 通用常量
/// 来自Trae
class AppConstants {
  AppConstants._();

  /// "永久" 有效期的占位日期（DB 中非空，用作哨兵值）
  static final DateTime permanentDate = DateTime(9999, 12, 31);

  /// 课次自动生成的最大天数（防止"永久"课程无限生成）
  static const int maxLessonGenerationDays = 730; // 2 年

  /// 成员类型列表（用于下拉选择）
  static const List<MemberType> memberTypes = [
    MemberType.child,
    MemberType.parent,
    MemberType.other,
  ];
}

/// 判断课程有效期是否为"永久"
/// 来自Trae
bool isPermanentValidTo(DateTime validTo) {
  return validTo.year >= AppConstants.permanentDate.year;
}
