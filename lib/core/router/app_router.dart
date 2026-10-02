import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/features/auth/sign_in_screen.dart';
import 'package:my_gym_bro/features/exercises/exercise_browser_screen.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_flow_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/sign_up_screen.dart';
import 'package:my_gym_bro/features/onboarding/screens/splash_screen.dart';
import 'package:my_gym_bro/features/paywall/paywall_screen.dart';
import 'package:my_gym_bro/features/profile/profile_screen.dart';
import 'package:my_gym_bro/features/scaffold/my_gym_bro_scaffold.dart';
import 'package:my_gym_bro/features/schedule/day_detail_screen.dart';
import 'package:my_gym_bro/features/schedule/discover_programs_screen.dart';
import 'package:my_gym_bro/features/schedule/premade_programs_screen.dart';
import 'package:my_gym_bro/features/schedule/schedule_builder_screen.dart';
import 'package:my_gym_bro/features/schedule/share/import_share_screen.dart';
import 'package:my_gym_bro/features/schedule/split_overview_screen.dart';
import 'package:my_gym_bro/features/settings/settings_screen.dart';
import 'package:my_gym_bro/features/social/add_bro_screen.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_screen.dart';
import 'package:my_gym_bro/features/workout/share/exercise_share_data.dart';
import 'package:my_gym_bro/features/workout/share/exercise_share_screen.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/app_error_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ROUTE PATHS
// ═══════════════════════════════════════════════════════════════════════════

/// Route path constants.
class AppRoutes {
  AppRoutes._();

  // Onboarding: splash → the flow (welcome · questionnaire · timeline ·
  // paywall, one screen — see OnboardingFlowScreen) → signup → home.
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const onboardingSignup = '/onboarding/signup';

  // Auth
  static const signIn = '/auth/signin';

  // Main app
  static const home = '/';
  static const settings = '/settings';
  static const exerciseBrowser = '/exercises';
  static const activeSession = '/session';
  static const shareCard = '/session/share';
  static const shareExercise = '/exercise/share';
  static const scheduleBuilder = '/schedule/build';
  static const splitOverview = '/schedule/overview';
  static const dayDetail = '/schedule/day';
  static const premadePrograms = '/programs';
  static const discoverPrograms = '/programs/discover';
  static const paywall = '/paywall';

  // Profile
  static const profile = '/profile';

  // Bros — invite deep-link target (the invite link/QR encodes the username).
  static const addBro = '/bro/:username';

  // Shared routine deep-link target (the share link/QR encodes the code).
  static const importShare = '/s/:code';
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Platform-adaptive push transition, resolved by the app theme's
/// `PageTransitionsTheme` (see `app.dart`): iOS/macOS get the native
/// Cupertino slide + interactive swipe-back, Android gets predictive-back /
/// M3 FadeForwards, desktop gets FadeForwards.
MaterialPage<T> _platformPage<T>({
  required Widget child,
  required GoRouterState state,
}) => MaterialPage<T>(key: state.pageKey, child: child);

/// Crossfade transition — for splash/welcome where a slide feels wrong.
CustomTransitionPage<T> _fadePage<T>({
  required Widget child,
  required GoRouterState state,
  Duration duration = const Duration(milliseconds: 350),
}) => CustomTransitionPage<T>(
  key: state.pageKey,
  child: child,
  transitionDuration: duration,
  reverseTransitionDuration: duration,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(opacity: animation, child: child);
  },
);

/// The onboarding handoff's horizontal push (in from the right over .42s,
/// iOS-like curve). Pop reverses it. Plain fade under reduced motion.
CustomTransitionPage<T> _pushPage<T>({
  required Widget child,
  required GoRouterState state,
}) => CustomTransitionPage<T>(
  key: state.pageKey,
  child: child,
  transitionDuration: AppOnboarding.push,
  reverseTransitionDuration: AppOnboarding.push,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: animation, curve: AppOnboarding.pushCurve),
      ),
      child: child,
    );
  },
);

/// No transition — used for the root scaffold (it's the base, nothing slides).
NoTransitionPage<T> _noTransitionPage<T>({
  required Widget child,
  required GoRouterState state,
}) => NoTransitionPage<T>(key: state.pageKey, child: child);

