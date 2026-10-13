import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// 成员仓库
/// 提供成员的增删改查，归档切换
/// 来自Trae
class MemberRepository {
  MemberRepository(this._db);

  final AppDatabase _db;

  /// 获取所有成员（可选择是否包含归档）
  Future<List<Member>> getAll({bool includeArchived = false}) {
    final query = _db.select(_db.members);
    if (!includeArchived) {
      query.where((m) => m.archived.equals(false));
    }
    query.orderBy([(m) => OrderingTerm.asc(m.createdAt)]);
    return query.get();
  }

  /// 按 id 获取单个成员
  Future<Member?> getById(int id) {
    return (_db.select(_db.members)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
  }

  /// 新增成员，返回新 id
  Future<int> insert(MembersCompanion companion) {
    return _db.into(_db.members).insert(companion);
  }

  /// 更新成员
  Future<bool> updateMember(MembersCompanion companion) {
    return _db.update(_db.members).replace(companion);
  }

  /// 切换归档状态，返回受影响行数
  Future<int> toggleArchived(int id, bool archived) {
    return (_db.update(_db.members)..where((m) => m.id.equals(id)))
        .write(MembersCompanion(archived: Value(archived)));
  }

  /// 删除成员
  Future<int> deleteById(int id) {
    return (_db.delete(_db.members)..where((m) => m.id.equals(id))).go();
  }
}
