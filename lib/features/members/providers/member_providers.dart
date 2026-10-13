import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/providers/backup_auto_sync.dart';
import '../../../data/providers/repository_providers.dart';

/// 成员列表（含归档成员，UI 层分组展示）
final membersProvider = FutureProvider.autoDispose<List<Member>>((ref) {
  return ref.watch(memberRepositoryProvider).getAll(includeArchived: true);
});

/// 是否显示归档成员
final showArchivedMembersProvider = StateProvider<bool>((ref) => false);

/// 单个成员
final memberProvider = FutureProvider.autoDispose.family<Member?, int>((ref, id) {
  return ref.watch(memberRepositoryProvider).getById(id);
});

/// 成员操作（新增/更新/归档/删除）
/// 来自Trae
class MemberActions {
  MemberActions(this.ref);
  final Ref ref;

  Future<int> insert(MembersCompanion companion) async {
    final id = await ref.read(memberRepositoryProvider).insert(companion);
    ref.invalidate(membersProvider);
    ref.read(backupAutoSyncProvider).trigger();
    return id;
  }

  Future<void> update(MembersCompanion companion) async {
    await ref.read(memberRepositoryProvider).updateMember(companion);
    ref.invalidate(membersProvider);
    ref.read(backupAutoSyncProvider).trigger();
  }

  Future<void> toggleArchived(int id, bool archived) async {
    await ref.read(memberRepositoryProvider).toggleArchived(id, archived);
    ref.invalidate(membersProvider);
    ref.read(backupAutoSyncProvider).trigger();
  }

  Future<void> delete(int id) async {
    await ref.read(memberRepositoryProvider).deleteById(id);
    ref.invalidate(membersProvider);
    ref.read(backupAutoSyncProvider).trigger();
  }
}

/// 成员操作 Provider
final memberActionsProvider = Provider<MemberActions>((ref) => MemberActions(ref));
