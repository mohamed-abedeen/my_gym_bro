import 'package:my_gym_bro/core/database/app_database.dart';

enum ExerciseSort { mostUsed, favorites, alphabetical }

/// Sorts [exercises] according to [sort] and returns a new list.
///
/// This function is intentionally decoupled from Drift and any other data
/// source. Tie-breaking always falls back to alphabetical order.
List<Exercise> sortExercises(List<Exercise> exercises, ExerciseSort sort) {
  final list = [...exercises];
  switch (sort) {
    case ExerciseSort.mostUsed:
      // Up to 25 "recents" — exercises with usage > 0 sorted by frequency
      // DESC — pinned at the top.  Everything else is sorted A-Z below them.
      final used = list.where((e) => e.usageCount > 0).toList()
        ..sort((a, b) {
          final byUsage = b.usageCount.compareTo(a.usageCount);
          return byUsage != 0 ? byUsage : a.name.compareTo(b.name);
        });
      final recents = used.take(25).toList();
      final rest = [...used.skip(25), ...list.where((e) => e.usageCount == 0)]
        ..sort((a, b) => a.name.compareTo(b.name));
      return [...recents, ...rest];

    case ExerciseSort.favorites:
      list.sort((a, b) {
        if (a.isFavorite == b.isFavorite) return a.name.compareTo(b.name);
        return a.isFavorite ? -1 : 1;
      });

    case ExerciseSort.alphabetical:
      list.sort((a, b) => a.name.compareTo(b.name));
  }
  return list;
}
