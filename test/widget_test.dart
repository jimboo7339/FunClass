// 趣课 App 基础烟雾测试
// 验证 App 能正常启动并显示底部导航
// 来自Trae
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:funclass/app.dart';

void main() {
  testWidgets('趣课 App 启动烟雾测试', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FunClassApp()));
    await tester.pump(const Duration(seconds: 1));
    // 验证底部导航出现（默认进入今日 Tab；四个 Tab：今日/课程/统计/成员）
    expect(find.text('今日'), findsWidgets);
    expect(find.text('成员'), findsWidgets);
    // 验证设置按钮存在
    expect(find.byIcon(Icons.settings_outlined), findsWidgets);
    // 路由推入会调度 400ms 的玻璃质量恢复定时器，跑完避免 pending timer 报错
    await tester.pump(const Duration(milliseconds: 500));
  });
}
