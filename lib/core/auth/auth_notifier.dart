import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/daos/user_profile_dao.dart';
import '../security/input_sanitiser.dart';
import '../security/secure_storage.dart';
import '../services/sync_service.dart';

/// Authentication state.
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

@immutable
class AppAuthState {
  final AuthStatus status;
  final String? errorMessage;
  final User? user;

  const AppAuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.user,
  });

  AppAuthState copyWith({AuthStatus? status, String? errorMessage, User? user}) =>
      AppAuthState(
        status: status ?? this.status,
        errorMessage: errorMessage,
        user: user ?? this.user,
      );
}

/// Auth notifier — handles sign-up, sign-in, sign-out, and social auth.
class AuthNotifier extends StateNotifier<AppAuthState> {
  final AppDatabase _db;
  final SupabaseClient? _supabase;
  final SyncService _syncService;

  AuthNotifier(this._db, this._supabase, this._syncService)
      : super(const AppAuthState());

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
        trialStartedAt: Value(now),
        subscriptionStatus: const Value('trial'),
        subscriptionExpiresAt: Value(now.add(const Duration(days: 7))),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      // Write exercise seed flag
      await SecureStorage().write('needs_exercise_seed', 'true');

      // RevenueCat login
      try {
        await Purchases.logIn(user.id);
      } catch (e) {
        if (kDebugMode) debugPrint('RevenueCat logIn failed: $e');
      }

      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
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
      } catch (e) {
        if (kDebugMode) debugPrint('RevenueCat logIn failed: $e');
      }

      // Sync
      unawaited(_syncService.syncAll());

      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
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
      } catch (e) {
        if (kDebugMode) debugPrint('RevenueCat logOut failed: $e');
      }
      await _supabase?.auth.signOut();
      await SecureStorage().clearTokens();
      state = const AppAuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
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
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.mygymbro://callback',
      );
      final user = _supabase.auth.currentUser;
      if (user != null) {
        try {
          await Purchases.logIn(user.id);
        } catch (e) {
          if (kDebugMode) debugPrint('RevenueCat logIn failed: $e');
        }
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      }
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> signInWithApple() async {
    if (!Platform.isIOS || _supabase == null) return;
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.mygymbro://callback',
      );
      final user = _supabase.auth.currentUser;
      if (user != null) {
        try {
          await Purchases.logIn(user.id);
        } catch (e) {
          if (kDebugMode) debugPrint('RevenueCat logIn failed: $e');
        }
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      }
    } catch (e) {
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
    } catch (e) {
      if (kDebugMode) debugPrint('Reset password failed: $e');
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
