import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/backup_repository.dart';
import '../repositories/course_repository.dart';
import '../repositories/lesson_planner.dart';
import '../repositories/lesson_repository.dart';
import '../repositories/member_repository.dart';
import '../../core/services/backup_service.dart';

/// 数据库单例 Provider
/// 来自Trae
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// 成员仓库
final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(databaseProvider));
});

/// 课程仓库
final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository(ref.watch(databaseProvider));
});

/// 课次仓库
final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository(ref.watch(databaseProvider));
});

/// 排程计划器（未来 pending 恒等于剩余课时；漏上自动后延）——来自Trae
final lessonPlannerProvider = Provider<LessonPlanner>((ref) {
  return LessonPlanner(ref.watch(databaseProvider));
});

/// 备份仓库
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(ref.watch(databaseProvider));
});

/// 备份/恢复服务
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});
