import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// 液态玻璃统一参数（浅色 / 深色各一组）
///
/// TabBar、FAB 等玻璃元素共用同一套颜色/模糊/折射参数，
/// 想整体调玻璃风格只改这里，避免参数散落各处不一致。
class LiquidGlassTokens {
  const LiquidGlassTokens._({
    required this.fill,
    required this.border,
    required this.pill,
    required this.blurSigma,
    required this.distortion,
    required this.distortionWidth,
    required this.bottomShadow,
    required this.bgBase,
    required this.bgTint,
    required this.cardFill,
    required this.cardBorder,
    required this.cardBlurSigma,
    required this.cardDistortion,
    required this.cardDistortionWidth,
    required this.cardShadow,
    required this.auroraA,
    required this.auroraB,
    required this.sheetFill,
    required this.sheetBorder,
    this.bgAccentMix = 0.0,
  });

  /// 玻璃主体填充色（含透明度）
  final Color fill;

  /// 玻璃主体描边色
  final Color border;

  /// TabBar 选中指示药丸的颜色
  final Color pill;

  /// 背景模糊强度
  final double blurSigma;

  /// 折射扭曲强度
  final double distortion;

  /// 折射扭曲宽度
  final double distortionWidth;

  /// 底部软阴影（深色模式下让玻璃有浮起感；浅色模式为空列表）
  final List<BoxShadow> bottomShadow;

  /// 玻璃模式页面背景基色（渐变顶部，与 AppBar / scaffoldBackgroundColor 一致）
  final Color bgBase;

  /// 页面渐变底部色（比基色略深的微色调，给玻璃折射留出层次）
  final Color bgTint;

  /// 玻璃卡片填充色（半透明，让卡片后面的背景能透出来）
  final Color cardFill;

  /// 玻璃卡片描边色
  final Color cardBorder;

  /// 玻璃卡片模糊强度（比 TabBar 小：卡片是小元素，模糊太重反而糊）
  final double cardBlurSigma;

  /// 玻璃卡片折射扭曲强度
  final double cardDistortion;

  /// 玻璃卡片折射扭曲宽度
  final double cardDistortionWidth;

  /// 玻璃卡片投影（让卡片从渐变背景上分离出来）
  final List<BoxShadow> cardShadow;

  /// 背景光斑 A：极淡的冷色光晕，给玻璃折射提供内容
  final Color auroraA;

  /// 背景光斑 B：极淡的暖色光晕，与 A 错开位置
  final Color auroraB;

  /// 背景渐变混入极光色的比例（0 = 保持中性底色，由 [of] 按强调色计算）
  final double bgAccentMix;

  /// 底部弹层（Sheet）填充色：比卡片略实，保证弹层上的文字可读
  final Color sheetFill;

  /// 底部弹层描边色
  final Color sheetBorder;

