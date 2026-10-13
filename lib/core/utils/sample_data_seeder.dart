import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/schedule_rule.dart';
import 'lesson_generator.dart';

/// 示例数据生成器
/// 创建 1 个成员 + 1 个课程（自动铺满课次），用于第一阶段验证
/// 来自Trae
class SampleDataSeeder {
  SampleDataSeeder(this._db);

  final AppDatabase _db;

  /// 生成示例数据，返回写入的课程 id
  Future<int> seed() async {
    // 1. 创建成员：小明（孩子）
    final memberId = await _db.into(_db.members).insert(
          MembersCompanion.insert(
            name: '小明',
            type: MemberType.child,
            colorTag: '#FFE57373',
          ),
        );

    // 2. 创建课程：足球课
    // 有效期：今天起一年
    // 总金额 2999，总课时 45
    // 频率：每周五 17:30-19:00
    final now = DateTime.now();
    final validFrom = DateTime(now.year, now.month, now.day);
    final validTo = validFrom.add(const Duration(days: 365));

    final courseId = await _db.into(_db.courses).insert(
          CoursesCompanion.insert(
            memberId: memberId,
            name: '足球课',
            totalAmount: 2999,
            totalLessons: 45,
            validFrom: validFrom,
            validTo: validTo,
            schedules: const [
              ScheduleRule(weekday: 5, startTime: '17:30', endTime: '19:00'),
            ],
          ),
        );

    // 3. 按频率规则自动生成课次
    final course = await (_db.select(_db.courses)
          ..where((c) => c.id.equals(courseId)))
        .getSingle();
    final lessons = LessonGenerator.generate(course);
    if (lessons.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAll(_db.lessons, lessons);
      });
    }

    return courseId;
  }
}