/// Slide-up transition — iOS fullscreen-dialog feel for modal flows
/// (active session, share card, paywall). Pop reverses it automatically.
/// Collapses to a plain fade when the OS requests reduced motion.
CustomTransitionPage<T> _slideUpPage<T>({
  required Widget child,
  required GoRouterState state,
  Duration duration = const Duration(milliseconds: 350),
}) => CustomTransitionPage<T>(
  key: state.pageKey,
  child: child,
  transitionDuration: duration,
  reverseTransitionDuration: duration,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
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
  final lockNotifier = ValueNotifier<bool>(
    ref.read(subscriptionLockedProvider),
  );
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
    // Unknown route / deep-link → branded error page instead of the default
    // grey exception page. Splash re-runs the normal routing logic.
    errorBuilder: (context, state) =>
        AppErrorScreen(onGoHome: () => context.go(AppRoutes.splash)),
    routes: [
      // ────────────────────────────────────────────────────────────────────
      // ONBOARDING — the flow screen runs its own step-to-step motion; the
      // splash hands over with the same push it uses between steps.
      // ────────────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _fadePage(child: const SplashScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) =>
            _pushPage(child: const OnboardingFlowScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.onboardingSignup,
        pageBuilder: (context, state) =>
            _pushPage(child: const SignUpScreen(), state: state),
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
            _platformPage(child: const SettingsScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.exerciseBrowser,
        pageBuilder: (context, state) => _platformPage(
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
        path: AppRoutes.shareCard,
        // Reached only via context.pushReplacement with a ShareCardData in
        // `extra` (from the finish flow). Deep-linked/refreshed without that
        // data → bounce home rather than crash on a null cast.
        redirect: (context, state) =>
            state.extra is ShareCardData ? null : AppRoutes.home,
        pageBuilder: (context, state) => _slideUpPage(
          child: ShareCardScreen(data: state.extra! as ShareCardData),
          state: state,
        ),
      ),
      GoRoute(
        path: AppRoutes.shareExercise,
        // Reached only via context.push with an ExerciseShareData in `extra`
        // (exercise detail header). Deep-linked/refreshed without that data →
        // bounce home rather than crash on a null cast.
        redirect: (context, state) =>
            state.extra is ExerciseShareData ? null : AppRoutes.home,
        pageBuilder: (context, state) => _slideUpPage(
          child: ExerciseShareScreen(data: state.extra! as ExerciseShareData),
          state: state,
        ),
      ),
      GoRoute(
        path: AppRoutes.scheduleBuilder,
        pageBuilder: (context, state) {
          final scheduleId = state.extra as int?;
          return _platformPage(
            child: ScheduleBuilderScreen(scheduleId: scheduleId),
            state: state,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.splitOverview,
        pageBuilder: (context, state) => _platformPage(
          child: SplitOverviewScreen(scheduleId: state.extra as int?),
          state: state,
        ),
      ),
      GoRoute(
        path: AppRoutes.dayDetail,
        redirect: (context, state) =>
            state.extra is int ? null : AppRoutes.home,
        pageBuilder: (context, state) => _platformPage(
          child: DayDetailScreen(scheduleDayId: state.extra! as int),
          state: state,
        ),
      ),
      GoRoute(
        path: AppRoutes.premadePrograms,
        pageBuilder: (context, state) =>
            _platformPage(child: const PremadeProgramsScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.discoverPrograms,
        pageBuilder: (context, state) =>
            _platformPage(child: const DiscoverProgramsScreen(), state: state),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        pageBuilder: (context, state) =>
            _slideUpPage(child: const PaywallScreen(), state: state),
      ),

      // ────────────────────────────────────────────────────────────────────
      // PROFILE
      // ────────────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) =>
            _platformPage(child: const ProfileScreen(), state: state),
      ),

      // ────────────────────────────────────────────────────────────────────
      // BROS — invite deep link. TODO(deploy): needs the universal-link
      // domain (AASA / assetlinks) configured before external links open the
      // app — see SETUP-STATUS.md. In-app pushes work today.
      GoRoute(
        path: AppRoutes.addBro,
        redirect: (context, state) =>
            (state.pathParameters['username']?.isEmpty ?? true)
                ? AppRoutes.home
                : null,
        pageBuilder: (context, state) => _platformPage(
          child: AddBroScreen(username: state.pathParameters['username']!),
          state: state,
        ),
      ),

      // ────────────────────────────────────────────────────────────────────
      // SHARED ROUTINE — import deep link (same TODO(deploy) universal-link
      // platform work as the Bros invite; the paste-link dialog and in-app
      // pushes work today).
      GoRoute(
        path: AppRoutes.importShare,
        redirect: (context, state) {
          final code =
              state.pathParameters['code']?.trim().toLowerCase() ?? '';
          return RegExp(r'^[a-z0-9]{4,16}$').hasMatch(code)
              ? null
              : AppRoutes.home;
        },
        pageBuilder: (context, state) => _platformPage(
          child: ImportShareScreen(
            code: state.pathParameters['code']!.trim().toLowerCase(),
          ),
          state: state,
        ),
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
      final exempt =
          loc == AppRoutes.paywall ||
          loc == AppRoutes.splash ||
          loc.startsWith('/auth') ||
          loc.startsWith('/onboarding') ||
          // Shared-routine import stays reachable while locked (product
          // decision: importing is free; the gate re-applies on the next
          // route change, so app usage stays paywalled).
          loc.startsWith('/s/');
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
