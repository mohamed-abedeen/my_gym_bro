import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/safe_logger.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_codec.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base of the routine share link; the 8-char share code is appended.
///
/// TODO(deploy): same universal-link platform work as the Bros invite
/// (AASA / assetlinks / web fallback page) — see SETUP-STATUS.md. The in-app
/// `/s/:code` route and the paste-link dialog work without it.
const String kRoutineShareLinkBase = 'https://mygymbro.app/s/';

/// Outcome of creating a share link.
sealed class ShareCreateResult {
  const ShareCreateResult();
}

class ShareCreated extends ShareCreateResult {
  const ShareCreated(this.code, this.link);
  final String code;
  final String link;
}

/// Supabase not configured or device fully offline at init — sharing needs
/// the cloud (accepted product trade-off; the app itself stays offline-first).
class ShareUnavailable extends ShareCreateResult {
  const ShareUnavailable();
}

/// Signed out — share codes are tied to an account.
class ShareSignedOut extends ShareCreateResult {
  const ShareSignedOut();
}

/// Network/server error creating the share.
class ShareFailed extends ShareCreateResult {
  const ShareFailed();
}

/// Nothing shareable (no non-rest exercises).
class ShareEmpty extends ShareCreateResult {
  const ShareEmpty();
}

/// Outcome of fetching a share by code.
sealed class ShareFetchResult {
  const ShareFetchResult();
}

class ShareFetched extends ShareFetchResult {
  const ShareFetched(this.payload);
  final RoutineSharePayload payload;
}

class ShareNotFound extends ShareFetchResult {
  const ShareNotFound();
}

class ShareFetchUnavailable extends ShareFetchResult {
  const ShareFetchUnavailable();
}

class ShareFetchSignedOut extends ShareFetchResult {
  const ShareFetchSignedOut();
}

class ShareFetchFailed extends ShareFetchResult {
  const ShareFetchFailed();
}

class ShareVersionUnsupported extends ShareFetchResult {
  const ShareVersionUnsupported();
}

/// Creates and fetches routine shares (migration 020).
///
/// Both calls are FOREGROUND RPCs, not sync-queue items — the user is
/// waiting for the link/preview, so fire-and-forget durability is wrong
/// here. Each call is time-boxed and degrades to a typed error; nothing
/// ever blocks another screen (offline-first rule).
class RoutineShareService {
  RoutineShareService(AppDatabase db, this._client, this._repo)
      : _scheduleDao = ScheduleDao(db),
        _exerciseDao = ExerciseDao(db);

  final ScheduleDao _scheduleDao;
  final ExerciseDao _exerciseDao;
  final SupabaseClient? _client;
  final ExerciseRepository _repo;

  static const _timeout = Duration(seconds: 10);
  static final _codeRx = RegExp(r'^[a-z0-9]{4,16}$');

  /// Shares a whole program. [fallbackTitle] is used when the schedule name
  /// sanitises to empty (localised by the caller — services stay l10n-free).
  Future<ShareCreateResult> shareSchedule(
    int scheduleId, {
    required String fallbackTitle,
  }) async {
    final schedule = await _scheduleDao.getScheduleById(scheduleId);
    if (schedule == null) return const ShareEmpty();

    final days = await _scheduleDao.getDays(scheduleId);
    final sharedDays = <SharedDay>[];
    for (final day in days) {
      final isRest = isRestScheduleDay(day);
      sharedDays.add(
        SharedDay(
          label: day.label ?? '',
          isRest: isRest,
          exercises: isRest ? const [] : await _snapshotDay(day.localId),
        ),
      );
    }
    return _create(
      RoutineSharePayload(
        kind: RoutineShareKind.program,
        title: schedule.name.trim().isEmpty ? fallbackTitle : schedule.name,
        days: sharedDays,
      ),
    );
  }

