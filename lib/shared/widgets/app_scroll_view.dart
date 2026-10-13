import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 统一 ListView 包装（自动 padding + 可选下拉刷新）
class AppScrollView extends StatelessWidget {
  const AppScrollView({
    super.key,
    required this.children,
    this.onRefresh,
    this.includeBottomNavClearance = true,
    this.controller,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool includeBottomNavClearance;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final padding = includeBottomNavClearance
        ? AppTokens.pagePadding(context)
        : AppTokens.pagePaddingWithoutNav(context);

    final listView = ListView(
      controller: controller,
      padding: padding,
      children: children,
    );

    if (onRefresh == null) return listView;

    return RefreshIndicator(onRefresh: onRefresh!, child: listView);
  }
}
