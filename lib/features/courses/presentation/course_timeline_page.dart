import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/help/help_topics.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/liquid_glass_tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/page_shell.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../members/providers/member_providers.dart';
import '../../shared/providers/lesson_providers.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/help_button.dart';
import '../providers/course_providers.dart';
import 'course_share_sheet.dart';

/// 课程课次时间轴页
/// 左侧竖线+节点圆点，右侧卡片展示每次上课记录
/// 支持按状态过滤：全部 / 已上 / 待上 / 跳过 ——来自Trae
class CourseTimelinePage extends ConsumerStatefulWidget {
  const CourseTimelinePage({super.key, required this.courseId});

  final int courseId;

  @override
  ConsumerState<CourseTimelinePage> createState() => _CourseTimelinePageState();
}

class _CourseTimelinePageState extends ConsumerState<CourseTimelinePage> {
  /// 当前选中的过滤状态，null 表示全部。
  /// 默认只看「已上」：这个页面主用途是查上课记录，未来排程列表反而干扰——来自Trae
  LessonStatus? _filterStatus = LessonStatus.attended;

  void _setFilter(LessonStatus? s) {
    setState(() => _filterStatus = s);
  }

  /// 编辑课次备注：弹底部弹层让用户输入——来自Trae
  Future<void> _editNote(Lesson lesson) async {
    final controller = TextEditingController(text: lesson.note ?? '');
    final scheme = Theme.of(context).colorScheme;
    // 走统一玻璃弹层，不再用 AlertDialog：同屏里混两种材质正是违和感的来源
    final saved = await showAppBottomSheet<String>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${lesson.date.month}月${lesson.date.day}日 备注',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '记下这次上课的情况，比如：表现好、请假、迟到…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: '保存',
              expand: true,
              height: 48,
              borderRadius: 16,
              tint: scheme.primary,
              onPressed: () => Navigator.pop(context, controller.text),
            ),
            if (lesson.note != null && lesson.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: '清除',
                      expand: true,
                      height: 48,
                      borderRadius: 16,
                      outlined: true,
                      tint: scheme.error,
                      onPressed: () => Navigator.pop(context, ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GlassButton(
                      label: '取消',
                      expand: true,
                      height: 48,
                      borderRadius: 16,
                      outlined: true,
                      tint: scheme.primary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == null) return; // 用户取消
    final note = saved.trim().isEmpty ? null : saved.trim();
    await ref.read(lessonActionsProvider).updateNote(lesson.id, note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('备注已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseProvider(widget.courseId));
    final lessonsAsync = ref.watch(lessonsByCourseProvider(widget.courseId));
    final membersAsync = ref.watch(membersProvider);

    return courseAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('加载失败: $e'))),
      data: (course) {
        if (course == null) {
          return const Scaffold(body: Center(child: Text('课程不存在')));
        }
        final member = (membersAsync.valueOrNull ?? [])
            .where((m) => m.id == course.memberId)
            .firstOrNull;

        return PageShell(
          title: '上课记录',
          // 顶栏分享入口：把课时进度生成图片走系统分享——来自Trae
          actions: [
            const HelpButton(topic: HelpTopics.timeline),
            IconButton(
              tooltip: '生成分享图',
              icon: const Icon(Icons.share_outlined),
              onPressed: () async {
                final attended = await ref
                    .read(attendedCountProvider(course.id).future);
                if (!context.mounted) return;
                showCourseShareSheet(
                  context,
                  course: course,
                  memberName: member?.name ?? '未知成员',
                  attendedCount: attended,
                );
              },
            ),
          ],
          body: lessonsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (lessons) {
              return _buildBody(context, course, member, lessons);
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    Course course,
    Member? member,
    List<Lesson> lessons,
  ) {
    final color = course.colorTag != null
        ? ColorHex.fromHex(course.colorTag!)
        : AppColors.primary;

    // 概览数字：已上 / 剩余(=总课时−已上) / 总课时。
    // 不再显示"待上/跳过"——未来排程恒等于剩余课时，漏上的会自动后延——来自Trae
    final attendedCount =
        lessons.where((l) => l.status == LessonStatus.attended).length;
    final remaining =
        course.totalLessons > attendedCount ? course.totalLessons - attendedCount : 0;

    // 应用过滤
    final filtered = _filterStatus == null
        ? lessons
        : lessons.where((l) => l.status == _filterStatus).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // 顶部课程概览卡（已上/剩余/总）
        _CourseHeaderCard(
          course: course,
          member: member,
          color: color,
          attended: attendedCount,
          remaining: remaining,
        ),
        const SizedBox(height: 16),
        // 状态过滤栏（极简纯文字）——来自Trae
        _FilterBar(
          filter: _filterStatus,
          onChanged: _setFilter,
        ),
        const SizedBox(height: 12),
        // 过滤后的时间轴主体
        if (filtered.isEmpty)
          _EmptyFilteredView(
            filter: _filterStatus,
            onClear: () => _setFilter(null),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Timeline(
              lessons: filtered,
              color: color,
              onEditNote: _editNote,
            ),
          ),
      ],
    );
  }
}

// ===== 以下是 UI 组件 =====

/// 保证白色文字压得住：过亮的底色往黑色压深
///
/// 课程颜色是用户自己挑的，选到亮黄、浅粉这类色时白字几乎看不见。
/// 这里按相对亮度判断，只有亮到会糊掉白字的程度（> 0.45）才动手，
/// 压到 0.20 左右收手；正常鲜艳的颜色（橙、蓝、紫等）原样保留，
/// 不会因为加了这条逻辑就整体变闷——来自Trae
Color _ensureWhiteTextContrast(Color color) {
  if (color.computeLuminance() <= 0.45) return color;
  var out = color;
  for (var i = 0; i < 8 && out.computeLuminance() > 0.2; i++) {
    out = Color.lerp(out, const Color(0xFF000000), 0.25)!;
  }
  return out;
}

/// 课程概览卡
class _CourseHeaderCard extends ConsumerWidget {
  const _CourseHeaderCard({
    required this.course,
    required this.member,
    required this.color,
    required this.attended,
    required this.remaining,
  });

  final Course course;
  final Member? member;
  final Color color;
  final int attended;
  final int remaining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 进度以课程设定的总课时为准（不再用生成行数）
    final total = course.totalLessons;
    final progress = total == 0 ? 0.0 : (attended / total).clamp(0.0, 1.0);

    // 玻璃模式下把课程色向背景色靠拢一点，避免顶部一块生硬的实心色块；
    // 但只掺 15%——bgTint 是接近白的颜色，掺多了等于把底色洗淡，
    // 白字压在上面就读不清了（这正是之前 40% 带来的问题）——来自Trae
    final isGlass = ref.watch(isLiquidGlassProvider);
    final tokens = LiquidGlassTokens.of(context);
    final mixed = isGlass ? Color.lerp(color, tokens.bgTint, 0.15)! : color;
    final base = _ensureWhiteTextContrast(mixed);

    // 渐变的第二段不能用 alpha 渐隐：半透明会透出下面的浅色渐变背景，
    // 等于又变淡一次。改成同色系压深，白字的对比度才立得住
    final end = isGlass
        ? Color.lerp(base, const Color(0xFF000000), 0.12)!
        : base.withValues(alpha: 0.7);

    // 复用课程列表页的大卡组件：同一套圆角 / 投影 / 亮边 / 顶部高光，
    // 两处概览卡读起来才是同一种材质——来自Trae
    return GradientStatCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      colors: [base, end],
      padding: const EdgeInsets.all(20),
      desaturate: false,
      shadowColor: base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.book_outlined,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member?.name ?? '未知',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 三个统计格：已上 / 剩余 / 总课时。
          // 「待上」「跳过」都不再展示——未来排程恒等于剩余，漏上的自动后延——来自Trae
          Row(
            children: [
              _statWithColor('已上', '$attended', Colors.greenAccent),
              Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.25)),
              _statWithColor('剩余', '$remaining', Colors.white),
              Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.25)),
              _stat('总课时', '${course.totalLessons}'),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statWithColor(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }
}

