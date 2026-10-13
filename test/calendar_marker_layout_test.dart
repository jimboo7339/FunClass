// 日历布局回归测试：选中有课日期时，底部课次数字标记不得压到日期圆。
// 2026-10-10 修复「下标 1 与选中圆重叠看不清」后加的几何断言。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:funclass/core/utils/sample_data_seeder.dart';
import 'package:funclass/data/database/app_database.dart';
import 'package:funclass/data/models/enums.dart';
import 'package:funclass/data/providers/repository_providers.dart';
import 'package:funclass/features/today/presentation/today_page.dart';
import 'package:funclass/shared/widgets/calendar_lesson_marker.dart';

void main() {
  // 日历用 zh_CN locale，测试环境要手动初始化日期符号数据——2026-10-10
  setUpAll(() => initializeDateFormatting('zh_CN'));

  // table_calendar 传进来的格子日期是 UTC，比较只看到年月日
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  testWidgets('选中有课日期时，数字标记与日期圆不重叠', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final courseId = await SampleDataSeeder(db).seed();
    // 示例数据只排周五，今天补一节已上课，保证选中日既有圆又有数字标记
    await db.into(db.lessons).insert(LessonsCompanion.insert(
          courseId: courseId,
          date: today,
          startTime: '18:00',
          endTime: '19:00',
          status: LessonStatus.attended,
        ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: DatePickerSheet(initialDate: today),
          ),
        ),
      ),
    );
    // 等两个 FutureProvider（状态 + 课次数）落定
    await tester.pumpAndSettle();

    // 选中日（今天）的日期圆：只有今天/选中会画圆底
    final cellFinder = find.byWidgetPredicate(
      (w) =>
          w is CalendarDayCell &&
          sameDay(w.date, today) &&
          w.circleColor != null,
    );
    expect(cellFinder, findsOneWidget, reason: '未找到选中日的日期圆');
    // 量真正的圆容器（32×32 圆形装饰），不是外层格子区域
    final circleFinder = find
        .descendant(
          of: cellFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        )
        .first;

    // 今天的课次数字标记
    final markerFinder = find.byWidgetPredicate(
      (w) =>
          w is CalendarLessonMarker &&
          w.date != null &&
          sameDay(w.date!, today),
    );
    expect(markerFinder, findsOneWidget, reason: '未找到今天的课次数字标记');

    final circleRect = tester.getRect(circleFinder);
    final markerRect = tester.getRect(markerFinder);
    // 外层格子(含 cellMargin 后)的底 = 标记所在行的下边界
    final cellRect = tester.getRect(cellFinder);

    // 关键断言：数字标记整体在圆的下沿之下，且两者之间留出空隙
    expect(
      markerRect.top,
      greaterThanOrEqualTo(circleRect.bottom + 2),
      reason: '数字标记(${markerRect.top}) 压到了日期圆(底 ${circleRect.bottom})，重叠',
    );
    // 标记完整落在格子内（留 1px 容差）
    expect(
      markerRect.bottom,
      lessThanOrEqualTo(cellRect.bottom + 1),
      reason: '数字标记(${markerRect.bottom}) 超出格子底(${cellRect.bottom})',
    );
  });
}
