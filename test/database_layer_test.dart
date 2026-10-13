// 趣课 - 第一阶段数据层验证测试
// 使用内存数据库验证：成员/课程 CRUD、课次自动生成、状态更新
// 来自Trae
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:funclass/core/constants/app_constants.dart';
import 'package:funclass/core/utils/lesson_generator.dart';
import 'package:funclass/core/utils/sample_data_seeder.dart';
import 'package:funclass/data/database/app_database.dart';
import 'package:funclass/data/models/enums.dart';
import 'package:funclass/data/models/schedule_rule.dart';
import 'package:funclass/data/repositories/course_repository.dart';
import 'package:funclass/data/repositories/lesson_planner.dart';
import 'package:funclass/data/repositories/lesson_repository.dart';
import 'package:funclass/data/repositories/member_repository.dart';

void main() {
  late AppDatabase db;
  late MemberRepository memberRepo;
  late CourseRepository courseRepo;
  late LessonRepository lessonRepo;

  setUp(() {
    db = AppDatabase.memory();
    memberRepo = MemberRepository(db);
    courseRepo = CourseRepository(db);
    lessonRepo = LessonRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('示例数据：1成员+1课程，自动生成课次', () async {
    final courseId = await SampleDataSeeder(db).seed();

    final members = await memberRepo.getAll();
    expect(members.length, 1);
    expect(members.first.name, '小明');
    expect(members.first.type, MemberType.child);

    final courses = await courseRepo.getAll();
    expect(courses.length, 1);
    expect(courses.first.name, '足球课');
    expect(courses.first.totalLessons, 45);

    final lessons = await lessonRepo.getByCourseId(courseId);
    // 一年约52周，每周1节，应在 50~54 之间
    expect(lessons.length, greaterThanOrEqualTo(50));
    expect(lessons.length, lessThanOrEqualTo(54));
    // 所有课次状态默认为 pending
    expect(lessons.every((l) => l.status == LessonStatus.pending), isTrue);
    // 首节课在有效期内
    expect(lessons.first.date.isAfter(courses.first.validFrom) ||
        lessons.first.date == courses.first.validFrom, isTrue);
  });

  test('课次状态更新：已上课', () async {
    final courseId = await SampleDataSeeder(db).seed();
    final lessons = await lessonRepo.getByCourseId(courseId);

    final rows = await lessonRepo.updateStatus(lessons.first.id, LessonStatus.attended);
    expect(rows, 1);

    final updated = await lessonRepo.getById(lessons.first.id);
    expect(updated!.status, LessonStatus.attended);
    expect(updated.attendedAt, isA<DateTime>());

    // 已上课时统计
    final attendedCount = await lessonRepo.countAttended(courseId);
    expect(attendedCount, 1);
  });

  test('课程删除：级联删除课次', () async {
    final courseId = await SampleDataSeeder(db).seed();
    final lessonsBefore = await lessonRepo.getByCourseId(courseId);
    expect(lessonsBefore.length, greaterThan(0));

    await courseRepo.deleteWithLessons(courseId);

    final coursesAfter = await courseRepo.getAll();
    expect(coursesAfter.length, 0);

    final lessonsAfter = await lessonRepo.getByCourseId(courseId);
    expect(lessonsAfter.length, 0);
  });

  test('多频率规则：每周六日各一节', () async {
    // 创建一个有效期为 14 天的课程，规则为周六+周日
    final memberId = await memberRepo.insert(
      MembersCompanion.insert(
        name: '小红',
        type: MemberType.child,
        colorTag: '#FF4FC3F7',
      ),
    );

    final now = DateTime.now();
    final validFrom = DateTime(now.year, now.month, now.day);
    final validTo = validFrom.add(const Duration(days: 13)); // 14天

    final courseId = await courseRepo.insertWithLessons(
      CoursesCompanion.insert(
        memberId: memberId,
        name: '舞蹈课',
        totalAmount: 1500,
        totalLessons: 20,
        validFrom: validFrom,
        validTo: validTo,
        schedules: const [
          ScheduleRule(weekday: 6, startTime: '09:00', endTime: '10:30'),
          ScheduleRule(weekday: 7, startTime: '09:00', endTime: '10:30'),
        ],
      ),
    );

    final lessons = await lessonRepo.getByCourseId(courseId);
    // 14天内周六周日各出现约2次 = 4节左右
    expect(lessons.length, inInclusiveRange(2, 6));
  });

  test('LessonGenerator 闭区间：validTo 当天命中规则仍生成', () {
    // 构造一个从周五到下周五的课程（共8天，含首尾两个周五）
    final validFrom = DateTime(2026, 1, 2); // 周五
    final validTo = DateTime(2026, 1, 9); // 下周五

    final course = Course(
      id: 1,
      memberId: 1,
      name: 'test',
      colorTag: null,
      totalAmount: 100,
      totalLessons: 10,
      validFrom: validFrom,
      validTo: validTo,
      schedules: const [
        ScheduleRule(weekday: 5, startTime: '17:30', endTime: '19:00'),
      ],
      note: null,
      createdAt: DateTime.now(),
    );

    final lessons = LessonGenerator.generate(course);
    // 首尾两个周五都应生成，共2节
    expect(lessons.length, 2);
  });

  test('永久课程：课次生成受 maxLessonGenerationDays 上限保护', () {
    final validFrom = DateTime(2026, 1, 1);
    final course = Course(
      id: 1,
      memberId: 1,
      name: '永久课',
      colorTag: null,
      totalAmount: 100,
      totalLessons: 1000,
      validFrom: validFrom,
      validTo: AppConstants.permanentDate, // 永久
      schedules: const [
        ScheduleRule(weekday: 1, startTime: '09:00', endTime: '10:00'),
      ],
      note: null,
      createdAt: DateTime.now(),
    );

    final lessons = LessonGenerator.generate(course);
    // 每周一节，maxLessonGenerationDays=730 天 ≈ 104 周
    expect(lessons.length, lessThanOrEqualTo(105));
    expect(lessons.length, greaterThan(100));
    // 末节课不超过 validFrom + 730 天
    final maxAllowed = validFrom
        .add(const Duration(days: AppConstants.maxLessonGenerationDays));
    expect(lessons.last.date.value.isAfter(maxAllowed), isFalse);
  });

  test('LessonGenerator maxCount：排满总课时就停', () {
    final course = Course(
      id: 1,
      memberId: 1,
      name: 'test',
      colorTag: null,
      totalAmount: 100,
      totalLessons: 2,
      validFrom: DateTime(2026, 1, 2), // 周五
      validTo: DateTime(2026, 3, 6), // 九个周五
      schedules: const [
        ScheduleRule(weekday: 5, startTime: '17:30', endTime: '19:00'),
      ],
      note: null,
      createdAt: DateTime.now(),
    );

    final lessons = LessonGenerator.generate(course, maxCount: 2);
    expect(lessons.length, 2);
    // 排到哪算哪：只取前两个周五
    expect(lessons.first.date.value, DateTime(2026, 1, 2));
    expect(lessons.last.date.value, DateTime(2026, 1, 9));
  });

  group('LessonPlanner 新排课模型', () {
    late LessonPlanner planner;
    // 固定"现在"=2026-10-10(周六) 12:00，避开真实时钟让断言稳定
    final fakeNow = DateTime(2026, 10, 10, 12);
    final wedFutures = [
      DateTime(2026, 10, 14),
      DateTime(2026, 10, 21),
      DateTime(2026, 10, 28),
      DateTime(2026, 11, 4),
      DateTime(2026, 11, 11),
      DateTime(2026, 11, 18),
    ];
    final wedPasts = [
      DateTime(2026, 9, 30),
      DateTime(2026, 10, 7),
    ];

    setUp(() {
      planner = LessonPlanner(db);
    });

    Future<int> createWeeklyCourse(int totalLessons) async {
      final memberId = await memberRepo.insert(
        MembersCompanion.insert(
          name: '测试员',
          type: MemberType.child,
          colorTag: '#FF90A4AE',
        ),
      );
      return db.into(db.courses).insert(
            CoursesCompanion.insert(
              memberId: memberId,
              name: '钢琴课',
              colorTag: const Value(null),
              totalAmount: 0,
              totalLessons: totalLessons,
              validFrom: fakeNow,
              validTo: fakeNow.add(const Duration(days: 365)),
              schedules: const [
                ScheduleRule(
                    weekday: 3, startTime: '18:00', endTime: '19:00'),
              ],
            ),
          );
    }

    Future<void> insertPendingLessons(
        int courseId, List<DateTime> dates) async {
      for (final d in dates) {
        await db.into(db.lessons).insert(
              LessonsCompanion.insert(
                courseId: courseId,
                date: d,
                startTime: '18:00',
                endTime: '19:00',
                status: LessonStatus.pending,
              ),
            );
      }
    }

    test('过期 pending 保留待处理：不删不改，future = 剩余 − 未处理', () async {
      final cid = await createWeeklyCourse(6);
      // 4 节未来 + 2 节已过期未处理
      await insertPendingLessons(cid, wedFutures.take(4).toList());
      await insertPendingLessons(cid, wedPasts);

      await planner.syncCourse(cid, now: fakeNow);

      final lessons = await lessonRepo.getByCourseId(cid);
      // target 6、已上 0、未处理 2 → 未来只需 4 节，原样保留
      expect(lessons.length, 6);
      expect(lessons.every((l) => l.status == LessonStatus.pending), isTrue);
      final dates = lessons.map((l) => l.date).toList()..sort();
      expect(dates.first, wedPasts[0]); // 过期那两节还在，等用户点
      expect(dates[2], wedFutures[0]);
      expect(dates.last, wedFutures[3]);
    });

    test('过期课点「未上课」→ 不占课时，计划末尾自动补一节（顺延）', () async {
      final cid = await createWeeklyCourse(6);
      await insertPendingLessons(cid, wedFutures.take(4).toList());
      await insertPendingLessons(cid, wedPasts);

      // 把 10-07 那节标成未上课（skipped）
      final all = await lessonRepo.getByCourseId(cid);
      final missed = all.firstWhere((l) => l.date == DateTime(2026, 10, 7));
      await lessonRepo.updateStatus(missed.id, LessonStatus.skipped);

      await planner.syncCourse(cid, now: fakeNow);

      final future = (await lessonRepo.getByCourseId(cid))
          .where((l) =>
              l.status == LessonStatus.pending && l.date.isAfter(fakeNow))
          .toList();
      // target 6、未处理剩 1（9-30 还挂着）→ 未来排程应有 5 节：尾部补出 11-11
      expect(future.length, 5);
      expect(
        future.any((l) => l.date == DateTime(2026, 11, 11)),
        isTrue,
      );
    });

    test('加课已上一节 → 尾部计划裁掉一节', () async {
      final cid = await createWeeklyCourse(6);
      await insertPendingLessons(cid, wedFutures); // 未来 6 = 目标 6

      // 今天手动加课并已上
      await db.into(db.lessons).insert(
            LessonsCompanion.insert(
              courseId: cid,
              date: fakeNow,
              startTime: '18:00',
              endTime: '19:00',
              status: LessonStatus.attended,
              isExtra: const Value(true),
              attendedAt: Value(fakeNow),
            ),
          );

      await planner.syncCourse(cid, now: fakeNow);

      final pending = (await lessonRepo.getByCourseId(cid))
          .where((l) => l.status == LessonStatus.pending)
          .toList();
      expect(pending.length, 5);
      // 裁的是最尾部那节
      expect(pending.every((l) => !l.date.isAtSameMomentAs(DateTime(2026, 11, 18))), isTrue);
    });

    test('计划正确时幂等：不删不增不改 id', () async {
      final cid = await createWeeklyCourse(6);
      await insertPendingLessons(cid, wedFutures);

      final before = await lessonRepo.getByCourseId(cid);
      await planner.syncCourse(cid, now: fakeNow);
      final after = await lessonRepo.getByCourseId(cid);

      expect(after.length, before.length);
      expect(
        after.map((l) => l.id).toList()..sort(),
        before.map((l) => l.id).toList()..sort(),
      );
    });
  });

  test('按日期范围查询有课日期', () async {
    await SampleDataSeeder(db).seed();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final dates = await lessonRepo.getDatesWithLessons(monthStart, monthEnd);
    // 足球课每周五，本月应至少有 1 个周五有课
    expect(dates.length, greaterThanOrEqualTo(1));
  });

  test('按月统计每日课次数：同日多节合并计数', () async {
    final courseId = await SampleDataSeeder(db).seed();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    // 同一天插两节（不同时间），日历标记应显示 2
    final day = DateTime(now.year, now.month, 15);
    await db.into(db.lessons).insert(LessonsCompanion.insert(
          courseId: courseId,
          date: day,
          startTime: '09:00',
          endTime: '10:00',
          status: LessonStatus.attended,
        ));
    await db.into(db.lessons).insert(LessonsCompanion.insert(
          courseId: courseId,
          date: day,
          startTime: '14:00',
          endTime: '15:00',
          status: LessonStatus.skipped,
        ));

    final counts =
        await lessonRepo.getLessonCountByDate(monthStart, monthEnd);
    final key = DateTime(day.year, day.month, day.day);
    expect(counts[key], 2);
    // 状态集合与课次数的日期口径一致（同一天混合状态也算一天有课）
    final statuses = await lessonRepo.getStatusesByDate(monthStart, monthEnd);
    expect(statuses[key], {LessonStatus.attended, LessonStatus.skipped});
    expect(counts.keys.toSet(), containsAll(statuses.keys.toSet()));
  });

  test('按日期查询课次（连表课程信息）', () async {
    final courseId = await SampleDataSeeder(db).seed();
    final lessons = await lessonRepo.getByCourseId(courseId);
    final firstDate = lessons.first.date;
    final withCourse = await lessonRepo.getLessonsWithCourseByDate(firstDate);
    expect(withCourse.length, greaterThanOrEqualTo(1));
    expect(withCourse.first.course.id, courseId);
    expect(withCourse.first.lesson.date, firstDate);
  });
}
