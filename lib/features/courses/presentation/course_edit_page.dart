import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/page_shell.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/schedule_rule.dart';
import '../../members/providers/member_providers.dart';
import '../providers/course_providers.dart';
import '../../../shared/widgets/color_picker_grid.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';
import '../../../shared/widgets/schedule_rule_editor.dart';
import '../../../shared/widgets/valid_period_selector.dart';

/// 课程新增/编辑页
/// 保存时自动按频率规则生成课次（仅新增时）
/// 来自Trae
class CourseEditPage extends ConsumerStatefulWidget {
  const CourseEditPage({super.key, this.courseId});

  final int? courseId;

  @override
  ConsumerState<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends ConsumerState<CourseEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _lessonsController = TextEditingController();
  final _noteController = TextEditingController();

  int? _memberId;
  String? _memberName;
  String? _memberColor;
  String? _colorTag; // null 表示继承成员颜色
  DateTime? _validFrom;
  DateTime? _validTo;
  List<ScheduleRule> _schedules = [];
  bool _loading = true;
  bool _dirty = false; // 是否发生未保存修改，用于离开拦截——来自Trae
  Course? _existing;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    // 先加载成员列表（新增和编辑都需要默认选中第一个成员）
    final members = await ref.read(membersProvider.future);

    if (widget.courseId != null) {
      _existing = await ref.read(courseProvider(widget.courseId!).future);
      if (_existing != null) {
        _nameController.text = _existing!.name;
        _amountController.text = _existing!.totalAmount.toString();
        _lessonsController.text = _existing!.totalLessons.toString();
        _noteController.text = _existing!.note ?? '';
        _memberId = _existing!.memberId;
        _colorTag = _existing!.colorTag;
        _validFrom = _existing!.validFrom;
        _validTo = _existing!.validTo;
        _schedules = List.from(_existing!.schedules);
      }
    }

