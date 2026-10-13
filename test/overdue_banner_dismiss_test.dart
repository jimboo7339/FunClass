// 今日页「有 N 节课已结束还没记」提醒条回归测试：
// 记完「已上/未上」后 overduePendingProvider 必须自己重算并清空，
// 否则提醒条只能靠下拉刷新才消失——2026-10-10
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:funclass/core/utils/sample_data_seeder.dart';
import 'package:funclass/data/database/app_database.dart';
import 'package:funclass/data/models/enums.dart';
import 'package:funclass/data/providers/repository_providers.dart';
import 'package:funclass/features/shared/providers/lesson_providers.dart';

void main() {
  test('记完「已上」后过期未处理列表自动清空', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 昨天 10:00 的课：一定是已结束且没记的状态
    final yesterday = today.subtract(const Duration(days: 1));

    final courseId = await SampleDataSeeder(db).seed();
    final lessonId = await db.into(db.lessons).insert(LessonsCompanion.insert(
          courseId: courseId,
          date: yesterday,
          startTime: '10:00',
          endTime: '11:00',
          status: LessonStatus.pending,
        ));

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    // 保持监听，模拟提醒条一直挂在页面上
    final seen = <int>[];
    final sub = container.listen(
      overduePendingProvider,
      (_, next) => seen.add(next.valueOrNull?.length ?? -1),
      fireImmediately: true,
    );
    addTearDown(() async {
      sub.close();
      // 不调 container.dispose()：Riverpod 2.6 在 dispose 时对已完成的
      // FutureProvider 内部 completer 重复 complete，会抛
      // "Bad state: Future already completed"；测试进程结束自然会回收——2026-10-10
      await Future<void>.delayed(Duration.zero);
    });

    await container.read(overduePendingProvider.future);
    expect(seen.last, 1, reason: '过期未处理的课没有被算出来');

    await container
        .read(lessonActionsProvider)
        .updateStatus(lessonId, LessonStatus.attended);
    // 等 invalidate 触发的重算落定
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(seen.last, 0, reason: '记完「已上」后过期列表没自动清空');
  });
}