import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/page_shell.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../providers/member_providers.dart';
import '../../../shared/widgets/color_picker_grid.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';

/// 成员新增/编辑页
/// 来自Trae
class MemberEditPage extends ConsumerStatefulWidget {
  const MemberEditPage({super.key, this.memberId});

  /// 编辑时传入成员 id，新增时为 null
  final int? memberId;

  @override
  ConsumerState<MemberEditPage> createState() => _MemberEditPageState();
}

class _MemberEditPageState extends ConsumerState<MemberEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  MemberType _type = MemberType.child;
  String _colorTag = AppColors.memberPalette.first.toHex();
  bool _archived = false;
  bool _loading = true;
  bool _dirty = false; // 是否发生未保存修改，用于离开拦截——来自Trae
  Member? _existing;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.memberId != null) {
      _existing = await ref.read(memberProvider(widget.memberId!).future);
      if (_existing != null) {
        _nameController.text = _existing!.name;
        _noteController.text = _existing!.note ?? '';
        _type = _existing!.type;
        _colorTag = _existing!.colorTag;
        _archived = _existing!.archived;
      }
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EditPageShell(
      title: widget.memberId == null ? '新增成员' : '编辑成员',
      saveLabel: '保存',
      onSave: _save,
      onPopInvoked: _confirmDirtyExit,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '姓名'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入姓名' : null,
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 16),
                  GlassSegmented<MemberType>(
                    items: [
                      for (final t in MemberType.values)
                        GlassSegmentedItem<MemberType>(
                          value: t,
                          label: t.label,
                        ),
                    ],
                    value: _type,
                    onChanged: (v) => setState(() {
                      _type = v;
                      _dirty = true;
                    }),
                  ),
                  const SizedBox(height: 24),
                  const Text('颜色标签', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ColorPickerGrid(
                    selectedColor: _colorTag,
                    onColorSelected: (hex) => setState(() {
                      _colorTag = hex;
                      _dirty = true;
                    }),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: '备注（选填）'),
                    maxLines: 2,
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  // 仅编辑模式显示归档开关——来自Trae
                  if (widget.memberId != null) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('归档'),
                      subtitle: const Text('归档后归入「已归档」分组，不再出现在默认列表'),
                      value: _archived,
                      onChanged: (v) => setState(() {
                        _archived = v;
                        _dirty = true;
                      }),
                    ),
                    // 成员删除入口：编辑页底部，红色危险区域——来自Trae
                    const SizedBox(height: 16),
                    GlassCard(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error),
                        title: Text('删除成员',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        subtitle: Text('将同时删除该成员的所有课程和课次'),
                        onTap: _deleteMember,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  /// 删除成员（带确认）——来自Trae
  Future<void> _deleteMember() async {
    final ok = await showConfirmSheet(
      context,
      title: '确认删除成员？',
      message:
          '删除「${_existing?.name ?? ''}」将同时删除其全部课程和课次，无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (ok != true || !mounted) return;
    await ref.read(memberActionsProvider).delete(widget.memberId!);
    if (!mounted) return;
    // 删除后返回上一级（列表页）
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除成员')),
    );
    Navigator.of(context).pop();
  }

  /// 未保存离开拦截：有改动时弹确认 Sheet，放弃才允许离开——来自Trae
  Future<bool> _confirmDirtyExit() async {
    if (!_dirty) return true;
    final ok = await showConfirmSheet(
      context,
      title: '放弃修改？',
      message: '当前更改尚未保存，确定要离开吗？',
      confirmLabel: '放弃',
      destructive: true,
    );
    return ok == true;
  }

  /// 保存
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final companion = MembersCompanion(
      name: Value(_nameController.text.trim()),
      type: Value(_type),
      colorTag: Value(_colorTag),
      note: Value(_noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim()),
      archived: Value(_archived),
    );
    try {
      if (widget.memberId == null) {
        await ref.read(memberActionsProvider).insert(companion);
      } else {
        await ref
            .read(memberActionsProvider)
            .update(companion.copyWith(id: Value(widget.memberId!)));
      }
      if (mounted) {
        _dirty = false; // 已保存，解除离开拦截
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
}