/// 课次状态过滤栏：玻璃分段控件（普通模式回退 Material 分段控件）
/// 四个状态互斥，选中项是一枚玻璃药丸——来自Trae
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.onChanged,
  });

  final LessonStatus? filter;
  final ValueChanged<LessonStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GlassSegmented<LessonStatus?>(
        value: filter,
        onChanged: onChanged,
        items: const [
          GlassSegmentedItem<LessonStatus?>(label: '全部', value: null),
          GlassSegmentedItem<LessonStatus?>(
              label: '已上', value: LessonStatus.attended),
          GlassSegmentedItem<LessonStatus?>(
              label: '待上', value: LessonStatus.pending),
          GlassSegmentedItem<LessonStatus?>(
              label: '未上', value: LessonStatus.skipped),
        ],
      ),
    );
  }
}

/// 过滤后为空的空状态——来自Trae
class _EmptyFilteredView extends StatelessWidget {
  const _EmptyFilteredView({required this.filter, required this.onClear});

  final LessonStatus? filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = filter == null
        ? '全部'
        : filter == LessonStatus.attended
            ? '已上'
            : filter == LessonStatus.pending
                ? '待上'
                : '未上';
    return Center(
      heightFactor: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('暂无「$label」的课次',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear),
            label: const Text('清除过滤'),
          ),
        ],
      ),
    );
  }
}

