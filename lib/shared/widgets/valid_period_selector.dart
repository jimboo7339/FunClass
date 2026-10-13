import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/glass_widgets.dart';

/// 有效期选择器
/// - validFrom：必选具体日期
/// - validTo：可选快捷（1年/2年/3年/永久）或自定义具体日期
/// 默认均为空，由用户选择
/// 来自Trae
class ValidPeriodSelector extends StatefulWidget {
  const ValidPeriodSelector({
    super.key,
    required this.validFrom,
    required this.validTo,
    required this.onFromChanged,
    required this.onToChanged,
  });

  final DateTime? validFrom;
  final DateTime? validTo;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;

  @override
  State<ValidPeriodSelector> createState() => _ValidPeriodSelectorState();
}

class _ValidPeriodSelectorState extends State<ValidPeriodSelector> {
  /// 当前选中的快捷项索引（null 表示自定义/未选）
  int? _quickIndex;

  /// 快捷选项：标签 + 天数
  static const List<_QuickOption> _quickOptions = [
    _QuickOption(label: '1年', days: 365),
    _QuickOption(label: '2年', days: 365 * 2),
    _QuickOption(label: '3年', days: 365 * 3),
    _QuickOption(label: '永久', days: -1), // -1 表示永久
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 有效期起
        _DateField(
          label: '有效期起',
          date: widget.validFrom,
          onTap: () async {
            final picked = await _pickDate(widget.validFrom ?? DateTime.now());
            if (picked != null) {
              widget.onFromChanged(picked);
              // 若已选快捷项，重新计算 validTo
              if (_quickIndex != null && widget.validFrom != null) {
                _applyQuickOption(_quickIndex!);
              }
            }
          },
        ),
        const SizedBox(height: 12),
        // 快捷选项
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_quickOptions.length, (index) {
            return GlassChip(
              label: _quickOptions[index].label,
              selected: _quickIndex == index,
              onTap: widget.validFrom == null
                  ? null
                  : () {
                      if (_quickIndex == index) {
                        setState(() => _quickIndex = null);
                      } else {
                        setState(() => _quickIndex = index);
                        _applyQuickOption(index);
                      }
                    },
            );
          }),
        ),
        const SizedBox(height: 12),
        // 有效期止（自定义或显示快捷结果）
        _DateField(
          label: '有效期止',
          date: widget.validTo,
          onTap: () async {
            final initial = widget.validTo != null &&
                    !isPermanentValidTo(widget.validTo!)
                ? widget.validTo!
                : (widget.validFrom ?? DateTime.now());
            final picked = await _pickDate(initial);
            if (picked != null) {
              setState(() => _quickIndex = null);
              widget.onToChanged(picked);
            }
          },
          isPermanent: widget.validTo != null &&
              isPermanentValidTo(widget.validTo!),
        ),
      ],
    );
  }

  /// 应用快捷选项计算 validTo
  void _applyQuickOption(int index) {
    if (widget.validFrom == null) return;
    final option = _quickOptions[index];
    if (option.days < 0) {
      widget.onToChanged(AppConstants.permanentDate);
    } else {
      widget.onToChanged(widget.validFrom!.add(Duration(days: option.days)));
    }
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }
}

/// 快捷选项
class _QuickOption {
  const _QuickOption({required this.label, required this.days});
  final String label;
  final int days;
}

/// 日期显示字段
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.isPermanent = false,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool isPermanent;

  @override
  Widget build(BuildContext context) {
    final text = isPermanent
        ? '永久'
        : (date == null ? '请选择' : DateUtilsTool.formatDate(date!));
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: date == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
      ),
    );
  }
}
