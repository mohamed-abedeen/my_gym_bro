import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/exercise_dao.dart';
import '../../../core/database/daos/schedule_dao.dart';
import '../../../core/database/daos/session_dao.dart';
import '../../../core/database/daos/sync_queue_dao.dart';
import '../../../core/security/input_sanitiser.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/providers/providers.dart';
import '../workout_providers.dart';
import 'rest_timer_service.dart';

// ── Models ────────────────────────────────────

class ActiveExercise {
  final int sessionExerciseId;
  final String exerciseId;
  final String name;
  final String? gifUrl;
  final List<ActiveSet> sets;

  ActiveExercise({
    required this.sessionExerciseId,
    required this.exerciseId,
    required this.name,
    this.gifUrl,
    List<ActiveSet>? sets,
  }) : sets = sets ?? [];

  ActiveExercise copyWith({List<ActiveSet>? sets}) => ActiveExercise(
        sessionExerciseId: sessionExerciseId,
        exerciseId: exerciseId,
        name: name,
        gifUrl: gifUrl,
        sets: sets ?? this.sets,
      );
}

class ActiveSet {
  final int localId;
  final int setIndex;
  final double? weight;
  final int? reps;
  final bool isWarmup;
  final bool isDropset;
  final bool isCompleted;

  const ActiveSet({
    required this.localId,
    required this.setIndex,
    this.weight,
    this.reps,
    this.isWarmup = false,
    this.isDropset = false,
    this.isCompleted = false,
  });

