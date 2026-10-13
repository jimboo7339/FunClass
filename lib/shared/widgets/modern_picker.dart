import 'package:flutter/material.dart';

/// 通用底部选择面板（适合移动端单选列表）
/// 来自Trae
class ModernPickerSheet<T> extends StatelessWidget {
  const ModernPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.allowNull = false,
    this.nullLabel = '无',
    this.itemLabel,
    this.itemBuilder,
    this.searchFilter,
    this.secondaryLabel,
    this.leadingWidget,
  });

  final String title;
  final List<T> items;
  final T? selectedValue;
  final ValueChanged<T?> onChanged;
  final bool allowNull;
  final String nullLabel;
  final String? Function(T item)? itemLabel;
  final Widget? Function(T item)? itemBuilder;
  final bool Function(String query, T item)? searchFilter;
  final String? Function(T item)? secondaryLabel;
  final Widget? Function(T item)? leadingWidget;

  @override
  Widget build(BuildContext context) {
    final effectiveItems = allowNull && !items.any((x) => x == null)
        ? <T?>[null as T, ...items]
        : items;

    return BottomSheet(
      showDragHandle: false, // 隐藏默认 handle，避免双层——来自Trae
      enableDrag: true,
      onClosing: () {},
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final controller = TextEditingController();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  if (searchFilter != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: '搜索',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                    ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: effectiveItems.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = effectiveItems[index];
                        final bool isNull = item == null && allowNull;
                        final bool selected =
                            (item == null && selectedValue == null) ||
                                item == selectedValue;

                        final Widget? leading = item == null
                            ? null
                            : leadingWidget?.call(item as T);
                        final Widget? trailing = item == null
                            ? null
                            : itemBuilder?.call(item as T);
                        final String label = item == null && allowNull
                            ? nullLabel
                            : (item == null ? '' : (itemLabel?.call(item as T) ?? '$item'));
                        final String? secondary = item == null
                            ? null
                            : secondaryLabel?.call(item as T);

                        final bool matchesSearch = searchFilter == null ||
                            controller.text.isEmpty ||
                            (item != null && searchFilter!(controller.text, item as T));

                        if (!matchesSearch) {
                          return const SizedBox.shrink();
                        }

                        return _PickerTile(
                          label: label,
                          secondaryLabel: secondary,
                          selected: selected,
                          leading: leading,
                          trailing: trailing,
                          onTap: () {
                            onChanged(isNull ? null : (item as T));
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.trailing,
    this.secondaryLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (secondaryLabel != null)
                    Text(
                      secondaryLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
            if (selected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
