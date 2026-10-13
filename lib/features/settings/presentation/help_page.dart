import 'package:flutter/material.dart';

import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/page_shell.dart';
import '../../../shared/widgets/app_scroll_view.dart';
import '../../../shared/widgets/section_header.dart';

/// 使用手册：完整操作说明，嵌在设置页「关于」分组里。
/// 内容对齐 v24 排课模型（排满总课时 / 未上课顺延 / 历史记录冻结），
/// 改排课逻辑时记得同步改这里。——来自Trae
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '使用手册',
      body: AppScrollView(
        children: [
          _section(
            context,
            '快速上手',
            '1. 在「课程」页点右下角 ＋ 新建一门课：填学员、总课时、有效期和每周上课频率。\n'
            '2. 保存后 App 会自动排出未来的课次计划。\n'
            '3. 每次上完课，在「今日」或课程卡片上点「已上课」（记一节）。\n'
            '4. 临时加课、请假改期，都有对应操作，见下面「排课与顺延规则」。',
          ),
          _section(
            context,
            '排课与顺延规则（核心）',
            '排课只排「总课时」那么多节，不是把有效期铺满。\n'
            '例：买了 50 节，每周六、日各一节——计划就是从开始日起往后排 50 节，排到哪一天算哪一天；两年有效期装得下 100 多个周六日，也只排 50 节。\n\n'
            '· 漏上一节：到点了没记，先点「未上课」——这节不占课时，计划末尾自动补一节（顺延）。\n'
            '· 多上一节：点「已上课」或「加一节」——已上数 +1，计划末尾自动少排一节。\n'
            '· 有效期是硬边界：剩余课时排不进有效期内时，把有效期改晚即可重新排课。\n'
            '· 已发生的记录（已上课 / 未上课 / 到点还没处理的课）永远不会被编辑改动——改时间、改频率、重排，都只影响当前时刻之后的计划。',
          ),
          _section(
            context,
            '上课记录与备注',
            '点课程卡片进入「上课记录」，默认显示已上的课，可切换 全部 / 待上 / 未上。\n'
            '顶部概览显示 已上 / 剩余 / 总课时。\n'
            '点课次右侧的笔（或长按卡片）可以写备注，比如「今天表现好」「请假」；「记一节」会自动带上「加课」备注。',
          ),
          _section(
            context,
            '分享课时图',
            '上课记录页右上角的分享按钮，或课程卡片「⋯」里的「分享课时图」：\n'
            '生成一张进度卡片图（课程名、学员、已上、剩余、有效期），直接发给家长或机构。'
            '图上刻意不显示「还剩多少节没上」——未上的课会顺延，在有效期内上完就行。',
          ),
          _section(
            context,
            '上课提醒与提醒诊断',
            '每节课会在「上课时间 − 提前量」时推送通知，提前量在设置里选 30 分钟 / 1 小时 / 2 小时。\n'
            '有课到点没记「已上/未上」时：今日页顶部出现提醒条，并且每天上午 9 点发一条催办通知，处理完自动停。\n'
            '收不到提醒？打开 设置 → 课程提醒 → 提醒诊断：\n'
            '· 通知权限 / 闹钟和提醒权限 两行必须都是「正常」；\n'
            '· 「待触发提醒」数量应与未来 3 天内未上的课次一致；\n'
            '· 都正常还不响，多半是手机系统杀后台——在系统设置里允许趣课「自启动」、电池策略选「无限制」。',
          ),
          _section(
            context,
            '外观：强调色 / 桌面图标 / 悬浮导航',
            '· 强调色：只染按钮、选中态等通用控件，不会改变课程颜色和成员色标。\n'
            '· 桌面图标：提供经典、拼图、笑脸、书本、星火五款，点一下即换、无需重装；个别桌面要退回桌面或等几秒才刷新。\n'
            '· 悬浮导航：开启后底部导航条悬浮在内容之上，关闭为贴底标准导航。',
          ),
          _section(
            context,
            '备份与恢复',
            '设置 → 备份：填 WebDAV 地址（坚果云等均可）后可手动备份或开启自动同步。\n'
            '换手机时在新设备上登录同一 WebDAV 恢复即可。课程删除后无法撤销，重要数据建议开自动备份。',
          ),
          _section(
            context,
            '常见问题',
            'Q：为什么计划节数和总课时对不上？\n'
            'A：旧版本是按频率铺满有效期，v24 起只排总课时那么多节；升级后首次启动会自动把已有课程修剪成新规则，无需手动处理。\n\n'
            'Q：今天有课没上，怎么办？\n'
            'A：点那节课的「未上课」即可，后面会自动延出一节；不点的话它会一直显示待上课，并每天上午催你处理。\n\n'
            'Q：改了上课频率（比如周五周六改成周六周日），之前的记录会变吗？\n'
            'A：不会。已上、未上、以及已到点的记录全部冻结，重排只动当前时间之后的计划。',
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