  ActiveSet copyWith({
    double? weight,
    int? reps,
    bool? isWarmup,
    bool? isDropset,
    bool? isCompleted,
  }) =>
      ActiveSet(
        localId: localId,
        setIndex: setIndex,
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        isWarmup: isWarmup ?? this.isWarmup,
        isDropset: isDropset ?? this.isDropset,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

class ActiveSessionState {
  final int? sessionId;
  final List<ActiveExercise> exercises;
  final int currentExerciseIndex;
  final DateTime? startedAt;
  final bool showRestTimer;
  final bool isFinishing;

  const ActiveSessionState({
    this.sessionId,
    this.exercises = const [],
    this.currentExerciseIndex = 0,
    this.startedAt,
    this.showRestTimer = false,
    this.isFinishing = false,
  });

  ActiveSessionState copyWith({
    int? sessionId,
    List<ActiveExercise>? exercises,
    int? currentExerciseIndex,
    DateTime? startedAt,
    bool? showRestTimer,
    bool? isFinishing,
  }) =>
      ActiveSessionState(
        sessionId: sessionId ?? this.sessionId,
        exercises: exercises ?? this.exercises,
        currentExerciseIndex:
            currentExerciseIndex ?? this.currentExerciseIndex,
        startedAt: startedAt ?? this.startedAt,
        showRestTimer: showRestTimer ?? this.showRestTimer,
        isFinishing: isFinishing ?? this.isFinishing,
      );

  ActiveExercise? get currentExercise =>
      exercises.isNotEmpty && currentExerciseIndex < exercises.length
          ? exercises[currentExerciseIndex]
          : null;

  int get elapsedSeconds => startedAt != null
      ? DateTime.now().difference(startedAt!).inSeconds
      : 0;

  double get totalVolume {
    double vol = 0;
    for (final ex in exercises) {
      for (final s in ex.sets) {
        if (s.isCompleted && s.weight != null && s.reps != null) {
          vol += s.weight! * s.reps!;
        }
      }
    }
    return vol;
  }

  int get totalCompletedSets {
    int count = 0;
    for (final ex in exercises) {
      count += ex.sets.where((s) => s.isCompleted).length;
    }
    return count;
  }
}

// ── Notifier ──────────────────────────────────

class ActiveSessionNotifier extends StateNotifier<ActiveSessionState> {
  final SessionDao _sessionDao;
  final ExerciseDao _exerciseDao;
  final ScheduleDao _scheduleDao;
  final SyncQueueDao _syncQueueDao;
  final SyncService _syncService;
  final RestTimerService restTimerService = RestTimerService();

  int _defaultRestSeconds;
  String _weightUnit;

  ActiveSessionNotifier({
    required SessionDao sessionDao,
    required ExerciseDao exerciseDao,
    required ScheduleDao scheduleDao,
    required SyncQueueDao syncQueueDao,
    required SyncService syncService,
    int defaultRestSeconds = 90,
    String weightUnit = 'kg',
  })  : _sessionDao = sessionDao,
        _exerciseDao = exerciseDao,
        _scheduleDao = scheduleDao,
        _syncQueueDao = syncQueueDao,
        _syncService = syncService,
        _defaultRestSeconds = defaultRestSeconds,
        _weightUnit = weightUnit,
        super(const ActiveSessionState());

  /// Start a new workout session, optionally pre-loading exercises from a
  /// schedule day.
  Future<void> startSession({int? scheduleDayId}) async {
    final now = DateTime.now();
    final id = await _sessionDao.createSession(SessionsCompanion(
      startedAt: Value(now),
      createdAt: Value(now),
    ));

    state = state.copyWith(
      sessionId: id,
      startedAt: now,
      exercises: [],
    );

    // If a schedule day was provided, load its exercises into the session.
    if (scheduleDayId != null) {
      await _loadScheduleExercises(scheduleDayId);
    }
  }

  /// Load all exercises from a schedule day into the active session.
  Future<void> _loadScheduleExercises(int scheduleDayId) async {
    if (state.sessionId == null) return;

    final scheduledExercises =
        await _scheduleDao.getExercises(scheduleDayId);

    // Sort by orderIndex (should already be sorted from DAO)
    scheduledExercises.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    for (final scheduled in scheduledExercises) {
      final exercise =
          await _exerciseDao.findByExerciseId(scheduled.exerciseId);
      if (exercise == null) continue;

      final orderIndex = state.exercises.length;
      final seId = await _sessionDao.addSessionExercise(
        SessionExercisesCompanion(
          sessionId: Value(state.sessionId!),
          exerciseId: Value(scheduled.exerciseId),
          orderIndex: Value(orderIndex),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Create sets based on the scheduled target sets and reps
      final sets = <ActiveSet>[];
      for (var s = 0; s < scheduled.targetSets; s++) {
        final setId = await _sessionDao.addSet(WorkoutSetsCompanion(
          sessionExerciseId: Value(seId),
          setIndex: Value(s),
          reps: Value(scheduled.targetReps),
          createdAt: Value(DateTime.now()),
        ));
        sets.add(ActiveSet(
          localId: setId,
          setIndex: s,
          reps: scheduled.targetReps,
        ));
      }

      final activeExercise = ActiveExercise(
        sessionExerciseId: seId,
        exerciseId: scheduled.exerciseId,
        name: exercise.name,
        gifUrl: exercise.gifUrl,
        sets: sets,
      );

      state = state.copyWith(
        exercises: [...state.exercises, activeExercise],
      );
    }

    // Select the first exercise
    if (state.exercises.isNotEmpty) {
      state = state.copyWith(currentExerciseIndex: 0);
    }
  }

  /// Add an exercise by its exerciseId string.
  Future<void> addExercise(String exerciseId) async {
    final exercise = await _exerciseDao.findByExerciseId(exerciseId);
    if (exercise == null || state.sessionId == null) return;

    final orderIndex = state.exercises.length;
    final seId = await _sessionDao.addSessionExercise(
      SessionExercisesCompanion(
        sessionId: Value(state.sessionId!),
        exerciseId: Value(exerciseId),
        orderIndex: Value(orderIndex),
        createdAt: Value(DateTime.now()),
      ),
    );

    // Add one default empty set
    final setId = await _sessionDao.addSet(WorkoutSetsCompanion(
      sessionExerciseId: Value(seId),
      setIndex: const Value(0),
      createdAt: Value(DateTime.now()),
    ));

    final activeExercise = ActiveExercise(
      sessionExerciseId: seId,
      exerciseId: exerciseId,
      name: exercise.name,
      gifUrl: exercise.gifUrl,
      sets: [ActiveSet(localId: setId, setIndex: 0)],
    );

    state = state.copyWith(
      exercises: [...state.exercises, activeExercise],
      currentExerciseIndex: state.exercises.length,
    );
  }

  /// Add a new set to the current exercise.
  Future<void> addSet() async {
    final ex = state.currentExercise;
    if (ex == null) return;

    final setIndex = ex.sets.length;
    final setId = await _sessionDao.addSet(WorkoutSetsCompanion(
      sessionExerciseId: Value(ex.sessionExerciseId),
      setIndex: Value(setIndex),
      createdAt: Value(DateTime.now()),
    ));

    final newSet = ActiveSet(localId: setId, setIndex: setIndex);
    final updatedEx = ex.copyWith(sets: [...ex.sets, newSet]);
    _updateExercise(updatedEx);
  }

  /// Update a set's weight or reps.
  Future<void> updateSet(int setLocalId, {String? weightStr, String? repsStr}) async {
    final ex = state.currentExercise;
    if (ex == null) return;

    double? weight;
    int? reps;

    if (weightStr != null) {
      weight = InputSanitiser.parseWeight(weightStr);
      // Convert lbs input to kg for storage
      if (_weightUnit == 'lbs' && weight != null) {
        weight = weight / 2.20462;
      }
    }

    if (repsStr != null) {
      reps = InputSanitiser.parseReps(repsStr);
    }

    final updatedSets = ex.sets.map((s) {
      if (s.localId == setLocalId) {
        return s.copyWith(
          weight: weight ?? s.weight,
          reps: reps ?? s.reps,
        );
      }
      return s;
    }).toList();

    final updatedEx = ex.copyWith(sets: updatedSets);
    _updateExercise(updatedEx);

    // Persist to DB
    final setEntity = await _sessionDao.getSets(ex.sessionExerciseId);
    final dbSet = setEntity.firstWhere((s) => s.localId == setLocalId);
    await _sessionDao.updateSet(dbSet.copyWith(
      weight: Value(weight ?? dbSet.weight),
      reps: Value(reps ?? dbSet.reps),
    ));
  }

  /// Mark a set as completed, trigger rest timer.
  Future<void> completeSet(int setLocalId) async {
    final ex = state.currentExercise;
    if (ex == null) return;

    final updatedSets = ex.sets.map((s) {
      if (s.localId == setLocalId) {
        return s.copyWith(isCompleted: true);
      }
      return s;
    }).toList();

    final updatedEx = ex.copyWith(sets: updatedSets);
    _updateExercise(updatedEx);

    // Haptic
    HapticFeedback.mediumImpact();

    // Start rest timer
    state = state.copyWith(showRestTimer: true);
    restTimerService.start(
      seconds: _defaultRestSeconds,
      onComplete: _onRestComplete,
    );
  }

  void _onRestComplete() {
    state = state.copyWith(showRestTimer: false);
  }

  void hideRestTimer() {
    restTimerService.cancel();
    state = state.copyWith(showRestTimer: false);
  }

  /// Switch to a different exercise.
  void selectExercise(int index) {
    if (index >= 0 && index < state.exercises.length) {
      state = state.copyWith(currentExerciseIndex: index);
    }
  }

  /// Finish the session.
  Future<void> finishSession() async {
    if (state.sessionId == null) return;
    state = state.copyWith(isFinishing: true);

    final now = DateTime.now();
    final durationSecs = now.difference(state.startedAt!).inSeconds;

    await _sessionDao.finishSession(
      state.sessionId!,
      now,
      durationSecs,
      state.totalVolume,
    );

    // Queue for sync
    await _syncQueueDao.enqueue(SyncQueueCompanion(
      syncTableName: const Value('sessions'),
      rowId: Value(state.sessionId!),
      operation: const Value('update'),
      payload: const Value('{}'),
      createdAt: Value(now),
    ));

    // Try sync
    try {
      await _syncService.syncAll();
    } catch (e) {
      debugPrint('Session sync failed: $e');
    }

    restTimerService.dispose();
  }

  /// Discard the session.
  Future<void> discardSession() async {
    restTimerService.dispose();
    state = const ActiveSessionState();
  }

  void updateSettings({int? restSeconds, String? weightUnit}) {
    if (restSeconds != null) _defaultRestSeconds = restSeconds;
    if (weightUnit != null) _weightUnit = weightUnit;
  }

  String get weightUnit => _weightUnit;

  /// Display weight: convert kg to lbs if needed.
  String displayWeight(double? weightKg) {
    if (weightKg == null) return '0';
    if (_weightUnit == 'lbs') {
      return (weightKg * 2.20462).toStringAsFixed(0);
    }
    return weightKg.toStringAsFixed(0);
  }

  void _updateExercise(ActiveExercise updated) {
    final exercises = [...state.exercises];
    final idx =
        exercises.indexWhere((e) => e.sessionExerciseId == updated.sessionExerciseId);
    if (idx >= 0) {
      exercises[idx] = updated;
      state = state.copyWith(exercises: exercises);
    }
  }

  @override
  void dispose() {
    restTimerService.dispose();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────

final activeSessionProvider =
    StateNotifierProvider<ActiveSessionNotifier, ActiveSessionState>((ref) {
  final sessionDao = ref.watch(sessionDaoProvider);
  final exerciseDao = ref.watch(exerciseDaoProvider);
  final scheduleDao = ref.watch(scheduleDaoProvider);
  final syncQueueDao = SyncQueueDao(ref.watch(databaseProvider));
  final syncService = ref.watch(syncServiceProvider);

  final profile = ref.watch(userProfileProvider).valueOrNull;

  return ActiveSessionNotifier(
    sessionDao: sessionDao,
    exerciseDao: exerciseDao,
    scheduleDao: scheduleDao,
    syncQueueDao: syncQueueDao,
    syncService: syncService,
    defaultRestSeconds: profile?.defaultRestSeconds ?? 90,
    weightUnit: profile?.weightUnit ?? 'kg',
  );
});
