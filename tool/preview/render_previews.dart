// 页面预览渲染工具（不是断言测试，不参与 `flutter test` 默认运行）
//
// 用法：flutter test tool/preview/render_previews.dart --update-goldens
// 作用：把四个主页在真实中文字体下渲染成 PNG，落到 build/preview/，
// 方便改样式前后肉眼对比（本地没设备时最实在的"看效果"办法）。
//
// 字体：flutter_test 默认字体是方块字，这里把 Windows 微软雅黑装进
// family 'Roboto'（Material 默认字体族），保证预览里的中文能正常显示。
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:funclass/core/providers/theme_provider.dart';
import 'package:funclass/core/theme/app_theme.dart';
import 'package:funclass/data/database/app_database.dart';
import 'package:funclass/data/models/enums.dart';
import 'package:funclass/data/models/schedule_rule.dart';
import 'package:funclass/data/providers/repository_providers.dart';
import 'package:funclass/features/courses/presentation/course_list_page.dart';
import 'package:funclass/features/members/presentation/member_list_page.dart';
import 'package:funclass/features/statistics/presentation/statistics_page.dart';
import 'package:funclass/features/today/presentation/today_page.dart';

/// 输出目录（相对本文件：tool/preview/ → 仓库根 → build/preview）
const String _outDir = '../../build/preview';

void main() {
  setUpAll(_loadRealFont);

  for (final bright in [Brightness.light, Brightness.dark]) {
    final tag = bright == Brightness.light ? 'light' : 'dark';
    _render('today_$tag', (db) => const TodayPage(), bright);
    _render('courses_$tag', (db) => const CourseListPage(), bright);
    _render('stats_$tag', (db) => const StatisticsPage(), bright);
    _render('members_$tag', (db) => const MemberListPage(), bright);
  }
}

/// 装真实中文字体：把 msyh.ttc 注册成 Roboto，测试环境就能渲染汉字
Future<void> _loadRealFont() async {
  for (final path in [
    'C:/Windows/Fonts/msyh.ttc',
    'C:/Windows/Fonts/simsun.ttc',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
    return;
  }
}

void _render(String name, Widget Function(AppDatabase) page, Brightness bright) {
  testWidgets('预览 $name', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390×844 @3x
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedPreviewData(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(bright, ThemeState.defaultSeedColor),
          home: page(db),
        ),
      ),
    );
    // 等 provider 落定 + 动画结束
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }

    Directory(_outDir).createSync(recursive: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_outDir/$name.png'),
    );
  });
}

/// 造一份"像真人在用"的预览数据：2 个成员、3 门课、当天几节不同状态的课
Future<void> _seedPreviewData(AppDatabase db) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final kidId = await db.into(db.members).insert(MembersCompanion.insert(
        name: '小明',
        type: MemberType.child,
        colorTag: '#FFE57373',
      ));
  final parentId = await db.into(db.members).insert(MembersCompanion.insert(
        name: '妈妈',
        type: MemberType.parent,
        colorTag: '#FF81C784',
      ));

  Future<int> addCourse({
    required String name,
    required int memberId,
    required double amount,
    required int lessons,
    required List<ScheduleRule> rules,
    String? color,
    int? validDays,
  }) async {
    final validFrom = today;
    final validTo = validDays == null
        ? DateTime(9999, 12, 31) // 永久课程
        : today.add(Duration(days: validDays));
    return db.into(db.courses).insert(CoursesCompanion.insert(
          memberId: memberId,
          name: name,
          totalAmount: amount,
          totalLessons: lessons,
          validFrom: validFrom,
          validTo: validTo,
          schedules: rules,
          colorTag: Value(color),
        ));
  }

  final soccer = await addCourse(
    name: '足球课',
    memberId: kidId,
    amount: 2999,
    lessons: 45,
    color: '#FF4FC3F7',
    rules: const [
      ScheduleRule(weekday: 6, startTime: '09:30', endTime: '11:00'),
      ScheduleRule(weekday: 3, startTime: '17:30', endTime: '19:00'),
    ],
  );
  final piano = await addCourse(
    name: '钢琴课',
    memberId: kidId,
    amount: 4800,
    lessons: 60,
    color: '#FFBA68C8',
    validDays: 18, // 快到期 → 今日页会出现到期提醒
    rules: const [
      ScheduleRule(weekday: 4, startTime: '18:30', endTime: '19:30'),
    ],
  );
  final swim = await addCourse(
    name: '游泳课',
    memberId: kidId,
    amount: 2400,
    lessons: 30,
    color: '#FF4DD0E1',
    rules: const [
      ScheduleRule(weekday: 7, startTime: '10:00', endTime: '11:30'),
    ],
  );

  // 历史已上课次（喂统计页）
  for (var i = 1; i <= 12; i++) {
    final d = today.subtract(Duration(days: i * 3));
    await db.into(db.lessons).insert(LessonsCompanion.insert(
          courseId: i.isEven ? soccer : piano,
          date: d,
          startTime: '18:00',
          endTime: '19:00',
          status: i == 7 ? LessonStatus.skipped : LessonStatus.attended,
          attendedAt: Value(d.add(const Duration(hours: 19))),
        ));
  }

  // 今天：一节已上、一节待上（未来）、一节已过点没记（触发提醒条）
  await db.into(db.lessons).insert(LessonsCompanion.insert(
        courseId: soccer,
        date: today,
        startTime: '09:30',
        endTime: '11:00',
        status: LessonStatus.attended,
        attendedAt: Value(now),
      ));
  await db.into(db.lessons).insert(LessonsCompanion.insert(
        courseId: piano,
        date: today,
        startTime: '17:30',
        endTime: '18:30',
        status: LessonStatus.pending,
      ));
  await db.into(db.lessons).insert(LessonsCompanion.insert(
        courseId: swim,
        date: today,
        startTime: '07:00',
        endTime: '08:00',
        status: LessonStatus.pending,
      ));

  // 妈妈名下也有一门课，让成员分组/统计有多成员对比
  await addCourse(
    name: '瑜伽课',
    memberId: parentId,
    amount: 3600,
    lessons: 48,
    color: '#FFA1887F',
    rules: const [
      ScheduleRule(weekday: 2, startTime: '19:30', endTime: '20:30'),
    ],
  );
}