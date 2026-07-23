import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';

/// User-claimed rest days — a "streak freeze" the user can spend from
/// Settings on a day they don't train so the gap doesn't kill the streak.
///
/// Claimed days never *add* to the streak (the count stays honest: training
/// days only); they are simply excluded from the workout-free runs that
/// the streak provider measures against the gap allowance.
///
/// Stored locally in SecureStorage (like the other non-profile settings) as
/// a comma-separated list of `yyyy-MM-dd` local-day keys — no DB migration,
/// no sync. History is kept indefinitely: a pass claimed months ago still
/// has to cover its gap when the streak walk reaches it, and at ~11 bytes
/// per claim the storage cost is negligible.

/// How many rest days the user may claim per calendar week (Monday-anchored,
/// the same week window as every other weekly metric in the app).
const int kRestDaysPerWeek = 2;

const String _kStorageKey = 'setting_rest_day_passes';

/// Canonical storage key for a local calendar day.
String restDayKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

class RestDayPassesNotifier extends StateNotifier<Set<String>> {
  RestDayPassesNotifier() : super(const {}) {
    ready = _load();
  }

  /// Test constructor: seeds the state and skips the storage read.
  @visibleForTesting
  RestDayPassesNotifier.seeded(super.initial) {
    ready = Future.value();
  }

  /// Completes once the persisted claims are in [state]. Never rejects —
  /// a failed read just means no claims.
  late final Future<void> ready;

  Future<void> _load() async {
    try {
      final raw = await SecureStorage().read(_kStorageKey);
      if (raw == null || raw.isEmpty) return;
      state = raw.split(',').where((k) => k.isNotEmpty).toSet();
    } on Object catch (_) {
      // Storage unavailable (unit tests) or unreadable — treat as none.
    }
  }

  /// Number of rest days claimed in the Monday-anchored week containing
  /// [at] (defaults to now).
  int usedThisWeek([DateTime? at]) {
    final now = at ?? DateTime.now();
    // day - (weekday - 1) normalizes via the DateTime constructor, so this
    // is safe across month boundaries and DST transitions.
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    var used = 0;
    for (var i = 0; i < 7; i++) {
      final d = DateTime(monday.year, monday.month, monday.day + i);
      if (state.contains(restDayKey(d))) used++;
    }
    return used;
  }

  int remainingThisWeek([DateTime? at]) =>
      (kRestDaysPerWeek - usedThisWeek(at)).clamp(0, kRestDaysPerWeek);

  bool get claimedToday => state.contains(restDayKey(DateTime.now()));

  /// Claims today as a rest day. Returns false when the weekly quota is
  /// already spent; claiming an already-claimed day is a no-op success.
  Future<bool> claimToday() async {
    await ready;
    final key = restDayKey(DateTime.now());
    if (state.contains(key)) return true;
    if (usedThisWeek() >= kRestDaysPerWeek) return false;
    state = {...state, key};
    try {
      await SecureStorage().write(_kStorageKey, state.join(','));
    } on Object catch (_) {
      // Best-effort persistence: the in-memory claim still protects the
      // streak for this app run.
    }
    return true;
  }
}

/// Set of claimed rest-day keys (`yyyy-MM-dd`). Watch the state for
/// reactivity; use the notifier for [RestDayPassesNotifier.claimToday] and
/// the weekly-quota queries.
final restDayPassesProvider =
    StateNotifierProvider<RestDayPassesNotifier, Set<String>>(
  (ref) => RestDayPassesNotifier(),
);
