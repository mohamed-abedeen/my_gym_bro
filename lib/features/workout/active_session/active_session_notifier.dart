import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/input_sanitiser.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';
import 'package:my_gym_bro/core/services/live_activity_service.dart';
import 'package:my_gym_bro/core/services/notification_image_cache.dart';
import 'package:my_gym_bro/core/services/notification_service.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/core/services/widget_sync_service.dart';
import 'package:my_gym_bro/features/settings/app_settings_provider.dart';
import 'package:my_gym_bro/features/workout/active_session/rest_timer_service.dart';
import 'package:my_gym_bro/features/workout/workout_log_repository.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

// ── Set type ──────────────────────────────────

/// Set types. [superset] has no dedicated DB column — it is persisted as the
/// (otherwise impossible) `isDropset && isFailure` combination so no schema
/// migration is needed. Stats are unaffected: working-set filters only
/// exclude `isWarmup`, so supersets still count toward volume and PRs.
enum SetType { normal, warmUp, failure, dropset, superset }

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
    if (isDropset && isFailure) return SetType.superset;
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
    this.pausedAt,
    this.accumulatedPausedSeconds = 0,
  });
  final int? sessionId;
  final List<ActiveExercise> exercises;
  final int currentExerciseIndex;
  final DateTime? startedAt;
  final bool showRestTimer;
  final bool isFinishing;

  /// Wall-clock time the user pressed pause. `null` when the session is
  /// active. The elapsed clock and Live Activity reads this to freeze.
  final DateTime? pausedAt;

  /// Total seconds the user has spent paused across the session so far.
  /// On resume, the in-flight pause delta is added here and `pausedAt`
  /// is cleared. `finishSession` subtracts this from total wall-time to
  /// get the user-facing duration.
  final int accumulatedPausedSeconds;

  bool get isPaused => pausedAt != null;

  ActiveSessionState copyWith({
    int? sessionId,
    List<ActiveExercise>? exercises,
    int? currentExerciseIndex,
    DateTime? startedAt,
    bool? showRestTimer,
    bool? isFinishing,
    DateTime? pausedAt,
    int? accumulatedPausedSeconds,
    bool clearPausedAt = false,
  }) =>
      ActiveSessionState(
        sessionId: sessionId ?? this.sessionId,
        exercises: exercises ?? this.exercises,
        currentExerciseIndex:
            currentExerciseIndex ?? this.currentExerciseIndex,
        startedAt: startedAt ?? this.startedAt,
        showRestTimer: showRestTimer ?? this.showRestTimer,
        isFinishing: isFinishing ?? this.isFinishing,
        pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
        accumulatedPausedSeconds:
            accumulatedPausedSeconds ?? this.accumulatedPausedSeconds,
      );

  ActiveExercise? get currentExercise =>
      exercises.isNotEmpty && currentExerciseIndex < exercises.length
          ? exercises[currentExerciseIndex]
          : null;

  /// Session time excluding pauses — wall clock minus accumulated paused
  /// time minus any in-flight pause. Matches what finishSession persists.
  int get elapsedSeconds {
    final started = startedAt;
    if (started == null) return 0;
    final now = DateTime.now();
    final wallClock = now.difference(started).inSeconds;
    final inFlightPause =
        pausedAt == null ? 0 : now.difference(pausedAt!).inSeconds;
    return (wallClock - accumulatedPausedSeconds - inFlightPause)
        .clamp(0, wallClock);
  }

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
    ExerciseRepository? exerciseRepository,
    int defaultRestSeconds = 90,
    String weightUnit = 'kg',
    bool restSoundEnabled = true,
    bool restVibrationEnabled = true,
    String restNotificationTitle = 'Rest complete!',
    String restNotificationBody = 'Time to start your next set.',
    Future<int> Function()? getStreak,
  })  : _repository = repository,
        _exerciseRepo = exerciseRepository,
        _defaultRestSeconds = defaultRestSeconds,
        _weightUnit = weightUnit,
        _restSoundEnabled = restSoundEnabled,
        _restVibrationEnabled = restVibrationEnabled,
        _restNotificationTitle = restNotificationTitle,
        _restNotificationBody = restNotificationBody,
        _getStreak = getStreak,
        super(const ActiveSessionState());
  final WorkoutLogRepository _repository;

  /// Optional WorkoutX-backed cache. When present, logging an exercise ensures
  /// it is cached locally (cache-on-log) so history/recovery resolve offline.
  final ExerciseRepository? _exerciseRepo;
  /// Refresh-and-read the streak. Invalidates the cached value first so the
  /// just-finished session is included. Provided by the provider builder.
  final Future<int> Function()? _getStreak;
  final RestTimerService restTimerService = RestTimerService();

  /// Subscription to the rest-timer tick stream for updating the
  /// notification progress bar every second.
  StreamSubscription<int>? _restTickSub;

  /// Per-session cache so we only hit the DB once per exercise.
  final Map<String, List<LastLoggedSetInfo>> _lastLoggedCache = {};

  int _defaultRestSeconds;
  String _weightUnit;
  bool _restSoundEnabled;
  bool _restVibrationEnabled;
  String _restNotificationTitle;
  String _restNotificationBody;
  String _workoutReminderTitle = 'Workout day';
  String _workoutReminderBody = 'Keep your streak going. Let\'s train.';

  /// User-selected notification voice — drives tone-aware copy in the
  /// ongoing-session notification (active-set tagline + rest tagline +
  /// generic "session live" body). Defaults to balanced so we never ship
  /// silent strings if the screen forgets to push the current tone.
  NotificationTone _notificationTone = NotificationTone.balanced;

  /// Cached local file path of the current exercise's GIF/thumbnail. Used
  /// as `largeIcon` on the Android notification. Resolved lazily — the
  /// notification renders without an icon if the download/cache misses
  /// inside the (short) timeout in [NotificationImageCache].
  String? _currentExerciseImagePath;

  /// The gifUrl whose path is currently cached in [_currentExerciseImagePath].
  /// Kept so we don't re-fetch the same asset every set.
  String? _cachedImageGifUrl;

  /// Called by the workout screen whenever the active locale or the
  /// user's `notificationTone` changes — keeps the rest-complete
  /// notification copy in sync with the user's current preferences.
  void setRestNotificationStrings(String title, String body) {
    _restNotificationTitle = title;
    _restNotificationBody = body;
  }

  /// Build the "Set 2 of 4" label for the current exercise. Used by the
  /// iOS Live Activity / Dynamic Island. Returns "" when there's no
  /// current exercise.
  String _setProgressLabel() {
    final ex = state.currentExercise;
    if (ex == null || ex.sets.isEmpty) return '';
    final completed = ex.sets.where((s) => s.isCompleted).length;
    return 'Set ${completed.clamp(1, ex.sets.length)} of ${ex.sets.length}';
  }

  String _liveActivityExerciseName() =>
      state.currentExercise?.name ?? 'Workout';

  /// Called by the screen each build with tone- and rest-day-aware copy.
  void setWorkoutReminderStrings(String title, String body) {
    _workoutReminderTitle = title;
    _workoutReminderBody = body;
  }

  /// Push the user's chosen notification voice down to the notifier so the
  /// active-session notification can use tone-aware taglines (active-set,
  /// resting, generic). Called from the screen alongside the existing
  /// `setRestNotificationStrings` so all tone state stays in sync.
  void setNotificationTone(NotificationTone tone) {
    _notificationTone = tone;
  }

  /// Resolve the current exercise's image into a local file path used as
  /// the Android notification largeIcon. Fire-and-forget; the notification
  /// is updated *after* the image lands so the first frame doesn't block
  /// the rest-timer push.
  Future<void> _refreshExerciseImage() async {
    final url = state.currentExercise?.gifUrl;
    if (url == _cachedImageGifUrl) return; // already cached
    _cachedImageGifUrl = url;
    if (url == null || url.isEmpty) {
      _currentExerciseImagePath = null;
      return;
    }
    _currentExerciseImagePath = await NotificationImageCache.filePathFor(url);
    // Re-push whichever notification we're currently showing so the new
    // largeIcon takes effect. If state has changed by the time the cache
    // resolves, the next state-driven update will pick it up naturally.
    if (state.sessionId == null) return;
    if (state.showRestTimer) {
      _updateRestTimerNotification(restTimerService.remaining);
    } else {
      _updateActiveSetNotification();
    }
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
      vibrationEnabled: saved.vibrationEnabled,
      notificationTitle: saved.title,
      notificationBody: saved.body,
    );

    // Subscribe to the tick stream so the notification updates every second.
    _restTickSub?.cancel();
    _restTickSub =
        restTimerService.stream?.listen(_updateRestTimerNotification);

    // The previous app instance owned a now-orphaned ongoing notification
    // whose +15s / Skip / Complete buttons point at a dead isolate. Tear
    // it down and rebuild from this notifier's current state.
    await resyncActiveNotification();
  }

  /// Option A from `docs/notification-recovery.md`.
  ///
  /// When the app returns from background (or relaunches after force-kill),
  /// the ongoing "MyGymBro Session" notification can be a stale ghost —
  /// the visible card is right but its action buttons are wired to a dead
  /// isolate that can't dispatch them. The fix is to cancel it and re-fire
  /// the appropriate notification from the live notifier so the buttons
  /// route through *this* process's `_handleAction`.
  ///
  /// Cheap: ~1 plugin cancel + 1 plugin show. Safe to call repeatedly —
  /// the rebuilt notification reuses the same id so it replaces in place
  /// without flicker on Android, and is a no-op when there's no active
  /// session.
  Future<void> resyncActiveNotification() async {
    if (state.sessionId == null) {
      // No live session — but tear down any lingering stale notification
      // anyway. Could exist if the previous app instance left one behind
      // and we resumed without restoring its state.
      await NotificationService.cancelActiveWorkout();
      return;
    }
    await NotificationService.cancelActiveWorkout();
    if (state.showRestTimer) {
      _updateRestTimerNotification(restTimerService.remaining);
    } else {
      _updateActiveSetNotification();
    }
  }

  /// Restore an in-progress session after a process kill, or just resync
  /// the ongoing notification when a session is already live in memory.
  /// Returns true when a session is live after the call.
  ///
  /// Restoration rebuilds the full [ActiveSessionState] (exercises + sets)
  /// from Drift — every mutation is already persisted as it happens, so a
  /// mid-workout kill loses nothing. Unfinished sessions older than the
  /// repository's restore window are reconciled instead: auto-finished when
  /// they contain completed work (so the workout still reaches history) or
  /// deleted when empty. Pause bookkeeping does not survive a kill; the
  /// restored session resumes unpaused.
  Future<bool> restoreOrResync() async {
    if (state.sessionId != null) {
      await resyncActiveNotification();
      return true;
    }

    try {
      await _repository.reconcileAbandonedSessions();
    } on Exception {
      // Best-effort cleanup — never block restore on it.
    }

    final RestoredSessionInfo? restored;
    try {
      restored = await _repository.getRestorableSession();
    } on Exception {
      return false;
    }
    if (restored == null) {
      // Nothing to restore — tear down any ghost notification left behind
      // by a previous process.
      await NotificationService.cancelActiveWorkout();
      return false;
    }
    // A manual start may have raced us across the awaits above.
    if (state.sessionId != null) return true;

    final exercises = [
      for (final e in restored.exercises)
        ActiveExercise(
          sessionExerciseId: e.sessionExerciseId,
          exerciseId: e.exerciseId,
          name: e.name,
          gifUrl: e.gifUrl,
          muscleGroup: e.muscleGroup,
          sets: [
            for (final s in e.sets)
              ActiveSet(
                localId: s.localId,
                setIndex: s.setIndex,
                weight: s.weight,
                reps: s.reps,
                isWarmup: s.isWarmup,
                isDropset: s.isDropset,
                isFailure: s.isFailure,
                isCompleted: s.isCompleted,
                durationSeconds: s.durationSeconds,
                distance: s.distance,
                speed: s.speed,
                incline: s.incline,
              ),
          ],
        ),
    ];

    // Resume on the first exercise that still has work to do.
    var currentIndex =
        exercises.indexWhere((ex) => ex.sets.any((s) => !s.isCompleted));
    if (currentIndex < 0) {
      currentIndex = exercises.isEmpty ? 0 : exercises.length - 1;
    }

    state = state.copyWith(
      sessionId: restored.sessionId,
      startedAt: restored.startedAt,
      exercises: exercises,
      currentExerciseIndex: currentIndex,
    );

    restTimerService.completeSetFromNotification = completeNextSet;

    // Re-arm a persisted rest countdown if one survived; it resyncs the
    // ongoing notification itself. Otherwise rebuild the active-set view.
    await tryRestoreRestTimer();
    if (!state.showRestTimer) {
      unawaited(_refreshExerciseImage());
      await resyncActiveNotification();
    }
    return true;
  }

  /// Start a new workout session, optionally pre-loading exercises from a
  /// schedule day.
  Future<void> startSession({int? scheduleDayId}) async {
    final now = DateTime.now();
    // Resolve the parent schedule for this day so countBySchedule /
    // getLastForSchedule / day-rotation logic can find the finished session.
    final scheduleId = scheduleDayId == null
        ? null
        : await _repository.getScheduleIdForDay(scheduleDayId);
    final id = await _repository.createSession(
      CreateSessionParams(startedAt: now, scheduleId: scheduleId),
    );

    state = state.copyWith(
      sessionId: id,
      startedAt: now,
      exercises: [],
    );

    // Show a persistent ongoing notification in the status bar so the user
    // can see the elapsed workout time even when the app is backgrounded.
    // This is the *generic* state — _loadScheduleExercises (or addExercise)
    // will replace it with the named-exercise notification once content
    // lands. Tone-aware body so the voice is consistent app-wide.
    unawaited(NotificationService.showActiveWorkout(
      title: 'MyGymBro · Session live',
      body: workoutInProgressBodyForTone(_notificationTone),
      startedAt: now,
    ));

    // iOS Live Activity — lock-screen + Dynamic Island. No-op everywhere
    // else (Android, simulator without widget target, Live Activities
    // disabled in Settings).
    unawaited(LiveActivityService.start(
      exerciseName: _liveActivityExerciseName(),
      setProgress: _setProgressLabel(),
      sessionStartedAt: now,
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
      // Bug fix: with exercises now loaded, immediately upgrade the
      // generic "Workout in progress" notification fired at session start
      // to the named "Exercise · Set 1/N" view so the user doesn't see a
      // stale generic notification while their session is set up.
      unawaited(_refreshExerciseImage());
      _updateActiveSetNotification();
    }
  }

  /// Add an exercise by its exerciseId string.
  ///
  /// Auto-fills sets from the user's most recently completed session for
  /// this exercise. Falls back to a single empty set when no history exists.
  Future<void> addExercise(String exerciseId) async {
    // Cache-on-log: pull this exercise into the local cache if it isn't there
    // yet (online), so it (and its gif/muscle data) resolve offline later.
    // Best-effort and a no-op when already cached or offline.
    if (_exerciseRepo != null) {
      await _exerciseRepo.ensureCached([exerciseId]);
    }

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
    // "Set X of N" in the ongoing notification needs to reflect the new
    // total so it doesn't lie about progress.
    if (!state.showRestTimer) _updateActiveSetNotification();
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
    // Refresh "Set X of N" so the ongoing notification reflects the new
    // total. Skip while a rest timer is showing — that notification has
    // its own progress bar.
    if (!state.showRestTimer) _updateActiveSetNotification();
  }

  /// Update a set's fields (strength or cardio).
  ///
  /// Each `*Str` parameter follows this contract:
  ///   - `null` → field unchanged (caller didn't touch it)
  ///   - non-null (including `""`) → field was edited; the parsed value
  ///     (which may itself be `null`) is the new value, **including a null
  ///     value clearing the field**.
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

    Patch<double?> weight = const Patch.unchanged();
    Patch<int?> reps = const Patch.unchanged();
    Patch<int?> durationSeconds = const Patch.unchanged();
    Patch<double?> distance = const Patch.unchanged();
    Patch<double?> speed = const Patch.unchanged();
    Patch<double?> incline = const Patch.unchanged();

    if (weightStr != null) {
      var parsed = InputSanitiser.parseWeight(weightStr);
      if (_weightUnit == 'lbs' && parsed != null) parsed = parsed / _kLbsPerKg;
      weight = Patch.set(parsed);
    }
    if (repsStr != null) {
      reps = Patch.set(InputSanitiser.parseReps(repsStr));
    }
    if (durationStr != null) {
      final minutes =
          double.tryParse(durationStr.replaceAll(RegExp('[^0-9.]'), ''));
      durationSeconds = Patch.set(
        (minutes != null && minutes >= 0 && minutes <= 999)
            ? (minutes * 60).round()
            : null,
      );
    }
    if (distanceStr != null) {
      var d = double.tryParse(distanceStr.replaceAll(RegExp('[^0-9.]'), ''));
      if (d != null && (d < 0 || d > 9999)) d = null;
      distance = Patch.set(d);
    }
    if (speedStr != null) {
      var sp = double.tryParse(speedStr.replaceAll(RegExp('[^0-9.]'), ''));
      if (sp != null && (sp < 0 || sp > 9999)) sp = null;
      speed = Patch.set(sp);
    }
    if (inclineStr != null) {
      var inc = double.tryParse(inclineStr.replaceAll(RegExp('[^0-9.]'), ''));
      if (inc != null && (inc < 0 || inc > 90)) inc = null;
      incline = Patch.set(inc);
    }

    // Build the new in-memory ActiveSet by hand so cleared (Patch.set(null))
    // fields actually clear rather than fall back to the prior value (which
    // is what `?? s.weight` would do).
    final updatedSets = ex.sets.map((s) {
      if (s.localId != setLocalId) return s;
      return ActiveSet(
        localId: s.localId,
        setIndex: s.setIndex,
        isWarmup: s.isWarmup,
        isDropset: s.isDropset,
        isFailure: s.isFailure,
        isCompleted: s.isCompleted,
        weight: weight.present ? weight.value : s.weight,
        reps: reps.present ? reps.value : s.reps,
        durationSeconds:
            durationSeconds.present ? durationSeconds.value : s.durationSeconds,
        distance: distance.present ? distance.value : s.distance,
        speed: speed.present ? speed.value : s.speed,
        incline: incline.present ? incline.value : s.incline,
      );
    }).toList();

    _updateExercise(ex.copyWith(sets: updatedSets));

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
    // If the user edited the next-active set's weight/reps, the ongoing
    // notification's "Xkg · Y reps" line is now stale.
    if (!state.showRestTimer &&
        (weight.present || reps.present)) {
      _updateActiveSetNotification();
    }
  }

  /// Change the type of a set (warm-up / normal / failure / drop-set).
  Future<void> updateSetType(int setLocalId, SetType type) async {
    for (final ex in state.exercises) {
      final idx = ex.sets.indexWhere((s) => s.localId == setLocalId);
      if (idx < 0) continue;

      // Superset is stored as isDropset + isFailure (see SetType docs).
      final asDropset = type == SetType.dropset || type == SetType.superset;
      final asFailure = type == SetType.failure || type == SetType.superset;
      final updatedSets = ex.sets.map((s) {
        if (s.localId != setLocalId) return s;
        return s.copyWith(
          isWarmup: type == SetType.warmUp,
          isDropset: asDropset,
          isFailure: asFailure,
        );
      }).toList();
      _updateExercise(ex.copyWith(sets: updatedSets));

      await _repository.updateSetType(UpdateSetTypeParams(
        sessionExerciseId: ex.sessionExerciseId,
        setLocalId: setLocalId,
        isWarmup: type == SetType.warmUp,
        isDropset: asDropset,
        isFailure: asFailure,
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

    // Persist completion so a process kill mid-session doesn't lose ticks.
    unawaited(_repository.setCompletion(
      sessionExerciseId: ex.sessionExerciseId,
      setLocalId: setLocalId,
      isCompleted: true,
    ));

    // Haptic
    unawaited(HapticFeedback.mediumImpact());

    // Start rest timer
    state = state.copyWith(showRestTimer: true);
    restTimerService.start(
      seconds: _defaultRestSeconds,
      onComplete: _onRestComplete,
      soundEnabled: _restSoundEnabled,
      vibrationEnabled: _restVibrationEnabled,
      notificationTitle: _restNotificationTitle,
      notificationBody: _restNotificationBody,
    );

    // Push the iOS Live Activity into "resting" mode with a countdown that
    // expires at the same moment the rest timer does. SwiftUI ticks the
    // countdown on-device so we don't need per-second updates here.
    unawaited(LiveActivityService.updateRest(
      exerciseName: _liveActivityExerciseName(),
      setProgress: _setProgressLabel(),
      restEndsAt: DateTime.now().add(Duration(seconds: _defaultRestSeconds)),
    ));

    // Subscribe to the tick stream so the notification updates every second.
    _restTickSub?.cancel();
    _restTickSub = restTimerService.stream?.listen(_updateRestTimerNotification);
  }

  /// Un-mark a completed set (mis-tap recovery). Does not touch the rest
  /// timer — if one is running it keeps counting.
  Future<void> uncompleteSet(int setLocalId) async {
    final ex = state.currentExercise;
    if (ex == null) return;

    final updatedSets = ex.sets.map((s) {
      if (s.localId == setLocalId) {
        return s.copyWith(isCompleted: false);
      }
      return s;
    }).toList();
    _updateExercise(ex.copyWith(sets: updatedSets));

    unawaited(_repository.setCompletion(
      sessionExerciseId: ex.sessionExerciseId,
      setLocalId: setLocalId,
      isCompleted: false,
    ));
    if (!state.showRestTimer) _updateActiveSetNotification();
  }

  void _onRestComplete() {
    _restTickSub?.cancel();
    _restTickSub = null;
    state = state.copyWith(showRestTimer: false);
    // Switch the notification back to the "active set" state.
    _updateActiveSetNotification();
    // Flip the Live Activity back to "active" so the lock screen stops
    // counting down and shows session elapsed time again.
    unawaited(LiveActivityService.updateActive(
      exerciseName: _liveActivityExerciseName(),
      setProgress: _setProgressLabel(),
    ));
  }

  /// Pause the entire session. Halts the rest timer (if running), tracks
  /// the pause start so finishSession can subtract paused time, and
  /// cancels the ongoing notification + Live Activity so they don't keep
  /// counting through the pause.
  void pause() {
    if (state.isPaused) return;
    if (restTimerService.isRunning) {
      restTimerService.pause();
    }
    unawaited(NotificationService.cancelActiveWorkout());
    unawaited(LiveActivityService.end());
    state = state.copyWith(pausedAt: DateTime.now());
  }

  /// Resume a paused session. Restores the rest timer, the ongoing
  /// notification, and Live Activity. Pause duration is folded into
  /// `accumulatedPausedSeconds`.
  void resume() {
    final pausedAt = state.pausedAt;
    if (pausedAt == null) return;
    final pausedSeconds =
        DateTime.now().difference(pausedAt).inSeconds.clamp(0, 1 << 30);
    state = state.copyWith(
      clearPausedAt: true,
      accumulatedPausedSeconds:
          state.accumulatedPausedSeconds + pausedSeconds,
    );
    if (restTimerService.isPaused) {
      restTimerService.resume();
    }
    // Rebuild the ongoing notification + Live Activity in their current
    // logical state (rest vs. active).
    if (state.showRestTimer) {
      _updateRestTimerNotification(restTimerService.remaining);
    } else {
      _updateActiveSetNotification();
    }
    final startedAt = state.startedAt;
    if (startedAt != null) {
      unawaited(LiveActivityService.start(
        exerciseName: _liveActivityExerciseName(),
        setProgress: _setProgressLabel(),
        sessionStartedAt: startedAt,
      ));
    }
  }

  void hideRestTimer() {
    _restTickSub?.cancel();
    _restTickSub = null;
    restTimerService.cancel();
    state = state.copyWith(showRestTimer: false);
    // Switch the notification back to the "active set" state.
    _updateActiveSetNotification();
    unawaited(LiveActivityService.updateActive(
      exerciseName: _liveActivityExerciseName(),
      setProgress: _setProgressLabel(),
    ));
  }

  /// Switch to a different exercise.
  void selectExercise(int index) {
    if (index >= 0 && index < state.exercises.length) {
      state = state.copyWith(currentExerciseIndex: index);
      // Refresh the cached notification largeIcon for the new exercise.
      unawaited(_refreshExerciseImage());
      // Keep the lock-screen exercise name in sync. Only refresh when
      // we're NOT mid-rest; the rest countdown owns the activity until
      // it completes.
      if (!state.showRestTimer) {
        _updateActiveSetNotification();
        unawaited(LiveActivityService.updateActive(
          exerciseName: _liveActivityExerciseName(),
          setProgress: _setProgressLabel(),
        ));
      }
    }
  }

  /// Finish the session.
  Future<void> finishSession() async {
    if (state.sessionId == null) return;
    state = state.copyWith(isFinishing: true);

    final now = DateTime.now();
    // Subtract paused time from total wall-clock duration. If the user is
    // mid-pause when finishing, fold the in-flight pause delta in too so
    // the persisted duration matches what the UI was showing.
    final wallClock = now.difference(state.startedAt!).inSeconds;
    final inFlightPause = state.pausedAt == null
        ? 0
        : now.difference(state.pausedAt!).inSeconds;
    final durationSecs = (wallClock -
            state.accumulatedPausedSeconds -
            inFlightPause)
        .clamp(0, wallClock);

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
    // Dismiss the lock-screen Live Activity. Safe no-op everywhere except
    // iOS 16.1+ with the widget extension installed.
    unawaited(LiveActivityService.end());

    // Schedule a daily workout reminder for tomorrow using rest-day-aware copy.
    unawaited(NotificationService.scheduleWorkoutReminder(
      title: _workoutReminderTitle,
      body: _workoutReminderBody,
    ));

    // Nudge the home-screen widget so today's session shows up
    // immediately rather than waiting for the next provider refresh.
    // Read the live streak (now includes today's just-finished session)
    // so the widget shows the correct count immediately.
    var streakDays = 0;
    if (_getStreak != null) {
      try {
        streakDays = await _getStreak();
      } catch (_) {
        // Fall back to 0; the ambient widgetSyncProvider listener will
        // overwrite once Drift re-reads.
      }
    }
    unawaited(WidgetSyncService.pushAll(
      streakDays: streakDays,
      nextCta: 'Workout logged. See you next session.',
    ));

    // Reset state so a subsequent session starts clean.
    _lastLoggedCache.clear();
    state = const ActiveSessionState();
  }

  /// Discard the session. Deletes the orphan DB row + all its session
  /// exercises and sets so nothing is left behind for history/stats.
  Future<void> discardSession() async {
    _restTickSub?.cancel();
    _restTickSub = null;
    restTimerService.dispose();
    _lastLoggedCache.clear();
    final sessionId = state.sessionId;
    if (sessionId != null) {
      try {
        await _repository.deleteSession(sessionId);
      } catch (_) {
        // Swallow — even if delete fails the orphan row is harmless
        // (finishedAt is null so it's filtered out of history/streak).
      }
    }
    unawaited(NotificationService.cancelActiveWorkout());
    unawaited(LiveActivityService.end());
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

  void updateSettings({
    int? restSeconds,
    String? weightUnit,
    bool? restSoundEnabled,
    bool? restVibrationEnabled,
  }) {
    if (restSeconds != null) _defaultRestSeconds = restSeconds;
    if (weightUnit != null) _weightUnit = weightUnit;
    if (restSoundEnabled != null) _restSoundEnabled = restSoundEnabled;
    if (restVibrationEnabled != null) {
      _restVibrationEnabled = restVibrationEnabled;
    }
  }

  String get weightUnit => _weightUnit;

  /// Default rest duration, for UI that surfaces the rest timer.
  int get defaultRestSeconds => _defaultRestSeconds;

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
    final startedAt = state.startedAt;
    if (startedAt == null) return;

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
      sessionStartedAt: startedAt,
      tagline: activeSetTaglineForTone(_notificationTone),
      exerciseImagePath: _currentExerciseImagePath,
    ));
  }

  /// Push the "rest timer" notification (State B) with a progress bar.
  void _updateRestTimerNotification(int remaining) {
    final ex = state.currentExercise;
    if (ex == null) return;
    final startedAt = state.startedAt;
    if (startedAt == null) return;

    final nextSet = ex.sets.where((s) => !s.isCompleted).firstOrNull;
    // When this is the final set, [nextSet] is null. Pass null through so
    // the notification body shows "Final set complete" instead of the
    // misleading "Set N/N (… × 0 reps)" we used to ship.
    final nextNum = nextSet != null ? nextSet.setIndex + 1 : null;
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
      sessionStartedAt: startedAt,
      tagline: restCountdownTaglineForTone(_notificationTone),
      exerciseImagePath: _currentExerciseImagePath,
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
    exerciseRepository: ref.read(exerciseRepositoryProvider),
    defaultRestSeconds: profile?.defaultRestSeconds ?? 90,
    weightUnit: profile?.weightUnit ?? 'kg',
    restSoundEnabled: ref.read(restTimerSoundEnabledProvider),
    restVibrationEnabled: ref.read(restTimerVibrationEnabledProvider),
    getStreak: () {
      // Invalidate the cached streak so the just-finished session counts,
      // then read the fresh value.
      ref.invalidate(streakProvider);
      return ref.read(streakProvider.future);
    },
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

  // Keep the rest-timer sound/vibration toggles in sync mid-session.
  ref
    ..listen(restTimerSoundEnabledProvider, (_, enabled) {
      notifier.updateSettings(restSoundEnabled: enabled);
    })
    ..listen(restTimerVibrationEnabledProvider, (_, enabled) {
      notifier.updateSettings(restVibrationEnabled: enabled);
    });

  return notifier;
});
