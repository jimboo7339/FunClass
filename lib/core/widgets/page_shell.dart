import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'glass_widgets.dart';

/// 底部悬浮导航栏的占位高度
///
/// 玻璃模式下 [HomeShell] 会开 `extendBody`，让页面内容（含玻璃背景）一直铺到
/// 屏幕底部、从导航栏下方穿过。但页面内部的 Scaffold 看不到外层的导航栏，
/// 它的 FAB 会沉到导航栏背后，所以由 HomeShell 把高度传下来给它让位。
/// 独立路由（非 Tab 页）没有这层，返回 0。—���来自Trae
class BottomNavInset extends InheritedWidget {
  const BottomNavInset({
    super.key,
    required this.height,
    required super.child,
  });

  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BottomNavInset>()?.height ?? 0;

  @override
  bool updateShouldNotify(BottomNavInset oldWidget) =>
      oldWidget.height != height;
}

/// 各 Tab 页统一外壳
///
/// 背景是一层静态柔和渐变（顶部与标题栏同色无缝衔接，底部微微发蓝），
/// 页面内容浮在上面，卡片靠描边 + 阴影分层——来自Trae
/// 2026-10-11 起普通模式也用它：整屏纯色太素，而这层渐变只是两层径向渐变，
/// 不含 BackdropFilter，没有玻璃模式那种掉帧开销；玻璃模式沿用同一层。
class PageShell extends ConsumerWidget {
  const PageShell({
    super.key,
    required this.title,
    this.actions,
    this.floatingActionButton,
    required this.body,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appBar = AppBar(
      title: Text(title),
      actions: actions,
      // 渐变背景铺在 Scaffold 之下，标题栏必须透明，否则顶部会出现一条纯色栏，
      // 与下方渐变形成硬接缝。状态栏图标明暗由 AppBarTheme.systemOverlayStyle
      // 显式指定（透明背景推不出亮度）——来自Trae
      backgroundColor: Colors.transparent,
    );

    // 外层悬浮导航栏（开启悬浮导航时）在内容之上，FAB 抬到它上面，
    // 否则会藏进导航条背后；贴底导航/独立路由时 BottomNavInset 为 0，无影响——来自Trae
    final fab = (floatingActionButton == null)
        ? null
        : Padding(
            padding: EdgeInsets.only(bottom: BottomNavInset.of(context)),
            child: floatingActionButton!,
          );

    return Stack(
      children: [
        Positioned.fill(child: GlassBackground(child: const SizedBox.shrink())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          floatingActionButton: fab,
        ),
      ],
    );
  }
}

/// 编辑页 Scaffold（sticky 保存栏 + 未保存离开拦截）
/// 与 PageShell 共用同一套渐变背景与透明标题栏，保证和列表页是同一种材质语言——来自Trae
class EditPageShell extends ConsumerWidget {
  const EditPageShell({
    super.key,
    required this.title,
    required this.body,
    this.saveLabel = '保存',
    this.onSave,
    this.isSaving = false,
    this.onPopInvoked,
  });

  final String title;
  final Widget body;
  final String saveLabel;
  final VoidCallback? onSave;
  final bool isSaving;
  final Future<bool> Function()? onPopInvoked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
      ),
      body: body,
      bottomNavigationBar: onSave == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: isSaving
                    ? const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : GlassButton(
                        label: saveLabel,
                        expand: true,
                        height: 48,
                        onPressed: onSave,
                      ),
              ),
            ),
    );

    return PopScope(
      canPop: onPopInvoked == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || onPopInvoked == null) return;
        final shouldPop = await onPopInvoked!();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
              child: GlassBackground(child: const SizedBox.shrink())),
          scaffold,
        ],
      ),
    );
  }
}
