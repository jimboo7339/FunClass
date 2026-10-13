// 转场中间帧预览（不是断言测试）
//
// 用法：flutter test tool/preview/render_transition.dart --update-goldens
// 目的：捕捉 push 二级页后第 N 毫秒那一帧，肉眼确认不会"闪一下黑"。
// opaque 路由淡入期间下面那条路由不绘制，底下没东西就是窗口黑底——
// 这里渲成 PNG，透明处会显示成黑色。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:funclass/core/theme/app_theme.dart';
import 'package:funclass/core/providers/theme_provider.dart';
import 'package:funclass/core/widgets/page_shell.dart';

const String _outDir = '../../build/preview_transition';

void main() {
  for (final ms in [60, 120, 200]) {
    testWidgets('转场第 $ms 毫秒', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(Brightness.light, ThemeState.defaultSeedColor),
          home: const Scaffold(body: Center(child: Text('首页'))),
        ),
      );
      await tester.pump();

      // push 一个走 PageShell 的二级页
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PageShell(
            title: '上课记录',
            body: const Center(child: Text('课次列表')),
          ),
        ),
      );
      await tester.pump(); // 启动转场
      await tester.pump(Duration(milliseconds: ms)); // 停在中间帧

      Directory(_outDir).createSync(recursive: true);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$_outDir/transition_${ms}ms.png'),
      );
    });
  }
}