  /// 浅色：白色 55% 填充 + 黑色 12% 描边
  static const LiquidGlassTokens light = LiquidGlassTokens._(
    fill: Color(0x8CFFFFFF),
    border: Color(0x1F000000),
    pill: Color(0x14000000),
    blurSigma: 20,
    distortion: 0.06,
    distortionWidth: 16,
    bottomShadow: [],
    bgBase: Color(0xFFF8F9FB),
    bgTint: Color(0xFFEDF2FA),
    cardFill: Color(0x3DFFFFFF),
    cardBorder: Color(0x2E000000),
    cardBlurSigma: 12,
    cardDistortion: 0.04,
    cardDistortionWidth: 12,
    cardShadow: [
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 10,
        offset: Offset(0, 3),
      ),
    ],
    auroraA: Color(0x2E5B8DEF),
    auroraB: Color(0x249B7BEF),
    sheetFill: Color(0xF2FFFFFF),
    sheetBorder: Color(0x1F000000),
  );

  /// 深色：白色 12% 填充 + 白色 20% 描边 + 底部软阴影
  static const LiquidGlassTokens dark = LiquidGlassTokens._(
    fill: Color(0x1FFFFFFF),
    border: Color(0x33FFFFFF),
    pill: Color(0x38FFFFFF),
    blurSigma: 20,
    distortion: 0.06,
    distortionWidth: 16,
    bottomShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 14,
        offset: Offset(0, 4),
      ),
    ],
    bgBase: Color(0xFF111214),
    bgTint: Color(0xFF171B24),
    cardFill: Color(0x24FFFFFF),
    cardBorder: Color(0x59FFFFFF),
    cardBlurSigma: 12,
    cardDistortion: 0.04,
    cardDistortionWidth: 12,
    cardShadow: [
      BoxShadow(
        color: Color(0x59000000),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
    auroraA: Color(0x333A6EA5),
    auroraB: Color(0x2E6B4FA8),
    sheetFill: Color(0xF21A1D24),
    sheetBorder: Color(0x33FFFFFF),
  );

  /// 取与当前明暗匹配、且极光色跟随当前强调色的一组参数
  static LiquidGlassTokens of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? dark : light;

    // 极光色由主色推导，不写死蓝紫：否则用户换了强调色，玻璃背景还是原来的颜色，
    // 玻璃面和页面看起来像两个应用。透明度沿用常量里定好的那一档。
    final primary = Theme.of(context).colorScheme.primary;
    final mixTarget = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final mixAmount = isDark ? 0.25 : 0.45;
    Color aurora(Color seed, double alpha) =>
        Color.lerp(seed, mixTarget, mixAmount)!.withValues(alpha: alpha);

    return base.copyWith(
      auroraA: aurora(primary, base.auroraA.a),
      // 第二团往次色偏一点，避免两团同色叠在一起糊成一片
      auroraB: aurora(
        Color.lerp(primary, Theme.of(context).colorScheme.secondary, 0.45)!,
        base.auroraB.a,
      ),
      // 浅色主题底色本来就接近白，混 10% 就够看出倾向；
      // 深色主题底色压得很暗，混太多会染浑，所以只给 5%
      bgAccentMix: isDark ? 0.05 : 0.10,
    );
  }

  /// 只替换强调色相关参数，其余沿用
  LiquidGlassTokens copyWith({
    Color? auroraA,
    Color? auroraB,
    double? bgAccentMix,
  }) {
    return LiquidGlassTokens._(
      fill: fill,
      border: border,
      pill: pill,
      blurSigma: blurSigma,
      distortion: distortion,
      distortionWidth: distortionWidth,
      bottomShadow: bottomShadow,
      bgBase: bgBase,
      bgTint: bgTint,
      cardFill: cardFill,
      cardBorder: cardBorder,
      cardBlurSigma: cardBlurSigma,
      cardDistortion: cardDistortion,
      cardDistortionWidth: cardDistortionWidth,
      cardShadow: cardShadow,
      auroraA: auroraA ?? this.auroraA,
      auroraB: auroraB ?? this.auroraB,
      sheetFill: sheetFill,
      sheetBorder: sheetBorder,
      bgAccentMix: bgAccentMix ?? this.bgAccentMix,
    );
  }

  /// 构造共享的玻璃风格（TabBar / FAB 等）
  LiquidGlassStyle style({required double cornerRadius, double borderWidth = 1.0}) {
    return LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: cornerRadius,
        borderWidth: borderWidth,
        borderColor: border,
      ),
      appearance: LiquidGlassAppearance(
        color: fill,
        blur: LiquidGlassBlur(sigmaX: blurSigma, sigmaY: blurSigma),
      ),
      refraction: LiquidGlassRefraction(
        distortion: distortion,
        distortionWidth: distortionWidth,
      ),
    );
  }

  /// TabBar 选中指示药丸风格
  LiquidGlassTabPillStyle pillStyle() {
    return LiquidGlassTabPillStyle(
      mode: LiquidGlassPillMode.both,
      animated: true,
      animationDuration: const Duration(milliseconds: 380),
      growHeight: 10,
      distortion: distortion,
      distortionWidth: distortionWidth,
      color: pill,
    );
  }

  /// 玻璃卡片风格（模糊 + 折射 + 描边，参数比 TabBar 轻一档）
  LiquidGlassStyle cardStyle({required double cornerRadius, double borderWidth = 1.0}) {
    return LiquidGlassStyle(
      shape: LiquidGlassShape.roundedRectangle(
        cornerRadius: cornerRadius,
        borderWidth: borderWidth,
        borderColor: cardBorder,
      ),
      appearance: LiquidGlassAppearance(
        color: cardFill,
        blur: LiquidGlassBlur(
            sigmaX: cardBlurSigma, sigmaY: cardBlurSigma),
      ),
      refraction: LiquidGlassRefraction(
        distortion: cardDistortion,
        distortionWidth: cardDistortionWidth,
      ),
    );
  }

  /// 玻璃底部弹层风格（比卡片更实，保证弹层上的文字可读）
  LiquidGlassStyle sheetStyle({
    double cornerRadius = 24,
    double borderWidth = 1.0,
  }) {
    return LiquidGlassStyle(
      shape: LiquidGlassShape.roundedRectangle(
        cornerRadius: cornerRadius,
        borderWidth: borderWidth,
        borderColor: sheetBorder,
      ),
      appearance: LiquidGlassAppearance(
        color: sheetFill,
        blur: LiquidGlassBlur(sigmaX: blurSigma, sigmaY: blurSigma),
      ),
      refraction: LiquidGlassRefraction(
        distortion: distortion,
        distortionWidth: distortionWidth,
      ),
    );
  }

  /// 玻璃模式页面细腻渐变（顶部 = 基色，与标题栏无缝衔接；底部 = 微色调）
  LinearGradient backgroundGradient() {
    // 底色整体往强调色上靠一点（比例由 [of] 按当前强调色算好），
    // 玻璃背景才和当前主题是一家人，而不是永远的一片淡蓝——来自Trae
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(bgBase, auroraA, bgAccentMix)!,
        Color.lerp(bgTint, auroraA, bgAccentMix)!,
      ],
    );
  }
}
