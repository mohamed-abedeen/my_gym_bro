import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/security/input_sanitiser.dart';
import 'package:my_gym_bro/core/services/notification_service.dart';
import 'package:my_gym_bro/features/workout/active_session/rest_timer_service.dart';
import 'package:my_gym_bro/features/workout/workout_log_repository.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

// ── Set type ──────────────────────────────────

enum SetType { normal, warmUp, failure, dropset }

// ── Models ────────────────────────────────────

class ActiveExercise {

  ActiveExercise({
    required this.sessionExerciseId,
    required this.exerciseId,
    required this.name,
    this.gifUrl,
    this.muscleGroup,
    List<ActiveSet>? sets,
  }) : sets = sets ?? [];
  final int sessionExerciseId;
  final String exerciseId;
  final String name;
  final String? gifUrl;
  final String? muscleGroup;
  final List<ActiveSet> sets;

  bool get isCardio => muscleGroup?.toLowerCase() == 'cardio';

  ActiveExercise copyWith({List<ActiveSet>? sets}) => ActiveExercise(
        sessionExerciseId: sessionExerciseId,
        exerciseId: exerciseId,
        name: name,
        gifUrl: gifUrl,
        muscleGroup: muscleGroup,
        sets: sets ?? this.sets,
      );
}

class ActiveSet {

  const ActiveSet({
    required this.localId,
    required this.setIndex,
    this.weight,
    this.reps,
    this.isWarmup = false,
    this.isDropset = false,
    this.isFailure = false,
    this.isCompleted = false,
    this.durationSeconds,
    this.distance,
    this.speed,
    this.incline,
  });
  final int localId;
  final int setIndex;
  final double? weight;
  final int? reps;
  final bool isWarmup;
  final bool isDropset;
  final bool isFailure;
  final bool isCompleted;
  final int? durationSeconds;
  final double? distance;
  final double? speed;
  final double? incline;

  SetType get setType {
    if (isWarmup) return SetType.warmUp;
    if (isDropset) return SetType.dropset;
    if (isFailure) return SetType.failure;
    return SetType.normal;
  }

  ActiveSet copyWith({
    double? weight,
    int? reps,
    bool? isWarmup,
    bool? isDropset,
    bool? isFailure,
    bool? isCompleted,
    int? durationSeconds,
    double? distance,
    double? speed,
    double? incline,
  }) =>
      ActiveSet(
        localId: localId,
        setIndex: setIndex,
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        isWarmup: isWarmup ?? this.isWarmup,
        isDropset: isDropset ?? this.isDropset,
        isFailure: isFailure ?? this.isFailure,
        isCompleted: isCompleted ?? this.isCompleted,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        distance: distance ?? this.distance,
        speed: speed ?? this.speed,
        incline: incline ?? this.incline,
      );
}

class ActiveSessionState {

  const ActiveSessionState({
    this.sessionId,
    this.exercises = const [],
    this.currentExerciseIndex = 0,
    this.startedAt,
    this.showRestTimer = false,
    this.isFinishing = false,
  });
  final int? sessionId;
  final List<ActiveExercise> exercises;
  final int currentExerciseIndex;
  final DateTime? startedAt;
  final bool showRestTimer;
  final bool isFinishing;

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
    var count = 0;
    for (final ex in exercises) {
      count += ex.sets.where((s) => s.isCompleted).length;
    }
    return count;
  }
}

// ── Notifier ──────────────────────────────────

class ActiveSessionNotifier extends StateNotifier<ActiveSessionState> {
  static const double _kLbsPerKg = 2.20462;

  ActiveSessionNotifier({
    required WorkoutLogRepository repository,
    int defaultRestSeconds = 90,
    String weightUnit = 'kg',
    String restNotificationTitle = 'Rest complete!',
    String restNotificationBody = 'Time to start your next set.',
  })  : _repository = repository,
        _defaultRestSeconds = defaultRestSeconds,
        _weightUnit = weightUnit,
        _restNotificationTitle = restNotificationTitle,
        _restNotificationBody = restNotificationBody,
        super(const ActiveSessionState());
  final WorkoutLogRepository _repository;
  final RestTimerService restTimerService = RestTimerService();

