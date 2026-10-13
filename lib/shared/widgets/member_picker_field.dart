import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import 'modern_picker.dart';

/// 成员选择字段（点击弹出 ModernPickerSheet）
class MemberPickerField extends StatelessWidget {
  const MemberPickerField({
    super.key,
    required this.selectedId,
    required this.selectedName,
    required this.selectedColor,
    required this.members,
    required this.onSelected,
  });

  final int? selectedId;
  final String? selectedName;
  final String? selectedColor;
  final List<Member> members;
  final ValueChanged<Member> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selectedColor != null
        ? ColorHex.fromHex(selectedColor!)
        : scheme.primary;

    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '所属成员',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          suffixIcon: const Icon(Icons.chevron_right, size: 20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color,
              child: Text(
                selectedName?.characters.first ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedName ?? '请选择成员',
                style: TextStyle(
                  color: selectedName == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ModernPickerSheet<Member>(
        title: '选择成员',
        items: members,
        selectedValue: members.where((m) => m.id == selectedId).firstOrNull,
        itemLabel: (m) => m.name,
        secondaryLabel: (m) => m.type.label,
        leadingWidget: (m) => CircleAvatar(
          radius: 20,
          backgroundColor: ColorHex.fromHex(m.colorTag),
          child: Text(
            m.name.characters.first,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onChanged: (m) {
          if (m != null) onSelected(m);
        },
      ),
    );
  }
}


