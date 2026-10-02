import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/onboarding/widgets/mgb_logo.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 00 — Splash (/splash).
///
/// M, G and B slam in one at a time (2.6× → 1 with an ease-in impact, a
/// short screen shake after each), the mark settles with a small spring and
/// fades, then at 1.7s: existing session → home, else → onboarding.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _total = 1700.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  static const _impact = Cubic(0.7, 0, 0.9, 0.4);
  static const _spring = Cubic(0.34, 1.5, 0.64, 1);

  final List<Timer> _timers = [];
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _navigate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1400 / _total;
      _timers.add(Timer(const Duration(milliseconds: 600), _navigate));
    } else {
      _c.forward();
      // A light tap with each letter's impact.
      for (final t in const [250 + 190, 450 + 190, 650 + 190]) {
        _timers.add(
          Timer(Duration(milliseconds: t), HapticFeedback.lightImpact),
        );
      }
    }
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    var hasSession = false;
    try {
      hasSession = Supabase.instance.client.auth.currentSession != null;
    } on Object catch (_) {
      // Supabase not initialised — treat as no session.
      // Must use bare catch: the package throws AssertionError (an Error,
      // not an Exception) in debug builds when not initialised.
    }
    if (!mounted) return;
    context.go(hasSession ? AppRoutes.home : AppRoutes.onboarding);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _c.dispose();
    super.dispose();
  }

  /// 0→1 progress of a [length]ms window starting at [start]ms.
  double _win(double ms, double start, double length) =>
      ((ms - start) / length).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppOnboarding.background,
        body: ObFrameScope(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final ob = ObFrame.of(context);
              final ms = _c.value * _total;

              // Letters land at 250 / 450 / 650ms.
              final scales = <double>[];
              final opacities = <double>[];
              var shake = Offset.zero;
              for (var i = 0; i < 3; i++) {
                final start = 250.0 + 200 * i;
                final p = _win(ms, start, 200);
                scales.add(ms < start ? 2.6 : 2.6 - 1.6 * _impact.transform(p));
                opacities.add(_win(ms, start, 80));
                // 3-unit jolt after each impact, eased in/out over 70ms.
                final env = _win(ms, start + 190, 70) - _win(ms, start + 250, 70);
                if (env > 0) {
                  final n = i + 1;
                  shake += Offset(n.isOdd ? 4 : -4, n == 2 ? 3 : -3) * env;
                }
              }

              // Settle: dip to .94 at 940ms, spring back at 1180ms.
              final dip = _spring.transform(_win(ms, 940, 450));
              final back = _spring.transform(_win(ms, 1180, 450));
              final settle = 1 - 0.06 * dip + 0.06 * back * math.min(1, dip);
              final fade = 1 - _win(ms, 1550, 250);

              return ObArtboard(
                children: [
                  ob.at(
                    left: 80,
                    top: 323,
                    width: 280,
                    height: 280,
                    child: Transform.translate(
                      offset: shake * ob.scale,
                      child: Opacity(
                        opacity: fade,
                        child: Transform.scale(
                          scale: settle,
                          child: MgbLogo(
                            size: ob(280),
                            letterScale: scales,
                            letterOpacity: opacities,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
