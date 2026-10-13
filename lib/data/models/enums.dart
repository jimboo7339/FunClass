/// 课次状态枚举
/// pending：待上课（默认）
/// attended：已上课（消耗课时）
/// skipped：未上课（跳过，不消耗课时）
/// 来自Trae
enum LessonStatus {
  pending,
  attended,
  skipped,
}

/// 成员类型枚举
/// child：孩子
/// parent：家长
/// other：其他
/// 来自Trae
enum MemberType {
  child,
  parent,
  other,
}

/// 成员类型中文展示
extension MemberTypeLabel on MemberType {
  String get label {
    switch (this) {
      case MemberType.child:
        return '孩子';
      case MemberType.parent:
        return '家长';
      case MemberType.other:
        return '其他';
    }
  }
}

/// 课次状态中文展示
extension LessonStatusLabel on LessonStatus {
  String get label {
    switch (this) {
      case LessonStatus.pending:
        return '待上课';
      case LessonStatus.attended:
        return '已上课';
      case LessonStatus.skipped:
        return '未上课';
    }
  }
}
