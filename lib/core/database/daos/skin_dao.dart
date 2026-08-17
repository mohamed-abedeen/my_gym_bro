import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'skin_dao.g.dart';

/// Data access for the skin-ownership offline mirror. Pure read-through
/// cache of the server's `skin_ownership` table: no sync queue; a refresh
/// replaces the whole set, a verified purchase upserts its rows.
@DriftAccessor(tables: [SkinOwnerships])
class SkinDao extends DatabaseAccessor<AppDatabase> with _$SkinDaoMixin {
  SkinDao(super.db);

  /// Every owned skin id (earned + purchased), as a stream for the gallery.
  Stream<Set<String>> watchOwnedIds() => select(skinOwnerships)
      .watch()
      .map((rows) => {for (final r in rows) r.skinId});

  Future<Set<String>> getOwnedIds() async {
    final rows = await select(skinOwnerships).get();
    return {for (final r in rows) r.skinId};
  }

  /// Replace the whole mirror with a fresh server snapshot.
  Future<void> replaceAll(List<SkinOwnershipsCompanion> rows) async {
    await transaction(() async {
      await delete(skinOwnerships).go();
      for (final row in rows) {
        await into(skinOwnerships).insert(row);
      }
    });
  }

  /// Wipe the mirror — account deletion, so the next sign-up on this device
  /// doesn't inherit the previous owner's grants.
  Future<int> clearAll() => delete(skinOwnerships).go();

  /// Upsert individual grants (post-purchase fast path).
  Future<void> upsertAll(List<SkinOwnershipsCompanion> rows) async {
    await transaction(() async {
      for (final row in rows) {
        await into(skinOwnerships).insert(
          row,
          onConflict: DoUpdate((_) => row, target: [skinOwnerships.skinId]),
        );
      }
    });
  }
}
