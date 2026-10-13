// 备份导出/导入往返测试——来自Trae
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';

import 'package:funclass/core/services/backup_service.dart';
import 'package:funclass/data/database/app_database.dart';
import 'package:funclass/data/models/enums.dart';
import 'package:funclass/data/models/schedule_rule.dart';

void main() {
  test('备份导出->清空->导入，数据与 schedule 规则完整还原', () async {
    final db = AppDatabase.memory();
    final service = BackupService(db);

    // 写入一条成员、一门课程（含频率规则）、一条课次
    final memberId = await db.into(db.members).insert(MembersCompanion.insert(
          name: '小明',
          type: MemberType.child,
          colorTag: '#FF2196F3',
          note: const Value('三年级'),
        ));

    final courseId =
        await db.into(db.courses).insert(CoursesCompanion.insert(
              memberId: memberId,
              name: '钢琴',
              colorTag: const Value('#FF4CAF50'),
              totalAmount: 3000.0,
              totalLessons: 30,
              validFrom: DateTime(2026, 9, 1),
              validTo: DateTime(2026, 12, 31),
              schedules: const [ScheduleRule(weekday: 5, startTime: '17:30', endTime: '19:00')],
            ));

    await db.into(db.lessons).insert(LessonsCompanion.insert(
          courseId: courseId,
          date: DateTime(2026, 9, 4),
          startTime: '17:30',
          endTime: '19:00',
          status: LessonStatus.attended,
        ));

    final json = await service.exportJson();

    // 模拟全新设备：清空后从备份导入
    await db.delete(db.members).go();
    await db.delete(db.courses).go();
    await db.delete(db.lessons).go();

    final summary = await service.restoreJson(json);
    expect(summary.members, 1);
    expect(summary.courses, 1);
    expect(summary.lessons, 1);

    final courses = await db.select(db.courses).get();
    expect(courses, hasLength(1));
    expect(courses.first.schedules, hasLength(1));
    expect(courses.first.schedules.first.weekday, 5);
    expect(courses.first.schedules.first.startTime, '17:30');
    expect(courses.first.colorTag, '#FF4CAF50');
    expect(courses.first.validFrom.year, 2026);

    final members = await db.select(db.members).get();
    expect(members.first.name, '小明');
    expect(members.first.type, MemberType.child);

    final lessons = await db.select(db.lessons).get();
    expect(lessons.first.courseId, courseId);
    expect(lessons.first.status, LessonStatus.attended);

    await db.close();
  });
}