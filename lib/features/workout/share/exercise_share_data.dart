import 'package:my_gym_bro/core/database/daos/session_dao.dart'
    show ExercisePersonalRecords;
import 'package:my_gym_bro/features/exercises/lift_rank/lift_rank_providers.dart'
    show LiftRank;

/// One session's volume for the trend sparkline (kg, canonical unit).
class ExerciseTrendPoint {
  const ExerciseTrendPoint({required this.date, required this.volumeKg});

  final DateTime date;
  final double volumeKg;
}

/// Immutable snapshot of one exercise's all-time stats, shaped for rendering
/// the exercise share card (the exercise-detail counterpart of
/// `ShareCardData`). Weights are canonical kg — templates convert at render
/// time via `formatWeight` + `weightUnitProvider`, never here.
class ExerciseShareData {
  const ExerciseShareData({
    required this.exerciseName,
    this.muscleGroup,
    this.maxWeightKg,
    this.best1RmKg,
    this.bestSetVolumeKg,
    this.bestSessionVolumeKg,
    this.rankBand,
    this.trend = const [],
    this.sessionCount = 0,
    this.date,
  });

  /// Builds the snapshot from what the exercise detail screen already loads:
  /// its PR row, its (nullable) lift rank, and the volume-per-session history
  /// feeding the trend chart. History may arrive in any order; the sparkline
  /// keeps the [maxTrendPoints] most recent sessions, oldest → newest.
  factory ExerciseShareData.fromStats({
    required String exerciseName,
    String? muscleGroup,
    ExercisePersonalRecords? records,
    LiftRank? rank,
    List<({DateTime date, double volume})> volumeHistory = const [],
    DateTime? date,
  }) {
    final points = [
      for (final p in volumeHistory)
        ExerciseTrendPoint(date: p.date, volumeKg: p.volume),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = points.length <= maxTrendPoints
        ? points
        : points.sublist(points.length - maxTrendPoints);
    return ExerciseShareData(
      exerciseName: exerciseName,
      muscleGroup: muscleGroup,
      maxWeightKg: records?.maxWeight,
      best1RmKg: records?.best1rm,
      bestSetVolumeKg: records?.bestSetVolume,
      bestSessionVolumeKg: records?.bestSessionVolume,
      rankBand: rank?.rank.band,
      trend: trimmed,
      sessionCount: points.length,
      date: date,
    );
  }

  /// Sparkline cap — enough to show a shape without turning into noise.
  static const maxTrendPoints = 16;

  final String exerciseName;

  /// Display muscle group (e.g. "Chest"); null hides the eyebrow label.
  final String? muscleGroup;

  // All-time PRs (kg). Null = never logged; cells render an em dash.
  final double? maxWeightKg;
  final double? best1RmKg;
  final double? bestSetVolumeKg;
  final double? bestSessionVolumeKg;

  /// All-time lift-rank band (feed to `Rank.fromBand`), or null when the
  /// exercise isn't a rankable classic / has no logged e1RM — the card hides
  /// the rank hero on null.
  final int? rankBand;

  /// Recent per-session volumes, oldest → newest, at most [maxTrendPoints].
  /// The sparkline section is hidden when fewer than 2 points exist.
  final List<ExerciseTrendPoint> trend;

  /// Total sessions in the source history (before trimming to the trend cap).
  final int sessionCount;

  /// Snapshot date — the masthead date line. Null falls back to "now".
  final DateTime? date;
}
