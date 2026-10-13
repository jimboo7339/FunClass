import 'package:flutter/material.dart';

import '../../core/widgets/glass_widgets.dart';
import '../../data/models/schedule_rule.dart';

/// 频率规则编辑器（可增删多条规则）
/// 每条规则：星期几 + 开始时间 + 结束时间
/// 来自Trae
class ScheduleRuleEditor extends StatefulWidget {
  const ScheduleRuleEditor({
    super.key,
    required this.initialRules,
    required this.onChanged,
  });

  /// 初始规则列表
  final List<ScheduleRule> initialRules;

  /// 规则变化回调
  final ValueChanged<List<ScheduleRule>> onChanged;

  @override
  State<ScheduleRuleEditor> createState() => _ScheduleRuleEditorState();
}

class _ScheduleRuleEditorState extends State<ScheduleRuleEditor> {
  late List<ScheduleRule> _rules;

  static const List<String> _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _rules = List.from(widget.initialRules);
  }

  /// 添加一条空规则（默认周一 09:00-10:30）
  void _addRule() {
    setState(() {
      _rules.add(const ScheduleRule(
        weekday: 1,
        startTime: '09:00',
        endTime: '10:30',
      ));
    });
    widget.onChanged(List.from(_rules));
  }

  /// 删除指定索引的规则
  void _removeRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
    widget.onChanged(List.from(_rules));
  }

  /// 更新某条规则
  void _updateRule(int index, ScheduleRule rule) {
    setState(() {
      _rules[index] = rule;
    });
    widget.onChanged(List.from(_rules));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '暂无频率规则，点击下方按钮添加',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ..._rules.asMap().entries.map((entry) {
          final index = entry.key;
          final rule = entry.value;
          return GlassCard(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '星期',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(7, (i) {
                                final w = i + 1;
                                final selected = rule.weekday == w;
                                return GlassChip(
                                  label: '周${_weekdays[i]}',
                                  selected: selected,
                                  onTap: () =>
                                      _updateRule(index, rule.copyWith(weekday: w)),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _removeRule(index),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TimePickerField(
                          label: '开始时间',
                          time: rule.startTime,
                          onChanged: (t) =>
                              _updateRule(index, rule.copyWith(startTime: t)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TimePickerField(
                          label: '结束时间',
                          time: rule.endTime,
                          onChanged: (t) =>
                              _updateRule(index, rule.copyWith(endTime: t)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addRule,
          icon: const Icon(Icons.add),
          label: const Text('添加频率规则'),
        ),
      ],
    );
  }
}

/// 时间选择字段（点击弹出 TimePicker）
/// 来自Trae
class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  final String label;
  final String time;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
        );
        if (picked != null) {
          onChanged(
            '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}',
          );
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(time),
            const Icon(Icons.access_time, size: 18),
          ],
        ),
      ),
    );
  }
}
