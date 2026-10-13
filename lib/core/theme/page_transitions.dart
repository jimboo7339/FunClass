import 'package:flutter/material.dart';

/// 二级页转场：纯淡入，不缩放、不压暗旧页面
///
/// 换掉这个是为了治两个毛病：
///
/// 1. **背景变暗**。Android 的默认转场是 [ZoomPageTransitionsBuilder]，
///    它会在旧页面上叠一层最高 25% 不透明度的黑色遮罩（越推进越暗）。
///    本项目玻璃模式下整页是浅色渐变，那层黑遮罩盖上去就是一块明显的灰，
///    看着像页面自己变色了。
/// 2. **卡顿**。缩放转场每帧都在给整棵子树换一个 scale，页面里每块玻璃卡片的
///    BackdropFilter 都得按新尺寸重新模糊一遍，一屏十几张卡片就是十几次全屏模糊
///    ——帧率就是这么掉下去的。淡入不一样：透明度改的是图层属性，
///    下面的 RepaintBoundary 让卡片内容只光栅化一次，逐帧只改 alpha。
///
/// 旧页面原地不动（不跟着推走、不加次级动画），它自己那套模糊也不需要重算。
/// iOS 仍然走系统的横向滑动，这里只覆盖 Android/桌面。——来自Trae
class GlassFriendlyTransitions extends PageTransitionsBuilder {
  const GlassFriendlyTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // 淡入层底下先铺一层不参与淡入的主题底色。
    //
    // 为什么需要：路由是 opaque 的，Navigator 会跳过它下面那条路由不绘制，
    // 所以整棵子树淡入的这 200 多毫秒里，底下什么都没有，透出来的是窗口黑底——
    // 用户看到的就是"进二级页时背景黑一下"。2026-10-11 起页面背景自己带渐变，
    // 这层底色取的是渐变顶部的同色，看起来就是"背景先铺上、内容再淡入"。
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
        FadeTransition(
          opacity: curved,
          child: RepaintBoundary(child: child),
        ),
      ],
    );
  }
}
