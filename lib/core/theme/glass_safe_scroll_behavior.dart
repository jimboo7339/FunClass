import 'package:flutter/material.dart';

/// 玻璃安全滚动行为
///
/// Android Material 3 默认的下拉回弹是「拉伸」效果（[StretchingOverscrollIndicator]），
/// 它会把滚动内容整体缩放进一个独立的合成图层；液态玻璃的 [BackdropFilter]
/// 在该图层里采样不到真实背景，玻璃卡片会整块变黑（liquid_glass_easy 也明确要求
/// 含镜片的滚动视图关掉 stretch）。
///
/// 这里统一改用 [GlowingOverscrollIndicator]：只在边缘画一圈发光，不对内容做
/// 缩放/分层，BackdropFilter 因此始终能采到真实背景，回弹手感也基本保留。
/// 来自Trae
class GlassSafeScrollBehavior extends MaterialScrollBehavior {
  const GlassSafeScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (getPlatform(context) == TargetPlatform.android) {
      return GlowingOverscrollIndicator(
        axisDirection: details.direction,
        color: Theme.of(context).colorScheme.secondary,
        child: child,
      );
    }
    return super.buildOverscrollIndicator(context, child, details);
  }
}