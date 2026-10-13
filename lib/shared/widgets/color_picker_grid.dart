import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';

/// 紧凑的颜色选择器（小圆形，横向流式排列）
/// 用于成员/课程的颜色标签选择——来自Trae
class ColorPickerGrid extends StatelessWidget {
  const ColorPickerGrid({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  static const double _size = 28;
  static const double _spacing = 10;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _spacing,
      runSpacing: _spacing,
      children: AppColors.memberPalette.map((color) {
        final hex = color.toHex();
        final isSelected = hex == selectedColor;
        return GestureDetector(
          onTap: () => onColorSelected(hex),
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
