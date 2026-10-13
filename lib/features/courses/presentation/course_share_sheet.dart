import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../data/database/app_database.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';

/// 课程课时分享图：弹层预览一张进度卡片，点「分享」即时把卡片渲染成 PNG 走系统分享面板。
///
/// 卡片只体现「已上 / 剩余」两个数字和有效期，**刻意不显示待上节数**——
/// 未发生的课可能因调课整体后延，只要还在有效期内上完就行，
/// 用待上数反而会把"没上课"的焦虑传出去。——来自Trae
Future<void> showCourseShareSheet(
  BuildContext context, {
  required Course course,
  required String memberName,
  required int attendedCount,
}) {
  return showAppBottomSheet<void>(
    context: context,
    child: _SharePreviewSheet(
      course: course,
      memberName: memberName,
      attendedCount: attendedCount,
    ),
  );
}

/// 弹层内容：卡片预览 + 分享按钮
class _SharePreviewSheet extends StatefulWidget {
  const _SharePreviewSheet({
    required this.course,
    required this.memberName,
    required this.attendedCount,
  });

  final Course course;
  final String memberName;
  final int attendedCount;

  @override
  State<_SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<_SharePreviewSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  /// 抓卡片 → PNG → 写临时文件 → 系统分享面板
  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      final renderObject =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (renderObject == null) throw Exception('卡片还没渲染好，稍等重试');
      // 3 倍像素密度：屏幕上看是 300 宽的卡片，导出 900px，微信里放大也清晰
      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw Exception('图片编码失败');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}'
        'funclass_share_${widget.course.id}_'
        '${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${widget.course.name} · ${widget.memberName}',
          subject: widget.course.name,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('分享失败：$e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final attended = widget.attendedCount;
    final remaining = course.totalLessons > attended
        ? course.totalLessons - attended
        : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '课时进度分享图',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 卡片本体按真实尺寸渲染；截图边界在卡片内部（见 _CourseShareCard.boundaryKey），
          // 保证导出的 PNG 正好是卡片、四周无透明边——来自Trae
          _CourseShareCard(
            boundaryKey: _cardKey,
            course: course,
            memberName: widget.memberName,
            attended: attended,
            remaining: remaining,
          ),
          const SizedBox(height: 16),
          if (_sharing)
            const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GlassButton(
              label: '分享这张图',
              icon: Icons.share_outlined,
              expand: true,
              height: 48,
              borderRadius: 16,
              tint: Theme.of(context).colorScheme.primary,
              onPressed: _share,
            ),
        ],
      ),
    );
  }
}

/// 保证白色文字压得住：过亮的底色往黑色压深
///
/// 与上课记录页概览卡同一套规则：课程色是用户自己挑的，
/// 亮黄浅粉这类颜色白字几乎看不见，按相对亮度压深到能压住白字为止。——来自Trae
Color _readableBase(Color color) {
  if (color.computeLuminance() <= 0.45) return color;
  var out = color;
  for (var i = 0; i < 8 && out.computeLuminance() > 0.2; i++) {
    out = Color.lerp(out, const Color(0xFF000000), 0.25)!;
  }
  return out;
}

/// 分享卡片：固定宽度、自包含配色（不跟随深浅主题），导出后在哪都能看
class _CourseShareCard extends StatelessWidget {
  const _CourseShareCard({
    required this.course,
    required this.memberName,
    required this.attended,
    required this.remaining,
    this.boundaryKey,
  });

  final Course course;
  final String memberName;
  final int attended;
  final int remaining;
  // 截图边界挂在这张卡本身（300 宽），不能挂在外层 Center 上，
  // 否则 Center 横向撑满弹层、卡片两侧会留一条透明边，被微信渲染成白底——来自Trae
  final GlobalKey? boundaryKey;

  @override
  Widget build(BuildContext context) {
    final tagColor = course.colorTag != null
        ? ColorHex.fromHex(course.colorTag!)
        : Theme.of(context).colorScheme.primary;
    final base = _readableBase(tagColor);
    // 渐变第二段用同色系压深，不用 alpha 渐隐（PNG 无背景，透明会出灰边）
    final end = Color.lerp(base, const Color(0xFF000000), 0.22)!;

    // 总数用 已上+剩余 反推：加课导致已上超出套餐时，剩余为 0、进度自然满格
    final totalCount = attended + remaining;
    final progress = totalCount == 0
        ? 0.0
        : (attended / totalCount).clamp(0.0, 1.0);
    final permanent = isPermanentValidTo(course.validTo);

    return Center(
      child: RepaintBoundary(
        key: boundaryKey,
        child: SizedBox(
          width: 300,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base, end],
              ),
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：应用标识
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '趣课 · 课时进度',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // 课程名 + 学员
                Text(
                  course.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    memberName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // 两个核心数字：已上 / 剩余
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _statBlock('已上课时', '$attended', '节')),
                    Container(
                      width: 1,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    Expanded(child: _statBlock('剩余课时', '$remaining', '节')),
                  ],
                ),
                const SizedBox(height: 18),
                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  permanent ? '有效期不限，慢慢上' : '剩余课时需在有效期内上完',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                if (!permanent) ...[
                  const SizedBox(height: 2),
                  Text(
                    '有效期至 ${DateUtilsTool.formatDate(course.validTo)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // 底部署名
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '由「趣课」记录 · ${DateUtilsTool.formatDate(DateTime.now())}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBlock(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