  /// Subscription to the rest-timer tick stream for updating the
  /// notification progress bar every second.
  StreamSubscription<int>? _restTickSub;

  /// Per-session cache so we only hit the DB once per exercise.
  final Map<String, List<LastLoggedSetInfo>> _lastLoggedCache = {};

  int _defaultRestSeconds;
  String _weightUnit;
  String _restNotificationTitle;
  String _restNotificationBody;
  String _workoutReminderTitle = 'Workout day';
  String _workoutReminderBody = 'Keep your streak going. Let\'s train.';

  /// Called by the workout screen whenever the active locale or the
  /// user's `notificationTone` changes — keeps the rest-complete
  /// notification copy in sync with the user's current preferences.
  void setRestNotificationStrings(String title, String body) {
    _restNotificationTitle = title;
    _restNotificationBody = body;
  }

  /// Called by the screen each build with tone- and rest-day-aware copy.
  void setWorkoutReminderStrings(String title, String body) {
    _workoutReminderTitle = title;
    _workoutReminderBody = body;
  }

  /// Attempt to restore a rest timer that was persisted before the OS killed
  /// the app. Should be called once after session state is rebuilt on app
  /// restart (e.g. from the workout screen's `initState`).
  Future<void> tryRestoreRestTimer() async {
    // Don't restore if a timer is already ticking.
    if (restTimerService.remaining > 0) return;

    final saved = await RestTimerService.loadPersistedState();
    if (saved == null) return;

    state = state.copyWith(showRestTimer: true);
    restTimerService.restore(
      remaining: saved.remaining,
      total: saved.total,
      onComplete: _onRestComplete,
      soundEnabled: saved.soundEnabled,
      notificationTitle: saved.title,
      notificationBody: saved.body,
    );

    // Subscribe to the tick stream so the notification updates every second.
    _restTickSub?.cancel();
    _restTickSub =
        restTimerService.stream?.listen(_updateRestTimerNotification);
  }

  /// Start a new workout session, optionally pre-loading exercises from a
  /// schedule day.
  Future<void> startSession({int? scheduleDayId}) async {
    final now = DateTime.now();
    final id = await _repository.createSession(
      CreateSessionParams(startedAt: now),
    );

    state = state.copyWith(
      sessionId: id,
      startedAt: now,
      exercises: [],
    );

    // Show a persistent ongoing notification in the status bar so the user
    // can see the elapsed workout time even when the app is backgrounded.
    unawaited(NotificationService.showActiveWorkout(
      title: 'Workout in progress',
      body: 'Tap to return to your session.',
      startedAt: now,
    ));

    // Allow the notification "Complete Set" action to call completeNextSet()
    // without needing a Riverpod ref.
    restTimerService.completeSetFromNotification = completeNextSet;

    // If a schedule day was provided, load its exercises into the session.
    if (scheduleDayId != null) {
      await _loadScheduleExercises(scheduleDayId);
    }
  }

