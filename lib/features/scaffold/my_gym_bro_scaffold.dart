import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/services/subscription_sync_service.dart';
import 'package:my_gym_bro/features/community/community_screen.dart';
import 'package:my_gym_bro/features/home/home_screen.dart';
import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/leaderboard/rank_up_overlay.dart';
import 'package:my_gym_bro/features/workout/achievement_planner.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/features/workout/workout_screen.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/bottom_nav_pill.dart';
import 'package:my_gym_bro/shared/widgets/ios_native_nav.dart';

/// Main app scaffold — animated tab switching with floating nav pill.
///
/// Pages: [HomeScreen, WorkoutScreen, CommunityScreen]
/// Nav pill floats OVER content.
class MyGymBroScaffold extends ConsumerStatefulWidget {
  const MyGymBroScaffold({super.key});

  @override
  ConsumerState<MyGymBroScaffold> createState() => _MyGymBroScaffoldState();
}

class _MyGymBroScaffoldState extends ConsumerState<MyGymBroScaffold>
    with WidgetsBindingObserver {
  int _previousIndex = 0;

  /// Timestamp of the last root back gesture — double-back-to-exit window.
  DateTime? _lastBackAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold start: restore a workout the OS killed mid-session (state is
    // rebuilt from Drift), reconcile abandoned ones into history, and
    // resync/tear down the ongoing notification accordingly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(activeSessionProvider.notifier).restoreOrResync(),
      );
      // Schedule the ambient achievement notifications (streak-at-risk,
      // weekly recap, scheduled-day, muscle-recovered) for today's data.
      unawaited(ref.read(achievementPlannerProvider).refresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-reconcile RevenueCat entitlements into the local profile so the
      // paywall gate (`subscriptionLockedProvider`) reflects renewals,
      // cancellations, and trial elapse the moment the app comes forward,
      // then let the verify-subscription edge function issue the
      // authoritative (clock-rollback-proof) verdict. Best-effort — no-ops
      // when RevenueCat/Supabase aren't configured or the device is offline.
      final profileDao = ref.read(userProfileDaoProvider);
      unawaited(SubscriptionSyncService.syncNow(profileDao)
          .then((_) => SubscriptionSyncService.verifyServer(profileDao)));
      // Option A — rebuild any stale active-workout notification whose
      // buttons would otherwise point at a dead isolate (see
      // `docs/notification-recovery.md`) — and, if this process has no
      // live session, restore one the OS killed mid-workout from Drift.
      unawaited(
        ref.read(activeSessionProvider.notifier).restoreOrResync(),
      );
    }
  }

  static const _pages = <Widget>[
    HomeScreen(),
    WorkoutScreen(),
    CommunityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    // Rank resolution: fold the live composite into the persisted rank state
    // — celebrates promotions, arms/holds/expires demotion shields, and keeps
    // the badge available offline. Lives on the scaffold (not a tab) because
    // the AnimatedSwitcher below disposes tabs on switch.
    ref.listen(myLiveCompositeProvider, (_, live) {
      final store = ref.read(rankStateProvider.notifier);
      if (live == null || !store.loaded) return;
      final stored = ref.read(rankStateProvider);
      final r = resolveRank(stored, live, DateTime.now());
      if (r.rankedUp) {
        unawaited(showRankUp(context, Rank.fromComposite(r.state.composite)));
      }
      if (r.state != stored) unawaited(store.save(r.state));
    });

    // Re-plan the scheduled achievement notifications whenever the streak
    // moves — i.e. after every finished workout and at midnight rollover.
    ref.listen(streakProvider, (_, __) {
      unawaited(ref.read(achievementPlannerProvider).refresh());
    });

    final colors = AppColors.of(context);
    final idx = ref.watch(navIndexProvider);

    // Activate the home-widget mirror listens. Pure side-effect provider —
    // ref.read is enough; we never need its (void) value.
    ref.read(widgetSyncProvider);

    // Track direction for slide animation
    final goingForward = idx >= _previousIndex;
    _previousIndex = idx;

    // ── Animated page content ── (shared by both nav styles)
    final pageBody = AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        // AnimatedSwitcher calls transitionBuilder for BOTH the old (fading
        // out) and new (fading in) child. The incoming child has the current
        // key; the outgoing has the previous key.
        final isIncoming = child.key == ValueKey(idx);
        final slideOffset = isIncoming
            ? (goingForward
                ? const Offset(0.15, 0) // new page enters from right
                : const Offset(-0.15, 0)) // new page enters from left
            : (goingForward
                ? const Offset(-0.08, 0) // old page exits to left
                : const Offset(0.08, 0)); // old page exits to right

        return SlideTransition(
          position: Tween<Offset>(begin: slideOffset, end: Offset.zero)
              .animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(idx), child: _pages[idx]),
    );

    // iOS → real native UITabBar (Apple Liquid Glass on iOS 26) via
    // cupertino_native_better. Every other platform keeps the custom frosted
    // floating pill. Both drive the same [navIndexProvider].
    final scaffold = Theme.of(context).platform == TargetPlatform.iOS
        ? Scaffold(
            backgroundColor: colors.background,
            body: pageBody,
            bottomNavigationBar: const IosNativeNav(),
          )
        : Scaffold(
            backgroundColor: colors.background,
            body: Stack(
              children: [
                pageBody,
                const BottomNavPill(),
              ],
            ),
          );

    // Root back guard: back from a non-home tab returns to Home; on Home
    // the first back gesture only shows a hint and a second within 2s
    // actually leaves the app. Pushed routes, sheets and dialogs sit above
    // this route, so their back behavior is untouched. Inert on iOS (no
    // system back at the app root).
    // BackButtonListener actually receives the event: go_router 13's
    // popRoute() checks canPop() before maybePop(), so a PopScope on the
    // root route is never consulted and the app would exit directly. The
    // listener takes priority on the back dispatcher; when something is
    // genuinely poppable (pushed screen, sheet, dialog) it returns false
    // and the router pops as usual. PopScope(canPop: false) stays as the
    // ahead-of-time "framework handles back" signal predictive back needs.
    return BackButtonListener(
      onBackButtonPressed: _handleRootBack,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          // Only reached if something calls maybePop() directly (or a
          // future go_router routes back through here) — same handling.
          if (!didPop) unawaited(_handleRootBack());
        },
        child: scaffold,
      ),
    );
  }

  /// Root back handling: pop whatever is genuinely open first; otherwise a
  /// non-home tab goes Home, and on Home a double-back within 2s exits.
  /// Returns true when the event was consumed.
  Future<bool> _handleRootBack() async {
    if (GoRouter.of(context).canPop()) return false; // let the router pop
    if (ref.read(navIndexProvider) != 0) {
      ref.read(navIndexProvider.notifier).state = 0;
      _lastBackAt = null; // exit window starts fresh on Home
      return true;
    }
    final now = DateTime.now();
    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return true;
    }
    _lastBackAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).backAgainToExit),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        // Keep the hint clear of the floating nav pill.
        margin: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 110.h),
      ),
    );
    return true;
  }
}