    // 设置成员信息（编辑时回填，新增时默认第一个）
    final targetId = _memberId ?? members.firstOrNull?.id;
    final m = members.where((x) => x.id == targetId).firstOrNull;
    if (m != null) {
      _memberId = m.id;
      _memberName = m.name;
      _memberColor = m.colorTag;
    }

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _lessonsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);

    return EditPageShell(
      title: widget.courseId == null ? '新增课程' : '编辑课程',
      saveLabel: widget.courseId == null ? '创建课程' : '保存修改',
      onSave: _save,
      onPopInvoked: _confirmDirtyExit,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 成员选择（现代化：点击弹出底部选择面板）
                  membersAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('成员加载失败: $e'),
                    data: (members) {
                      if (members.isEmpty) {
                        return const Text('请先在「成员」页面中添加成员');
                      }
                      return _MemberSelector(
                        selectedId: _memberId,
                        selectedName: _memberName,
                        selectedColor: _memberColor,
                        members: members,
                        onSelected: (m) {
                          setState(() {
                            _dirty = true;
                            _memberId = m.id;
                            _memberName = m.name;
                            _memberColor = m.colorTag;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '课程名称'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入课程名称' : null,
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: '总金额（元）',
                            prefixText: '¥',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return '请输入有效金额';
                            return null;
                          },
                          onChanged: (_) => setState(() => _dirty = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lessonsController,
                          decoration: const InputDecoration(labelText: '总课时'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return '请输入有效课时';
                            return null;
                          },
                          onChanged: (_) => setState(() => _dirty = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ValidPeriodSelector(
                    validFrom: _validFrom,
                    validTo: _validTo,
                    onFromChanged: (d) => setState(() {
                      _validFrom = d;
                      _dirty = true;
                    }),
                    onToChanged: (d) => setState(() {
                      _validTo = d;
                      _dirty = true;
                    }),
                  ),
                  const SizedBox(height: 24),
                  const Text('每周频率规则',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ScheduleRuleEditor(
                    initialRules: _schedules,
                    onChanged: (rules) {
                      _schedules = rules;
                      _dirty = true;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('课程颜色（留空则继承成员颜色）',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ColorPickerGrid(
                    selectedColor: _colorTag ?? '',
                    onColorSelected: (hex) => setState(() {
                      _colorTag = hex;
                      _dirty = true;
                    }),
                  ),
                  const SizedBox(height: 8),
                  if (_colorTag != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _colorTag = null;
                          _dirty = true;
                        }),
                        child: const Text('清除颜色（继承成员）'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: '备注（选填）'),
                    maxLines: 2,
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
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

  /// 保存课程
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_memberId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择成员')));
      return;
    }
    if (_validFrom == null || _validTo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择有效期')));
      return;
    }
    if (_validTo!.isBefore(_validFrom!)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('有效期止不能早于起')));
      return;
    }
    if (_schedules.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请至少添加一条频率规则')));
      return;
    }

    final companion = CoursesCompanion(
      memberId: Value(_memberId!),
      name: Value(_nameController.text.trim()),
      colorTag: Value(_colorTag),
      totalAmount: Value(double.parse(_amountController.text)),
      totalLessons: Value(int.parse(_lessonsController.text)),
      validFrom: Value(_validFrom!),
      validTo: Value(_validTo!),
      schedules: Value(_schedules),
      note: Value(_noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim()),
    );

    try {
      if (widget.courseId == null) {
        await ref.read(courseActionsProvider).insertWithLessons(companion);
        _finishSaved('创建成功');
      } else {
        final actions = ref.read(courseActionsProvider);
        final updateCompanion = companion.copyWith(id: Value(widget.courseId!));

        // 只有"会改变课程排布"的字段变了才需要重排课次。
        // 只改名字 / 颜色 / 金额这些时不动课次，保留已有课次 id
        // （提醒排程也在复用 lesson.id 当通知 id）。——来自Trae
        final existing = _existing;
        final scheduleChanged = existing == null
            ? true
            : !existing.validFrom.isAtSameMomentAs(_validFrom!) ||
                !existing.validTo.isAtSameMomentAs(_validTo!) ||
                ScheduleRule.listToJson(existing.schedules) !=
                    ScheduleRule.listToJson(_schedules);

        if (!scheduleChanged) {
          await actions.update(updateCompanion);
          _finishSaved('保存成功');
        } else {
          final affected = await actions.countReschedulable(widget.courseId!);
          if (affected > 0 && mounted) {
            final ok = await showConfirmSheet(
              context,
              title: '重新排课？',
              message: '课程时间变了。已上过的课保持不变，'
                  '\n未上的 $affected 节课会按新计划重排。',
              confirmLabel: '重排',
            );
            if (!ok || !mounted) return; // 取消则留在编辑页
          }
          final result = await actions.reschedule(updateCompanion);
          _finishSaved(
            result.removed > 0 || result.added > 0
                ? '已保存（删除 ${result.removed} 节、新增 ${result.added} 节）'
                : '保存成功',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  /// 保存成功后的统一收尾：解除离开拦截、提示、退出编辑页
  void _finishSaved(String message) {
    _dirty = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.pop(context);
  }
}

/// 现代化成员选择器
/// 点击显示选中的成员（头像+名称），点击弹出底部面板选择 来自Trae
class _MemberSelector extends StatelessWidget {
  const _MemberSelector({
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
    final color = selectedColor != null
        ? ColorHex.fromHex(selectedColor!)
        : Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '所属成员',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
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
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedName ?? '请选择成员',
                style: TextStyle(
                  color: selectedName == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出底部成员选择面板
  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽手柄
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      const Text(
                        '选择成员',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: members.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final m = members[index];
                      final mColor = ColorHex.fromHex(m.colorTag);
                      final isSelected = m.id == selectedId;
                      return InkWell(
                        onTap: () {
                          onSelected(m);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? mColor.withValues(alpha: 0.1)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? mColor.withValues(alpha: 0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: mColor,
                                child: Text(
                                  m.name.characters.first,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      m.type.label,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle,
                                    color: mColor, size: 22),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