  /// Load all exercises from a schedule day into the active session.
  Future<void> _loadScheduleExercises(int scheduleDayId) async {
    if (state.sessionId == null) return;

    final scheduledExercises =
        await _repository.getScheduledExercises(scheduleDayId);

    // Batch-fetch all exercises in one query instead of N individual queries.
    final exerciseIds =
        scheduledExercises.map((se) => se.exerciseId).toList();
    final exerciseMap = await _repository.findExercisesByIds(exerciseIds);

    for (final scheduled in scheduledExercises) {
      final exercise = exerciseMap[scheduled.exerciseId];
      if (exercise == null) continue;

      unawaited(_repository.incrementExerciseUsage(scheduled.exerciseId));

      final orderIndex = state.exercises.length;
      final seId = await _repository.addSessionExercise(
        AddSessionExerciseParams(
          sessionId: state.sessionId!,
          exerciseId: scheduled.exerciseId,
          orderIndex: orderIndex,
        ),
      );

      // Fetch the user's last logged sets for this exercise (auto-fill).
      final history = await _getLastLoggedSets(scheduled.exerciseId);

      // Create sets based on the scheduled target sets and reps,
      // but auto-fill weight & cardio fields from history when available.
      final sets = <ActiveSet>[];
      for (var s = 0; s < scheduled.targetSets; s++) {
        final histSet = s < history.length ? history[s] : null;
        final setId = await _repository.addSet(AddSetParams(
          sessionExerciseId: seId,
          setIndex: s,
          weight: histSet?.weight,
          reps: histSet?.reps ?? scheduled.targetReps,
          durationSeconds: histSet?.durationSeconds,
          distance: histSet?.distance,
          speed: histSet?.speed,
          incline: histSet?.incline,
        ));
        sets.add(ActiveSet(
          localId: setId,
          setIndex: s,
          weight: histSet?.weight,
          reps: histSet?.reps ?? scheduled.targetReps,
          durationSeconds: histSet?.durationSeconds,
          distance: histSet?.distance,
          speed: histSet?.speed,
          incline: histSet?.incline,
        ));
      }

      final activeExercise = ActiveExercise(
        sessionExerciseId: seId,
        exerciseId: scheduled.exerciseId,
        name: exercise.name,
        gifUrl: exercise.gifUrl,
        muscleGroup: exercise.muscleGroup,
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
  ///
  /// Auto-fills sets from the user's most recently completed session for
  /// this exercise. Falls back to a single empty set when no history exists.
  Future<void> addExercise(String exerciseId) async {
    final exercise = await _repository.findExercise(exerciseId);
    if (exercise == null || state.sessionId == null) return;

    unawaited(_repository.incrementExerciseUsage(exerciseId));

    final orderIndex = state.exercises.length;
    final seId = await _repository.addSessionExercise(
      AddSessionExerciseParams(
        sessionId: state.sessionId!,
        exerciseId: exerciseId,
        orderIndex: orderIndex,
      ),
    );

    // Fetch the user's last logged sets for this exercise (auto-fill).
    final history = await _getLastLoggedSets(exerciseId);

    final sets = <ActiveSet>[];
    if (history.isNotEmpty) {
      // Recreate the same number of sets with their weights/reps pre-filled.
      for (var i = 0; i < history.length; i++) {
        final h = history[i];
        final setId = await _repository.addSet(AddSetParams(
          sessionExerciseId: seId,
          setIndex: i,
          weight: h.weight,
          reps: h.reps,
          durationSeconds: h.durationSeconds,
          distance: h.distance,
          speed: h.speed,
          incline: h.incline,
        ));
        sets.add(ActiveSet(
          localId: setId,
          setIndex: i,
          weight: h.weight,
          reps: h.reps,
          durationSeconds: h.durationSeconds,
          distance: h.distance,
          speed: h.speed,
          incline: h.incline,
        ));
      }
    } else {
      // No history — add one empty set.
      final setId = await _repository.addSet(AddSetParams(
        sessionExerciseId: seId,
        setIndex: 0,
      ));
      sets.add(ActiveSet(localId: setId, setIndex: 0));
    }

    final activeExercise = ActiveExercise(
      sessionExerciseId: seId,
      exerciseId: exerciseId,
      name: exercise.name,
      gifUrl: exercise.gifUrl,
      muscleGroup: exercise.muscleGroup,
      sets: sets,
    );

    state = state.copyWith(
      exercises: [...state.exercises, activeExercise],
      currentExerciseIndex: state.exercises.length,
    );
  }

  /// Remove the currently active exercise (and all its sets) from the session.
  Future<void> removeCurrentExercise() async {
    final ex = state.currentExercise;
    if (ex == null) return;

    final exercises = [...state.exercises]
      ..removeAt(state.currentExerciseIndex);
    final newIndex =
        state.currentExerciseIndex >= exercises.length && exercises.isNotEmpty
            ? exercises.length - 1
            : state.currentExerciseIndex.clamp(0, exercises.isEmpty ? 0 : exercises.length - 1);

    state = state.copyWith(
      exercises: exercises,
      currentExerciseIndex: newIndex,
    );

    await _repository.deleteSessionExercise(ex.sessionExerciseId);
  }

  /// Delete a set by its local id, removing it from both state and the DB.
  Future<void> deleteSet(int setLocalId) async {
    final exercises = [...state.exercises];
    for (var i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      final idx = ex.sets.indexWhere((s) => s.localId == setLocalId);
      if (idx < 0) continue;

      final remaining = [...ex.sets]..removeAt(idx);
      // Re-number setIndex so displayed set numbers stay contiguous.
      final reindexed = List<ActiveSet>.generate(
        remaining.length,
        (j) => ActiveSet(
          localId: remaining[j].localId,
          setIndex: j,
          weight: remaining[j].weight,
          reps: remaining[j].reps,
          isWarmup: remaining[j].isWarmup,
          isDropset: remaining[j].isDropset,
          isFailure: remaining[j].isFailure,
          isCompleted: remaining[j].isCompleted,
          durationSeconds: remaining[j].durationSeconds,
          distance: remaining[j].distance,
          speed: remaining[j].speed,
          incline: remaining[j].incline,
        ),
      );
      exercises[i] = ex.copyWith(sets: reindexed);
      state = state.copyWith(exercises: exercises);
      break;
    }
    await _repository.deleteSet(setLocalId);
  }

  /// Complete the first incomplete set in the current exercise.
  Future<void> completeNextSet() async {
    final ex = state.currentExercise;
    if (ex == null) return;
    final next = ex.sets.where((s) => !s.isCompleted).firstOrNull;
    if (next != null) await completeSet(next.localId);
  }

  /// Add a new set to the current exercise.
  Future<void> addSet() async {
    final ex = state.currentExercise;
    if (ex == null) return;

    final setIndex = ex.sets.length;
    final prevSet = ex.sets.isNotEmpty ? ex.sets.last : null;

    final setId = await _repository.addSet(AddSetParams(
      sessionExerciseId: ex.sessionExerciseId,
      setIndex: setIndex,
      weight: prevSet?.weight,
      reps: prevSet?.reps,
      durationSeconds: prevSet?.durationSeconds,
      distance: prevSet?.distance,
      speed: prevSet?.speed,
      incline: prevSet?.incline,
    ));

    final newSet = ActiveSet(
      localId: setId,
      setIndex: setIndex,
      weight: prevSet?.weight,
      reps: prevSet?.reps,
      durationSeconds: prevSet?.durationSeconds,
      distance: prevSet?.distance,
      speed: prevSet?.speed,
      incline: prevSet?.incline,
    );
    final updatedEx = ex.copyWith(sets: [...ex.sets, newSet]);
    _updateExercise(updatedEx);
  }

  /// Update a set's fields (strength or cardio).
  Future<void> updateSet(
    int setLocalId, {
    String? weightStr,
    String? repsStr,
    String? durationStr,
    String? distanceStr,
    String? speedStr,
    String? inclineStr,
  }) async {
    final ex = state.currentExercise;
    if (ex == null) return;

    double? weight;
    int? reps;
    int? durationSeconds;
    double? distance;
    double? speed;
    double? incline;

    if (weightStr != null) {
      weight = InputSanitiser.parseWeight(weightStr);
      if (_weightUnit == 'lbs' && weight != null) weight = weight / _kLbsPerKg;
    }
    if (repsStr != null) reps = InputSanitiser.parseReps(repsStr);
    if (durationStr != null) {
      final minutes = double.tryParse(durationStr.replaceAll(RegExp('[^0-9.]'), ''));
      if (minutes != null && minutes >= 0 && minutes <= 999) {
        durationSeconds = (minutes * 60).round();
      }
    }
    if (distanceStr != null) {
      distance = double.tryParse(distanceStr.replaceAll(RegExp('[^0-9.]'), ''));
      if (distance != null && (distance < 0 || distance > 9999)) distance = null;
    }
    if (speedStr != null) {
      speed = double.tryParse(speedStr.replaceAll(RegExp('[^0-9.]'), ''));
      if (speed != null && (speed < 0 || speed > 9999)) speed = null;
    }
    if (inclineStr != null) {
      incline = double.tryParse(inclineStr.replaceAll(RegExp('[^0-9.]'), ''));
      if (incline != null && (incline < 0 || incline > 90)) incline = null;
    }

    final updatedSets = ex.sets.map((s) {
      if (s.localId == setLocalId) {
        return s.copyWith(
          weight: weight ?? s.weight,
          reps: reps ?? s.reps,
          durationSeconds: durationSeconds ?? s.durationSeconds,
          distance: distance ?? s.distance,
          speed: speed ?? s.speed,
          incline: incline ?? s.incline,
        );
      }
      return s;
    }).toList();

    final updatedEx = ex.copyWith(sets: updatedSets);
    _updateExercise(updatedEx);

    // Persist to DB
    await _repository.updateSet(UpdateSetParams(
      sessionExerciseId: ex.sessionExerciseId,
      setLocalId: setLocalId,
      weight: weight,
      reps: reps,
      durationSeconds: durationSeconds,
      distance: distance,
      speed: speed,
      incline: incline,
    ));
  }

  /// Change the type of a set (warm-up / normal / failure / drop-set).
  Future<void> updateSetType(int setLocalId, SetType type) async {
    for (final ex in state.exercises) {
      final idx = ex.sets.indexWhere((s) => s.localId == setLocalId);
      if (idx < 0) continue;

      final updatedSets = ex.sets.map((s) {
        if (s.localId != setLocalId) return s;
        return s.copyWith(
          isWarmup: type == SetType.warmUp,
          isDropset: type == SetType.dropset,
          isFailure: type == SetType.failure,
        );
      }).toList();
      _updateExercise(ex.copyWith(sets: updatedSets));

      await _repository.updateSetType(UpdateSetTypeParams(
        sessionExerciseId: ex.sessionExerciseId,
        setLocalId: setLocalId,
        isWarmup: type == SetType.warmUp,
        isDropset: type == SetType.dropset,
        isFailure: type == SetType.failure,
      ));
      return;
    }
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
    unawaited(HapticFeedback.mediumImpact());

    // Start rest timer
    state = state.copyWith(showRestTimer: true);
    restTimerService.start(
      seconds: _defaultRestSeconds,
      onComplete: _onRestComplete,
      notificationTitle: _restNotificationTitle,
      notificationBody: _restNotificationBody,
    );

    // Subscribe to the tick stream so the notification updates every second.
    _restTickSub?.cancel();
    _restTickSub = restTimerService.stream?.listen(_updateRestTimerNotification);
  }

  void _onRestComplete() {
    _restTickSub?.cancel();
    _restTickSub = null;
    state = state.copyWith(showRestTimer: false);
    // Switch the notification back to the "active set" state.
    _updateActiveSetNotification();
  }

  void hideRestTimer() {
    _restTickSub?.cancel();
    _restTickSub = null;
    restTimerService.cancel();
    state = state.copyWith(showRestTimer: false);
    // Switch the notification back to the "active set" state.
    _updateActiveSetNotification();
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

    await _repository.finishSession(FinishSessionParams(
      sessionId: state.sessionId!,
      finishedAt: now,
      durationSeconds: durationSecs,
      totalVolume: state.totalVolume,
    ));

    _restTickSub?.cancel();
    _restTickSub = null;
    restTimerService.dispose();

    // Remove the persistent workout-in-progress notification.
    unawaited(NotificationService.cancelActiveWorkout());

    // Schedule a daily workout reminder for tomorrow using rest-day-aware copy.
    unawaited(NotificationService.scheduleWorkoutReminder(
      title: _workoutReminderTitle,
      body: _workoutReminderBody,
    ));

    // Reset state so a subsequent session starts clean.
    _lastLoggedCache.clear();
    state = const ActiveSessionState();
  }

  /// Discard the session.
  Future<void> discardSession() async {
    _restTickSub?.cancel();
    _restTickSub = null;
    restTimerService.dispose();
    _lastLoggedCache.clear();
    unawaited(NotificationService.cancelActiveWorkout());
    state = const ActiveSessionState();
  }

  /// Retrieve the user's last logged sets for [exerciseId], using a
  /// per-session in-memory cache to avoid redundant DB hits.
  Future<List<LastLoggedSetInfo>> _getLastLoggedSets(String exerciseId) async {
    if (_lastLoggedCache.containsKey(exerciseId)) {
      return _lastLoggedCache[exerciseId]!;
    }
    final sets = await _repository.getLastLoggedSets(exerciseId);
    _lastLoggedCache[exerciseId] = sets;
    return sets;
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
      return (weightKg * _kLbsPerKg).toStringAsFixed(0);
    }
    return weightKg.toStringAsFixed(0);
  }

  /// Display duration in decimal minutes (e.g. 330 s → "5.5").
  String displayDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '0';
    if (seconds % 60 == 0) return '${seconds ~/ 60}';
    return (seconds / 60.0).toStringAsFixed(1);
  }

  /// Display a nullable double field, defaulting to '0'.
  String displayDouble(double? value) {
    if (value == null || value == 0) return '0';
    return value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
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

  // ── Notification helpers ────────────────────────────────────────────────

  /// Push the "active set" notification (State A).
  ///
  /// Shows the next incomplete set for the current exercise, or falls
  /// back to a generic "workout in progress" notification.
  void _updateActiveSetNotification() {
    final ex = state.currentExercise;
    if (ex == null) return;

    final nextSet = ex.sets.where((s) => !s.isCompleted).firstOrNull;
    if (nextSet == null) return;

    final currentNum = nextSet.setIndex + 1;
    final totalSets = ex.sets.length;
    final weight = displayWeight(nextSet.weight);
    final unit = _weightUnit;
    final reps = nextSet.reps ?? 0;

    unawaited(NotificationService.showActiveSet(
      exerciseName: ex.name,
      currentSet: currentNum,
      totalSets: totalSets,
      weight: '$weight$unit',
      reps: reps,
    ));
  }

  /// Push the "rest timer" notification (State B) with a progress bar.
  void _updateRestTimerNotification(int remaining) {
    final ex = state.currentExercise;
    if (ex == null) return;

    final nextSet = ex.sets.where((s) => !s.isCompleted).firstOrNull;
    final nextNum = nextSet != null ? nextSet.setIndex + 1 : ex.sets.length;
    final totalSets = ex.sets.length;
    final weight = displayWeight(nextSet?.weight);
    final unit = _weightUnit;
    final reps = nextSet?.reps ?? 0;

    unawaited(NotificationService.updateRestTimer(
      exerciseName: ex.name,
      nextSet: nextNum,
      totalSets: totalSets,
      weight: '$weight$unit',
      reps: reps,
      remaining: remaining,
      totalSeconds: restTimerService.total,
    ));
  }

  @override
  void dispose() {
    _restTickSub?.cancel();
    restTimerService.dispose();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────

final activeSessionProvider =
    StateNotifierProvider<ActiveSessionNotifier, ActiveSessionState>((ref) {
  final repository = ref.watch(workoutLogRepositoryProvider);

  // Use ref.read so that profile changes don't recreate (and wipe) the
  // notifier mid-session. Settings are pushed reactively via ref.listen below.
  final profile = ref.read(userProfileProvider).valueOrNull;

  final notifier = ActiveSessionNotifier(
    repository: repository,
    defaultRestSeconds: profile?.defaultRestSeconds ?? 90,
    weightUnit: profile?.weightUnit ?? 'kg',
  );

  // Keep rest-time / weight-unit in sync without recreating the notifier.
  ref.listen(userProfileProvider, (_, next) {
    final p = next.valueOrNull;
    if (p != null) {
      notifier.updateSettings(
        restSeconds: p.defaultRestSeconds,
        weightUnit: p.weightUnit,
      );
    }
  });

  return notifier;
});
