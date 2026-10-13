import 'dart:ui' show FrameTiming;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 液态玻璃效果质量档位
///
/// full = 折射完整（LiquidGlassLens，液态感最强）；
/// reduced = 低端机持续掉帧时自动降级为轻量毛玻璃（保留模糊与半透明，去掉折射扭曲）。
enum GlassQuality { full, reduced }

class GlassQualityNotifier extends StateNotifier<GlassQuality> {
  GlassQualityNotifier() : super(GlassQuality.full);

  /// 是否处于监控中（只在玻璃开关打开时监控，避免普通模式误判）
  bool _armed = false;
  int _slowBatches = 0;

  /// 转场临时降级的代际与锁定标记——来自Trae
  int _transitionGen = 0;
  bool _lockedForTransition = false;

  /// 当前是否处于转场临时锁（区别于 15s 持续掉帧触发的真降级，
  /// 设置页的「性能模式」提示据此避免误报闪烁）——来自Trae
  bool get transitionLocked => _lockedForTransition;

  /// 玻璃开关切换时调用：关闭则重置为 full 并解除监控；打开则重新武装
  void onGlassToggled(bool glassOn) {
    _armed = glassOn;
    _slowBatches = 0;
    _lockedForTransition = false;
    if (!glassOn && state != GlassQuality.full) {
      state = GlassQuality.full;
    }
  }

  /// 路由转场开始时调用：若当前是 full，临时降到 reduced，
  /// 让新页首帧只做轻量模糊（全量折射的一次性光栅化最贵，正是转场掉帧的主因）；
  /// 转场结束后自动恢复。快速连续 push 用代际计数防止旧定时器提前恢复——来自Trae
  void beginRouteTransition() {
    final gen = ++_transitionGen;
    // 首次路由的 didPush 发生在 build 期，直接改 state 会在 Riverpod 报
    // "modified during build"；微任务推迟到 build 外再改——来自Trae
    Future.microtask(() {
      if (gen != _transitionGen) return;
      if (state != GlassQuality.full || _lockedForTransition) return;
      _lockedForTransition = true;
      state = GlassQuality.reduced;
      // 路由转场 240ms 结束 + 60ms 余量即解锁：全量折射在页面「落地」后
      // 就开始渐显（GlassPanel 侧 320ms 交叉淡化），不留"停留的普通质感"窗口——来自Trae
      Future.delayed(const Duration(milliseconds: 300), () {
        if (gen != _transitionGen) return;
        _lockedForTransition = false;
        state = GlassQuality.full;
      });
    });
  }

  /// 由 [WidgetsBinding.addTimingsCallback] 驱动（约每 500ms 投递一批帧）
  /// 连续 30 批（约 15 秒）平均帧耗时 > 34ms（约 30fps）即判定低端机，降级——来自Trae
  void onFrameTimings(List<FrameTiming> timings) {
    if (!_armed || state != GlassQuality.full || timings.isEmpty) return;
    var totalMicros = 0;
    for (final t in timings) {
      totalMicros += t.totalSpan.inMicroseconds;
    }
    final avg = totalMicros / timings.length;
    if (avg > 34000) {
      _slowBatches++;
      if (_slowBatches >= 30) {
        state = GlassQuality.reduced;
        _armed = false;
      }
    } else {
      _slowBatches = 0;
    }
  }
}

/// 当前玻璃质量（自动降级、不持久化；关闭再打开玻璃会重新以 full 起步）
final glassQualityProvider =
    StateNotifierProvider<GlassQualityNotifier, GlassQuality>(
  (ref) => GlassQualityNotifier(),
);
