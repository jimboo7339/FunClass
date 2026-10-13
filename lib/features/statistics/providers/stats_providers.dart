import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers/repository_providers.dart';
import '../../members/providers/member_providers.dart';

/// 单课程详细统计
/// 来自Trae
class CourseStatDetail {
  final int courseId;
  final String courseName;
  final String memberName;
  final int attendedCount;
  final int totalLessons;
  final double totalAmount;
  final double consumedAmount;
  final int remainingLessons;
  final double unitPrice;
  final double attendanceRate;
  final int validDaysRemaining;

  const CourseStatDetail({
    required this.courseId,
    required this.courseName,
    required this.memberName,
    required this.attendedCount,
    required this.totalLessons,
    required this.totalAmount,
    required this.consumedAmount,
    required this.remainingLessons,
    required this.unitPrice,
    required this.attendanceRate,
    required this.validDaysRemaining,
  });
}

/// 按成员统计
class MemberStat {
  final int memberId;
  final String memberName;
  final String colorTag;
  final double totalSpent;
  final int totalAttended;
  const MemberStat({
    required this.memberId,
    required this.memberName,
    required this.colorTag,
    required this.totalSpent,
    required this.totalAttended,
  });
}

/// 按家庭（自然年）统计
class FamilyAnnualStat {
  final int year;
  final double totalSpent;
  final int totalAttended;
  final List<MemberStat> memberBreakdown;
  const FamilyAnnualStat({
    required this.year,
    required this.totalSpent,
    required this.totalAttended,
    required this.memberBreakdown,
  });
}

/// 全量统计数据
class StatsData {
  final List<CourseStatDetail> courseStats;
  final List<MemberStat> memberStats;
  final FamilyAnnualStat familyAnnual;
  const StatsData({
    required this.courseStats,
    required this.memberStats,
    required this.familyAnnual,
  });
}

/// 统计数据 Provider（单课程 + 按成员 + 按家庭）
/// 来自Trae
final statsProvider = FutureProvider.autoDispose<StatsData>((ref) async {
  final lessonRepo = ref.watch(lessonRepositoryProvider);
  final courses = await ref.watch(courseRepositoryProvider).getAll();
  final members = await ref.watch(membersProvider.future);
  final memberMap = {for (final m in members) m.id: m};

  final courseStats = <CourseStatDetail>[];
  final memberMapStats = <int, MemberStat>{};

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yearStart = DateTime(now.year, 1, 1);
  final yearEnd = DateTime(now.year + 1, 1, 1);

  double familyAnnualSpent = 0;
  int familyAnnualAttended = 0;
  final familyMemberSpent = <int, double>{};
  final familyMemberAttended = <int, int>{};

  for (final c in courses) {
    final attended = await lessonRepo.countAttended(c.id);
    final unitPrice = c.totalLessons == 0 ? 0.0 : c.totalAmount / c.totalLessons;
    final consumed = unitPrice * attended;
    final remaining = c.totalLessons - attended;
    // 出勤率 = 已上 / 购课总数（不是已生成 schedule 数，那会不准）——来自Trae
    final rate = c.totalLessons == 0 ? 0.0 : attended / c.totalLessons;
    // 永久课程用 -1 表示「长期有效」，否则统计页会显示 2912159 天这种鬼数字——2026-10-11
    final validDays = isPermanentValidTo(c.validTo)
        ? -1
        : c.validTo.difference(today).inDays;

    final member = memberMap[c.memberId];
    courseStats.add(CourseStatDetail(
      courseId: c.id,
      courseName: c.name,
      memberName: member?.name ?? '未知成员',
      attendedCount: attended,
      totalLessons: c.totalLessons,
      totalAmount: c.totalAmount,
      consumedAmount: consumed,
      remainingLessons: remaining,
      unitPrice: unitPrice,
      attendanceRate: rate,
      validDaysRemaining: validDays,
    ));

    final ms = memberMapStats[c.memberId];
    memberMapStats[c.memberId] = MemberStat(
      memberId: c.memberId,
      memberName: member?.name ?? '未知成员',
      colorTag: member?.colorTag ?? '#FF9E9E9E',
      totalSpent: (ms?.totalSpent ?? 0.0) + c.totalAmount,
      totalAttended: (ms?.totalAttended ?? 0) + attended,
    );

    final validFrom = c.validFrom;
    if (!validFrom.isBefore(yearStart) && validFrom.isBefore(yearEnd)) {
      familyAnnualSpent += c.totalAmount;
      familyAnnualAttended += attended;
      familyMemberSpent[c.memberId] =
          (familyMemberSpent[c.memberId] ?? 0.0) + c.totalAmount;
      familyMemberAttended[c.memberId] =
          (familyMemberAttended[c.memberId] ?? 0) + attended;
    }
  }

  final memberStats = memberMapStats.values.toList()
    ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

  final familyMemberBreakdown = members
      .map((m) => MemberStat(
            memberId: m.id,
            memberName: m.name,
            colorTag: m.colorTag,
            totalSpent: familyMemberSpent[m.id] ?? 0,
            totalAttended: familyMemberAttended[m.id] ?? 0,
          ))
      .where((m) => m.totalSpent > 0 || m.totalAttended > 0)
      .toList()
    ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

  return StatsData(
    courseStats: courseStats,
    memberStats: memberStats,
    familyAnnual: FamilyAnnualStat(
      year: now.year,
      totalSpent: familyAnnualSpent,
      totalAttended: familyAnnualAttended,
      memberBreakdown: familyMemberBreakdown,
    ),
  );
});
