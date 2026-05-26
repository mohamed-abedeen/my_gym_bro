import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/community/community_screen.dart';
import 'package:my_gym_bro/features/home/home_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/features/workout/workout_screen.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/bottom_nav_pill.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check on first load (after first frame so context is ready).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTrial());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkTrial();
  }

  void _checkTrial() {
    if (!mounted) return;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;

    final isTrialExpired = profile.subscriptionStatus == 'trial' &&
        profile.subscriptionExpiresAt != null &&
        DateTime.now().isAfter(profile.subscriptionExpiresAt!);

    final isExpired = profile.subscriptionStatus == 'expired';

    if (isTrialExpired || isExpired) {
      context.push(AppRoutes.paywall);
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
    final colors = AppColors.of(context);
    final idx = ref.watch(navIndexProvider);

    // Track direction for slide animation
    final goingForward = idx >= _previousIndex;
    _previousIndex = idx;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Animated page content ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              // Determine if this child is the incoming or outgoing page.
              // AnimatedSwitcher calls transitionBuilder for BOTH the old
              // (fading out) and new (fading in) child. The incoming child
              // has the current key; the outgoing has the previous key.
              final isIncoming = (child.key == ValueKey(idx));
              final slideOffset =
                  isIncoming
                      ? (goingForward
                          ? const Offset(0.15, 0) // new page enters from right
                          : const Offset(-0.15, 0)) // new page enters from left
                      : (goingForward
                          ? const Offset(-0.08, 0) // old page exits to left
                          : const Offset(0.08, 0)); // old page exits to right

              return SlideTransition(
                position: Tween<Offset>(
                  begin: slideOffset,
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: KeyedSubtree(key: ValueKey(idx), child: _pages[idx]),
          ),

          // ── Faded lime glow at bottom ──
          // Positioned(
          //   left: 0,
          //   right: 0,
          //   bottom: 0,
          //   height: MediaQuery.of(context).padding.bottom + 1,
          //   child: IgnorePointer(
          //     child: Container(
          //       decoration: const BoxDecoration(
          //         gradient: LinearGradient(
          //           begin: Alignment.bottomCenter,
          //           end: Alignment.topCenter,
          //           colors: [
          //             Color(0x40D2FF00), // lime at ~25% opacity
          //             Color(0x00D2FF00), // fully transparent
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),
          // ),

          // ── Floating nav pill ──
          const BottomNavPill(),
        ],
      ),
    );
  }
}
