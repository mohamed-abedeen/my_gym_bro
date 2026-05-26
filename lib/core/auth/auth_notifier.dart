import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/security/input_sanitiser.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/shared/app_constants.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication state.
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

@immutable
class AppAuthState {

  const AppAuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.user,
  });
  final AuthStatus status;
  final String? errorMessage;
  final User? user;

  AppAuthState copyWith({AuthStatus? status, String? errorMessage, User? user}) =>
      AppAuthState(
        status: status ?? this.status,
        errorMessage: errorMessage,
        user: user ?? this.user,
      );
}

/// Auth notifier — handles sign-up, sign-in, sign-out, and social auth.
class AuthNotifier extends StateNotifier<AppAuthState> {

  AuthNotifier(this._db, this._supabase, this._syncService)
      : super(const AppAuthState()) {
    // OAuth (Google/Apple) returns from signInWithOAuth before the session
    // exists — the real login arrives via the deep-link callback. Subscribe
    // here so the state transitions to authenticated whenever Supabase
    // actually has a session, regardless of which flow produced it.
    final sb = _supabase;
    if (sb != null) {
      _authSub = sb.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        switch (data.event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
          case AuthChangeEvent.initialSession:
            if (user != null) {
              // RevenueCat login — fire-and-forget; don't block auth state.
              unawaited(_revenueCatLogin(user.id));
              unawaited(_syncService.syncAll());
              state = state.copyWith(
                status: AuthStatus.authenticated,
                user: user,
              );
            }
          case AuthChangeEvent.signedOut:
            state = const AppAuthState(status: AuthStatus.unauthenticated);
          case AuthChangeEvent.mfaChallengeVerified:
          case AuthChangeEvent.passwordRecovery:
          // ignore: deprecated_member_use -- userDeleted was removed in Supabase v2; kept to satisfy the exhaustive switch until the SDK drops this enum value.
          case AuthChangeEvent.userDeleted:
            break;
        }
      });
    }
  }
  final AppDatabase _db;
  final SupabaseClient? _supabase;
  final SyncService _syncService;
  StreamSubscription<AuthState>? _authSub;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _revenueCatLogin(String userId) async {
    try {
      await Purchases.logIn(userId);
    } on Exception catch (e) {
      CrashReporter.recordError(e, reason: 'RevenueCat logIn failed');
    }
  }

  // ──────────────────────────────────────────────
  // Sign Up
  // ──────────────────────────────────────────────
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String? goal,
    String? experience,
    String? gender,
    String notificationTone = AppConstants.defaultNotificationTone,
  }) async {
    if (_supabase == null) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: 'Not connected to server');
      return;
    }
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final cleanName = InputSanitiser.sanitise(name, maxLength: 100);
      final cleanEmail = email.trim().toLowerCase();

      // Supabase sign up
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'display_name': cleanName},
      );
      final user = response.user;
      if (user == null) {
        state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Sign up failed — no user returned.');
        return;
      }

      // Create local user profile
      final now = DateTime.now();
      final dao = UserProfileDao(_db);
      await dao.upsert(UserProfilesCompanion(
        remoteId: Value(user.id),
        displayName: Value(cleanName),
        goal: Value(goal),
        experience: Value(experience),
        gender: Value(gender),
        notificationTone: Value(notificationTone),
        trialStartedAt: Value(now),
        subscriptionStatus: const Value('trial'),
        subscriptionExpiresAt: Value(now.add(const Duration(days: AppConstants.trialDurationDays))),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      // Write exercise seed flag
      await SecureStorage().write('needs_exercise_seed', 'true');

      // RevenueCat login
      try {
        await Purchases.logIn(user.id);
      } on Exception catch (e) {
        CrashReporter.recordError(e, reason: 'RevenueCat logIn failed');
      }

      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } on Exception catch (e) {
      state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: _friendlyError(e));
    }
  }

  // ──────────────────────────────────────────────
  // Sign In
  // ──────────────────────────────────────────────
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      if (_supabase == null) {
        state = state.copyWith(
            status: AuthStatus.error, errorMessage: 'Not connected to server');
        return;
      }
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Sign in failed.');
        return;
      }

      // RevenueCat login
      try {
        await Purchases.logIn(user.id);
      } on Exception catch (e) {
        CrashReporter.recordError(e, reason: 'RevenueCat logIn failed');
      }

      // Sync
      unawaited(_syncService.syncAll());

      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } on Exception catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _friendlyError(e));
    }
  }

  // ──────────────────────────────────────────────
  // Sign Out
  // ──────────────────────────────────────────────
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      try {
        await Purchases.logOut();
      } on Exception catch (e) {
        CrashReporter.recordError(e, reason: 'RevenueCat logOut failed');
      }
      await _supabase?.auth.signOut();
      await SecureStorage().clearTokens();
      state = const AppAuthState(status: AuthStatus.unauthenticated);
    } on Exception catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  // ──────────────────────────────────────────────
  // Social Auth
  // ──────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    if (_supabase == null) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: 'Not connected to server');
      return;
    }
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // Kicks off the external browser flow and returns immediately. The
      // session lands asynchronously via the deep-link callback and is
      // handled by the onAuthStateChange subscription in the constructor.
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConstants.oauthRedirectUri,
      );
    } on Exception catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> signInWithApple() async {
    if (!Platform.isIOS || _supabase == null) return;
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // See signInWithGoogle — auth completes via the deep-link callback,
      // picked up by the onAuthStateChange listener.
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: AppConstants.oauthRedirectUri,
      );
    } on Exception catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  // ──────────────────────────────────────────────
  // Reset Password
  // ──────────────────────────────────────────────
  Future<bool> resetPassword(String email) async {
    try {
      if (_supabase == null) return false;
      await _supabase.auth.resetPasswordForEmail(email.trim().toLowerCase());
      return true;
    } on Exception catch (e) {
      CrashReporter.recordError(e, reason: 'Reset password failed');
      return false;
    }
  }

  /// Convert raw exceptions to user-friendly messages.
  static String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('no address associated')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('timeout')) {
      return 'Connection timed out. Please try again.';
    }
    if (msg.contains('unsupported provider') ||
        msg.contains('provider is not enabled')) {
      return 'This sign-in method is not enabled yet. Please use email instead.';
    }
    return 'Something went wrong. Please try again.';
  }
}
