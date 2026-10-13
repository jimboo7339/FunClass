import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/help/help_topics.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/page_shell.dart';
import '../../../core/widgets/settings_gear_button.dart';
import '../../../shared/widgets/app_scroll_view.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/help_button.dart';
import '../../courses/presentation/course_timeline_page.dart';
import '../providers/stats_providers.dart';

/// 统计分析页
class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  late final PageController _pageController;

  static const _tabs = <GlassSegmentedItem<String>>[
    GlassSegmentedItem(value: 'course', label: '单课程'),
    GlassSegmentedItem(value: 'member', label: '按成员'),
    GlassSegmentedItem(value: 'family', label: '按家庭'),
  ];

  /// 当前页的连续位置：0 / 1 / 2 之间的小数表示正滑到一半，直接驱动上方药丸
  double _page = 0;

  /// 当前页（_page 四舍五入后的结果），用于决定哪一项高亮
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 用 PageController 而不是 TabController：TabController.offset 静止时恒为 0、
    // 点击跳转时是直接跳变，中间的滑动过程读不到；PageController.page 在手指
    // 拖动的每一帧都是真实位置，药丸才能真正跟手——来自Trae
    _pageController = PageController()..addListener(_onPageScroll);
  }

  void _onPageScroll() {
    if (!mounted || !_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;
    final index = page.round().clamp(0, _tabs.length - 1);
    if (page == _page && index == _index) return;
    setState(() {
      _page = page;
      _index = index;
    });
  }

  void _onTabSelected(String value) {
    final i = _tabs.indexWhere((e) => e.value == value);
    if (i < 0 || i == _index) return;
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statsProvider);

    return PageShell(
      title: '统计分析',
      actions: [
        const HelpButton(topic: HelpTopics.statistics),
        buildSettingsGear(context),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: GlassSegmented<String>(
              items: _tabs,
              value: _tabs[_index].value,
              position: _page,
              onChanged: _onTabSelected,
            ),
          ),
          Expanded(
            child: statsAsync.when(
              data: (stats) => PageView(
                controller: _pageController,
                children: [
                  _CourseStatsView(courseStats: stats.courseStats),
                  _MemberStatsView(memberStats: stats.memberStats),
                  _FamilyStatsView(family: stats.familyAnnual),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseStatsView extends StatelessWidget {
  final List<CourseStatDetail> courseStats;
  const _CourseStatsView({required this.courseStats});

  @override
  Widget build(BuildContext context) {
    if (courseStats.isEmpty) {
      return const EmptyStateView(
        icon: Icons.bar_chart_outlined,
        title: '暂无课程数据',
        subtitle: '添加课程后这里会显示统计信息',
      );
    }
    return AppScrollView(
      children: courseStats
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    // 点击跳时间轴，不再跳编辑——来自Trae
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CourseTimelinePage(courseId: s.courseId),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.courseName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                s.memberName,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              // 加课时已上数可能超过购课总数（出勤率 > 1），
                              // 进度条必须 clamp 到 0~1，否则 debug 模式断言崩溃
                              value: s.attendanceRate.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _statChip(context, '已上课', '${s.attendedCount} 节'),
                              _statChip(context, '剩余课时', '${s.remainingLessons} 节'),
                              _statChip(
                                context,
                                '均价',
                                '¥${s.unitPrice.toStringAsFixed(1)}',
                              ),
                              _statChip(
                                context,
                                '消耗金额',
                                '¥${s.consumedAmount.toStringAsFixed(0)}',
                              ),
                              _statChip(
                                context,
                                '出勤率',
                                '${(s.attendanceRate * 100).toStringAsFixed(0)}%',
                              ),
                              _statChip(
                                context,
                                '有效期剩余',
                                // -1 = 永久课程，显示「长期有效」而不是 2912159 天——2026-10-11
                                s.validDaysRemaining < 0
                                    ? '长期有效'
                                    : '${s.validDaysRemaining} 天',
                                color: s.validDaysRemaining >= 0 &&
                                        s.validDaysRemaining < 30
                                    ? Colors.orange
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _MemberStatsView extends StatefulWidget {
  final List<MemberStat> memberStats;
  const _MemberStatsView({required this.memberStats});

  @override
  State<_MemberStatsView> createState() => _MemberStatsViewState();
}

class _MemberStatsViewState extends State<_MemberStatsView> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.memberStats.isEmpty) {
      return const EmptyStateView(
        icon: Icons.people_outline,
        title: '暂无成员数据',
      );
    }

    final maxSpent = widget.memberStats
        .map((m) => m.totalSpent)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final barGroups = widget.memberStats.asMap().entries.map((e) {
      final i = e.key;
      final m = e.value;
      final selected = _selectedIndex == i;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: m.totalSpent,
            color: _parseColor(m.colorTag).withValues(
              alpha: selected ? 1.0 : 0.75,
            ),
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return AppScrollView(
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '各成员总支出',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxSpent == 0 ? 1 : maxSpent * 1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          if (response?.spot == null) return;
                          setState(() {
                            _selectedIndex = response!.spot!.touchedBarGroupIndex;
                          });
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final idx = value.toInt();
                              if (idx < 0 ||
                                  idx >= widget.memberStats.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  widget.memberStats[idx].memberName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...widget.memberStats.asMap().entries.map((e) {
          final selected = _selectedIndex == e.key;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: GlassCard(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _parseColor(e.value.colorTag),
                  child: Text(e.value.memberName[0]),
                ),
                title: Text(e.value.memberName),
                subtitle: Text('总上课时 ${e.value.totalAttended} 节'),
                trailing: Text(
                  '¥${e.value.totalSpent.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _FamilyStatsView extends StatelessWidget {
  final FamilyAnnualStat family;
  const _FamilyStatsView({required this.family});

  @override
  Widget build(BuildContext context) {
    final total = family.totalSpent;
    return AppScrollView(
      children: [
        GradientStatCard(
          child: Column(
            children: [
              Text(
                '${family.year} 年家庭总支出',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¥${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '总上课时 ${family.totalAttended} 节',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (family.memberBreakdown.isNotEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '各成员支出占比',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 50,
                            sections: family.memberBreakdown.map((m) {
                              final pct = total == 0
                                  ? 0.0
                                  : (m.totalSpent / total) * 100;
                              return PieChartSectionData(
                                value: m.totalSpent,
                                color: _parseColor(m.colorTag),
                                title: '${pct.toStringAsFixed(0)}%',
                                radius: 70,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Text(
                          '¥${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...family.memberBreakdown.map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _parseColor(m.colorTag),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(m.memberName)),
                            Text('¥${m.totalSpent.toStringAsFixed(0)}'),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Widget _statChip(BuildContext context, String label, String value,
    {Color? color}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );
}

Color _parseColor(String hex) {
  final hexStr = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hexStr', radix: 16));
}
