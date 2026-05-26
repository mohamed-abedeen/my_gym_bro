import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen 1 — Splash (1.5s)
/// "My Gym Bro" 48px w700 centered. D2FF00 pulse animation.
/// Navigates: existing session → /home, else → /onboarding/welcome.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Navigate after 1.5s
    Future.delayed(const Duration(milliseconds: 1500), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    var hasSession = false;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      hasSession = session != null;
    } catch (_) { // ignore: avoid_catches_without_on_clauses
      // Supabase not initialised — treat as no session.
      // Must use bare catch: the package throws AssertionError (an Error,
      // not an Exception) in debug builds when not initialised.
    }
    if (hasSession) {
      context.go('/');
    } else {
      context.go('/onboarding/welcome');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _pulse,
              child: Text(
                'MGB',
                style: TextStyle(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.of(context).white,
                ),
              ),
            ),
          ),

          // ── DEV ONLY — visible in debug builds only ──────────────────────
          if (kDebugMode)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/'),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.of(context).white.withValues(alpha: 0.24)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '⚡ DEV — Skip to Home',
                          style: TextStyle(
                            color: AppColors.of(context).white.withValues(alpha: 0.54),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => context.go('/onboarding/welcome'),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.of(context).white.withValues(alpha: 0.24)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '⚡ DEV — Skip to Onboarding',
                          style: TextStyle(
                            color: AppColors.of(context).white.withValues(alpha: 0.54),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