  /// Shares a single day as a `day` payload.
  Future<ShareCreateResult> shareDay(
    int scheduleDayId, {
    required String fallbackTitle,
  }) async {
    final day = await _scheduleDao.getDayById(scheduleDayId);
    if (day == null || isRestScheduleDay(day)) return const ShareEmpty();

    var title = (day.label ?? '').trim();
    if (title.isEmpty) {
      final schedule = await _scheduleDao.getScheduleById(day.scheduleId);
      title = schedule?.name.trim() ?? '';
    }
    return _create(
      RoutineSharePayload(
        kind: RoutineShareKind.day,
        title: title.isEmpty ? fallbackTitle : title,
        days: [
          SharedDay(
            label: day.label ?? '',
            isRest: false,
            exercises: await _snapshotDay(day.localId),
          ),
        ],
      ),
    );
  }

  /// Fetches and decodes a share by its code.
  Future<ShareFetchResult> fetchShare(String code) async {
    final client = _client;
    if (client == null) return const ShareFetchUnavailable();
    if (client.auth.currentSession == null) return const ShareFetchSignedOut();
    final normalised = code.trim().toLowerCase();
    if (!_codeRx.hasMatch(normalised)) return const ShareNotFound();

    Object? raw;
    try {
      raw = await client
          .rpc<dynamic>('get_routine_share', params: {'p_code': normalised})
          .timeout(_timeout);
    } on Object catch (e) {
      SafeLogger.log('share fetch failed: ${e.runtimeType}', tag: 'share');
      return const ShareFetchFailed();
    }
    if (raw == null) return const ShareNotFound();
    if (raw is! Map) return const ShareFetchFailed();

    return switch (RoutineSharePayload.decode(raw['payload'])) {
      RoutineShareDecoded(:final payload) => ShareFetched(payload),
      RoutineShareUnsupportedVersion() => const ShareVersionUnsupported(),
      RoutineShareMalformed() => const ShareFetchFailed(),
    };
  }

  /// Best-effort import counter — never surfaces errors.
  Future<void> markImported(String code) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return;
    try {
      await client
          .rpc<dynamic>(
            'increment_share_import',
            params: {'p_code': code.trim().toLowerCase()},
          )
          .timeout(_timeout);
    } on Object {
      // Counter only — losing it is fine.
    }
  }

  Future<List<SharedExercise>> _snapshotDay(int scheduleDayId) async {
    final scheduled = await _scheduleDao.getExercises(scheduleDayId);
    if (scheduled.isEmpty) return const [];

    final ids = scheduled.map((s) => s.exerciseId).toSet().toList();
    final byId = {
      for (final e in await _exerciseDao.findByExerciseIds(ids))
        e.exerciseId: e,
    };
    final result = <SharedExercise>[];
    for (final s in scheduled) {
      var row = byId[s.exerciseId];
      if (row == null) {
        // Library row missing locally (cleared cache) — best-effort backfill
        // so the payload carries a real name for the recipient.
        try {
          row = await _repo.getById(s.exerciseId);
        } on Object {
          row = null;
        }
      }
      result.add(
        SharedExercise(
          exerciseId: s.exerciseId,
          // Falls back to the id; the recipient's id-first resolution and
          // the codec's `custom_*` stripping handle the rest.
          name: row?.name ?? s.exerciseId,
          muscleGroup: row?.muscleGroup,
          sets: s.targetSets,
          reps: s.targetReps,
          durationSeconds: s.targetDurationSeconds,
          distance: s.targetDistance,
        ),
      );
    }
    return result;
  }

  Future<ShareCreateResult> _create(RoutineSharePayload payload) async {
    if (payload.exerciseCount == 0) return const ShareEmpty();
    final client = _client;
    if (client == null) return const ShareUnavailable();
    if (client.auth.currentSession == null) return const ShareSignedOut();

    try {
      final code = await client
          .rpc<dynamic>('create_routine_share', params: {'p': payload.toJson()})
          .timeout(_timeout);
      if (code is! String || !_codeRx.hasMatch(code)) {
        return const ShareFailed();
      }
      return ShareCreated(code, '$kRoutineShareLinkBase$code');
    } on Object catch (e) {
      // Never log the payload — it's user content.
      SafeLogger.log('share create failed: ${e.runtimeType}', tag: 'share');
      return const ShareFailed();
    }
  }
}

final routineShareServiceProvider = Provider<RoutineShareService>(
  (ref) => RoutineShareService(
    ref.watch(databaseProvider),
    ref.watch(supabaseProvider),
    ref.watch(exerciseRepositoryProvider),
  ),
);
