import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/features/auth/sign_in_screen.dart';
import 'package:my_gym_bro/features/exercises/exercise_browser_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/birthday_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/experience_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/gender_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/goal_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/height_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/language_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/notification_tone_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/sign_up_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/splash_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/target_zones_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/trial_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/weight_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/welcome_screen.dart';
import 'package:my_gym_bro/features/paywall/paywall_screen.dart';
import 'package:my_gym_bro/features/profile/profile_screen.dart';
import 'package:my_gym_bro/features/scaffold/my_gym_bro_scaffold.dart';
import 'package:my_gym_bro/features/schedule/schedule_builder_screen.dart';
import 'package:my_gym_bro/features/settings/settings_screen.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ROUTE PATHS
// ═══════════════════════════════════════════════════════════════════════════

/// Route path constants.
class AppRoutes {
  AppRoutes._();

  // Onboarding flow:
  // splash → welcome → gender → goal → experience → birthday →
  // weight → height → target-zones → signup → trial → home
  static const splash = '/splash';
  static const onboardingWelcome = '/onboarding/welcome';
  static const onboardingGender = '/onboarding/gender';
  static const onboardingGoal = '/onboarding/goal';
  static const onboardingExperience = '/onboarding/experience';
  static const onboardingBirthday = '/onboarding/birthday';
  static const onboardingWeight = '/onboarding/weight';
  static const onboardingHeight = '/onboarding/height';
  static const onboardingTargetZones = '/onboarding/target-zones';
  static const onboardingNotificationTone = '/onboarding/notification-tone';
  static const onboardingLanguage = '/onboarding/language';
  static const onboardingSignup = '/onboarding/signup';
  static const onboardingTrial = '/onboarding/trial';

  // Auth
  static const signIn = '/auth/signin';

  // Main app
  static const home = '/';
  static const settings = '/settings';
  static const exerciseBrowser = '/exercises';
  static const activeSession = '/session';
  static const scheduleBuilder = '/schedule/build';
  static const paywall = '/paywall';

  // Profile
  static const profile = '/profile';
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// iOS-native slide transition with parallax + interactive swipe-back.
/// This is the same transition UINavigationController uses on real iPhones.
CupertinoPage<T> _cupertinoPage<T>({
  required Widget child,
  required GoRouterState state,
}) =>
    CupertinoPage<T>(
      key: state.pageKey,
      child: child,
    );

/// Crossfade transition — for splash/welcome where a slide feels wrong.
CustomTransitionPage<T> _fadePage<T>({
  required Widget child,
  required GoRouterState state,
  Duration duration = const Duration(milliseconds: 350),
}) =>
    CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );

/// No transition — used for the root scaffold (it's the base, nothing slides).
NoTransitionPage<T> _noTransitionPage<T>({
  required Widget child,
  required GoRouterState state,
}) =>
    NoTransitionPage<T>(
      key: state.pageKey,
      child: child,
    );

/// Slide-up transition — for modals like active session, paywall.
CustomTransitionPage<T> _slideUpPage<T>({
  required Widget child,
  required GoRouterState state,
  Duration duration = const Duration(milliseconds: 400),
}) =>
    CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );

// ═══════════════════════════════════════════════════════════════════════════
// ROUTER PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Global handle to the live GoRouter — populated by [routerProvider] the
/// first time it's built and cleared on app teardown. Used by code paths
/// that don't have access to a `BuildContext` (notification handlers,
/// background isolate dispatches) to deep-link into the app.
///
/// Prefer `context.go(...)` / `ref.read(routerProvider).go(...)` from
/// widget code — this exists only as an escape hatch for background flows.
GoRouter? globalRouter;

/// GoRouter provider.
final routerProvider = Provider<GoRouter>((ref) {
  // Bridges the Riverpod lock state into a Listenable so GoRouter re-runs its
  // redirect when the trial elapses or a purchase/restore unlocks access.
  final lockNotifier =
      ValueNotifier<bool>(ref.read(subscriptionLockedProvider));
  ref.listen<bool>(subscriptionLockedProvider, (_, next) {
    lockNotifier.value = next;
  });
  ref.onDispose(lockNotifier.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: lockNotifier,
    // Lets the native iOS CNTabBar auto-hide under bottom sheets/modals so its
    // UIView z-order doesn't cover Flutter-rendered sheet content. Harmless on
    // other platforms (just counts modal depth; the native bar isn't used).
    observers: [CNTabBarRouteObserver()],
    routes: [
      // ────────────────────────────────────────────────────────────────────
      // ONBOARDING — fade transitions (they're a linear wizard, not a stack)
      // ────────────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _fadePage(child: const SplashScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingWelcome,
        pageBuilder: (context, state) =>
            _fadePage(child: const WelcomeScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingGender,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const GenderScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingGoal,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const GoalScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingExperience,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const ExperienceScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingBirthday,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const BirthdayScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingWeight,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const WeightScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingHeight,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const HeightScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingTargetZones,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const TargetZonesScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingNotificationTone,
        pageBuilder: (context, state) => _cupertinoPage(
            child: const NotificationToneScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingLanguage,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const LanguageScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingSignup,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const SignUpScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingTrial,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const TrialScreen(), state: state),
      ),

      // ────────────────────────────────────────────────────────────────────
      // AUTH
      // ────────────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.signIn,
        pageBuilder: (context, state) =>
            _fadePage(child: const SignInScreen(), state: state),
      ),

      // ────────────────────────────────────────────────────────────────────
      // MAIN APP — root scaffold has no transition; children slide iOS-style
      // ────────────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) =>
            _noTransitionPage(child: const MyGymBroScaffold(), state: state),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const SettingsScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.exerciseBrowser,
        pageBuilder: (context, state) => _cupertinoPage(
          child: const ExerciseBrowserScreen(pickMode: true),
          state: state,
        ),
      ),
      GoRoute(
        path: AppRoutes.activeSession,
        pageBuilder: (context, state) {
          final scheduleDayId = state.extra as int?;
          return _slideUpPage(
            child: ActiveSessionScreen(scheduleDayId: scheduleDayId),
            state: state,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.scheduleBuilder,
        pageBuilder: (context, state) {
          final scheduleId = state.extra as int?;
          return _cupertinoPage(
            child: ScheduleBuilderScreen(scheduleId: scheduleId),
            state: state,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.paywall,
        pageBuilder: (context, state) => _slideUpPage(
          child: const PaywallScreen(),
          state: state,
        ),
      ),

      // ────────────────────────────────────────────────────────────────────
      // PROFILE
      // ────────────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) =>
            _cupertinoPage(child: const ProfileScreen(), state: state),
      ),
    ],
    // ──────────────────────────────────────────────────────────────────────
    // PAYWALL GATE — single source of truth. When the trial has elapsed or
    // the subscription is expired, every route except the paywall itself and
    // the pre-auth/onboarding flow is redirected to the paywall, so the app
    // cannot be used until the user subscribes or restores.
    // ──────────────────────────────────────────────────────────────────────
    redirect: (context, state) {
      final locked = ref.read(subscriptionLockedProvider);
      if (!locked) return null;
      final loc = state.matchedLocation;
      final exempt = loc == AppRoutes.paywall ||
          loc == AppRoutes.splash ||
          loc.startsWith('/auth') ||
          loc.startsWith('/onboarding');
      return exempt ? null : AppRoutes.paywall;
    },
  );

  // Publish for background callers (notification taps, isolate handlers).
  globalRouter = router;
  ref.onDispose(() {
    if (identical(globalRouter, router)) globalRouter = null;
  });
  return router;
});
