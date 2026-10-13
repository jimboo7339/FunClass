import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_topics.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/adaptive_card.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/page_shell.dart';
import '../../../core/widgets/settings_gear_button.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../shared/widgets/app_scroll_view.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/help_button.dart';
import '../providers/member_providers.dart';
import 'member_edit_page.dart';

/// 成员管理列表页
class MemberListPage extends ConsumerWidget {
  const MemberListPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(membersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);

    return PageShell(
      title: '成员',
      actions: [
        const HelpButton(topic: HelpTopics.members),
        buildSettingsGear(context),
      ],
      floatingActionButton: GlassFab(
        isGlass: ref.watch(appThemeProvider).isLiquidGlass,
        heroTag: 'fab-member',
        onPressed: () => _openEdit(context),
        child: const Icon(Icons.person_add),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (members) {
          if (members.isEmpty) {
            return EmptyStateView(
              icon: Icons.people_outline,
              title: '还没有成员',
              subtitle: '添加孩子或家长，开始管理课程',
              actionLabel: '添加成员',
              onAction: () => _openEdit(context),
            );
          }

          final active = members.where((m) => !m.archived).toList();
          final archived = members.where((m) => m.archived).toList();

          return AppScrollView(
            onRefresh: () => _refresh(ref),
            children: [
              ...active.map((m) => _MemberCard(member: m)),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 16),
                // 已归档折叠块：原本直接贴在渐变背景上，玻璃模式下像一块没做完的半成品。
                // 套一层卡片，让它和上面的成员卡是同一套卡片语言——来自Trae
                GlassCard(
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      title: Text(
                        '已归档 (${archived.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      children:
                          archived.map((m) => _MemberCard(member: m)).toList(),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openEdit(BuildContext context, {int? memberId}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemberEditPage(memberId: memberId)),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ColorHex.fromHex(member.colorTag);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('member-${member.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          HapticFeedback.mediumImpact();
          if (direction == DismissDirection.startToEnd) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MemberEditPage(memberId: member.id),
              ),
            );
            return false;
          }
          final ok = await showConfirmSheet(
            context,
            title: '确认删除',
            message: '删除成员将同时删除其课程和课次，确定吗？',
            confirmLabel: '删除',
            destructive: true,
          );
          if (ok) {
            await ref.read(memberActionsProvider).delete(member.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已删除成员「${member.name}」'),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.edit_outlined, color: scheme.primary),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.red),
        ),
        child: AdaptiveCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MemberEditPage(memberId: member.id),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Text(
                  member.name.characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration:
                            member.archived ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      member.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                tooltip: member.archived ? '取消归档' : '归档',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(memberActionsProvider)
                      .toggleArchived(member.id, !member.archived);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