// ===== 时间轴组件 =====

/// 时间轴：左侧贯穿竖线 + 节点圆点，右侧卡片
/// 自然 Row 列表布局，跨年时插入年份分隔符——来自Trae
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.lessons,
    required this.color,
    required this.onEditNote,
  });
  final List<Lesson> lessons;
  final Color color;
  final ValueChanged<Lesson> onEditNote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 预先计算年份断点：每个 index 对应的年份（同一年只记第一年）
    final yearAt = <int, int>{};
    int? lastYear;
    for (int i = 0; i < lessons.length; i++) {
      final y = lessons[i].date.year;
      if (y != lastYear) {
        yearAt[i] = y;
        lastYear = y;
      }
    }

    final rows = <Widget>[];
    for (int i = 0; i < lessons.length; i++) {
      // 年份分隔
      if (yearAt.containsKey(i)) {
        rows.add(_YearDivider(year: yearAt[i]!, scheme: scheme));
      }
      rows.add(
        _TimelineRow(
          lesson: lessons[i],
          color: color,
          onEditNote: () => onEditNote(lessons[i]),
          scheme: scheme,
          showTopLine: i > 0,
          showBottomLine: i < lessons.length - 1,
        ),
      );
    }
    return Column(children: rows);
  }
}

/// 年份分隔符：年份文字 + 横线——来自Trae
class _YearDivider extends StatelessWidget {
  const _YearDivider({required this.year, required this.scheme});
  final int year;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Row(
        children: [
          SizedBox(width: 32, child: Center(
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
            ),
          )),
          Text(
            '$year',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单行：左侧贯穿竖线 + 节点 + 右侧卡片
/// 左侧用固定高度 SizedBox + Stack 叠加竖线和节点——来自Trae
class _TimelineRow extends ConsumerWidget {
  const _TimelineRow({
    required this.lesson,
    required this.color,
    required this.onEditNote,
    required this.scheme,
    required this.showTopLine,
    required this.showBottomLine,
  });

  final Lesson lesson;
  final Color color;
  final VoidCallback onEditNote;
  final ColorScheme scheme;
  final bool showTopLine;
  final bool showBottomLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeColor = statusColor(lesson.status);
    // 玻璃模式下连线与节点外圈都压到半透明：实色圆环叠在玻璃上会显得是块贴上去的补丁，
    // 半透明才能和背后的玻璃一起读——来自Trae
    final isGlass = ref.watch(isLiquidGlassProvider);
    final lineColor =
        scheme.outlineVariant.withValues(alpha: isGlass ? 0.32 : 0.6);
    final ringColor =
        scheme.surface.withValues(alpha: isGlass ? 0.45 : 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：竖线 + 节点（固定高度，让 Row 能正确测量）
        SizedBox(
          width: 32,
          height: 100, // 固定高度，让 Stack 有约束
          child: Stack(
            children: [
              // 贯穿竖线：用三个 Container 分别画 上/节点位置/下 三段——来自Trae
              // 上半段：从 SizedBox 顶部到节点中心（showTopLine 才画）
              if (showTopLine)
                Positioned(
                  top: 0,
                  left: 15,
                  child: Container(width: 2, height: 22, color: lineColor),
                ),
              // 下半段：从节点中心到 SizedBox 底部（showBottomLine 才画）
              if (showBottomLine)
                Positioned(
                  top: 42,
                  left: 15,
                  child: Container(width: 2, height: 58, color: lineColor),
                ),
              // 节点圆点
              Positioned(
                top: 12,
                left: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: nodeColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(statusIcon(lesson.status),
                      size: 10, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        // 右侧：卡片（Expanded 自适应剩余宽度）
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LessonCard(
              lesson: lesson,
              color: color,
              onEditNote: onEditNote,
            ),
          ),
        ),
      ],
    );
  }
}

/// 时间轴上的课次卡片——来自Trae
class _LessonCard extends ConsumerWidget {
  const _LessonCard({
    required this.lesson,
    required this.color,
    required this.onEditNote,
  });

  final Lesson lesson;
  final Color color;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final chipColor = statusColor(lesson.status);
    final weekday = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
        [lesson.date.weekday - 1];
    final isToday = _isSameDay(lesson.date, DateTime.now());

    // 玻璃模式：课次卡片换成折射玻璃面板；关闭时沿用原来的实心底+描边——来自Trae
    final isGlass = ref.watch(isLiquidGlassProvider);
    Widget cardSurface(Widget child) {
      if (isGlass) {
        return GlassPanel(
          borderRadius: 14,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: child,
      );
    }

    return GestureDetector(
      // 长按也能快速进入备注编辑——来自Trae
      onLongPress: onEditNote,
      child: cardSurface(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：状态胶囊（左） + 编辑备注按钮（右）——来自Trae
            Row(
              children: [
                // 状态胶囊
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon(lesson.status),
                          size: 12, color: chipColor),
                      const SizedBox(width: 3),
                      Text(
                        lesson.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: chipColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // 编辑备注按钮——来自Trae
                IconButton(
                  onPressed: onEditNote,
                  icon: Icon(Icons.edit_note_outlined,
                      size: 18, color: scheme.onSurfaceVariant),
                  tooltip: '编辑备注',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 2),
            // 第二行：日期 + 周几 + 标签，独立一行不拥挤——来自Trae
            Row(
              children: [
                Text(
                  '${lesson.date.year}年${lesson.date.month}月${lesson.date.day}日',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(weekday,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    )),
                if (isToday) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('今天',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                if (lesson.isExtra) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('加课',
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.primary,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${lesson.startTime} - ${lesson.endTime}',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (lesson.attendedAt != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '记录于 ${lesson.attendedAt!.hour.toString().padLeft(2, '0')}:${lesson.attendedAt!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
            if (lesson.note != null && lesson.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              // 玻璃模式下外层卡片本身已经上过色，备注块再填一层底色就成了「灰斑」。
              // 改成一条左侧竖线提示块，只保留可读性所需的分隔，不再叠第二层染色——来自Trae
              if (ref.watch(isLiquidGlassProvider))
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      margin: const EdgeInsets.only(top: 2, right: 8),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        lesson.note!,
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          lesson.note!,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ===== 文件级辅助函数（供多个 widget 共享）=====

/// 根据状态返回颜色——来自Trae
Color statusColor(LessonStatus s) {
  switch (s) {
    case LessonStatus.attended:
      return const Color(0xFF4CAF50);
    case LessonStatus.skipped:
      return const Color(0xFFFF9800);
    case LessonStatus.pending:
      return const Color(0xFF9E9E9E);
  }
}

/// 根据状态返回图标——来自Trae
IconData statusIcon(LessonStatus s) {
  switch (s) {
    case LessonStatus.attended:
      return Icons.check;
    case LessonStatus.skipped:
      return Icons.close;
    case LessonStatus.pending:
      return Icons.schedule;
  }
}