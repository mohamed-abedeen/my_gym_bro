import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart'
    show kBetaFreeAccess;
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// 01 — Welcome: full-bleed hero with a slow Ken Burns settle, then
/// "Get Started" and the sign-in link fade up.
class WelcomeStep extends StatefulWidget {
  const WelcomeStep({
    required this.onGetStarted,
    required this.onSignIn,
    required this.onSkip,
    super.key,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  /// Dev/beta shortcut straight into the app (hidden in store builds).
  final VoidCallback onSkip;

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hero = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  late final TapGestureRecognizer _signIn = TapGestureRecognizer()
    ..onTap = widget.onSignIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hero.isAnimating || _hero.value > 0) return;
    final play = ObPageScope.animateInOf(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (play) {
      _hero.forward();
    } else {
      _hero.value = 1;
    }
  }

  @override
  void dispose() {
    _hero.dispose();
    _signIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final zoom = CurvedAnimation(
      parent: _hero,
      curve: const Cubic(0.16, 0.84, 0.3, 1),
    );
    final fade = CurvedAnimation(
      parent: _hero,
      curve: const Interval(0, 1 / 3, curve: Curves.ease),
    );

    return ObArtboard(
      children: [
        ob.at(
          left: 0,
          top: 0,
          width: 440,
          height: 812,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: _hero,
                  builder: (context, child) => Opacity(
                    opacity: fade.value,
                    child: Transform.scale(
                      scale: 1.1 - 0.1 * zoom.value,
                      alignment: const Alignment(0, -0.4),
                      child: child,
                    ),
                  ),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: ob(956),
                    child: Image.asset(
                      'assets/onboarding/hero.png',
                      width: ob(440),
                      height: ob(956),
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: ob(150),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), AppOnboarding.background],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ob.at(
          left: 33,
          top: 818,
          width: 374,
          height: 80,
          child: ObEntrance(
            delay: const Duration(milliseconds: 700),
            duration: const Duration(milliseconds: 700),
            fade: !obNativeGlass,
            child: ObDarkButton(
              label: l10n.getStarted,
              onTap: widget.onGetStarted,
            ),
          ),
        ),
        ob.centered(
          top: 914,
          child: ObEntrance(
            delay: const Duration(milliseconds: 900),
            dy: 0,
            child: Text.rich(
              TextSpan(
                style: ob.text(11, weight: FontWeight.w500),
                children: [
                  TextSpan(text: '${l10n.obHaveAccount} '),
                  TextSpan(
                    text: l10n.obSignInLink,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    recognizer: _signIn,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (kDebugMode || kBetaFreeAccess)
          ob.at(
            right: 20,
            top: 52,
            height: 48,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSkip,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ob(8)),
                child: Center(
                  child: Text(
                    l10n.skip,
                    style: ob.text(13,
                        weight: FontWeight.w600,
                        color: AppOnboarding.textPrimary.withValues(alpha: .7)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 06 / 12 — "SECTION 02 · BODY DATA" interstitial. The number slides up out
/// of a clipped mask, a 60×2 rule fills over 1.5s; the flow auto-advances
/// after 2s and a tap skips ahead.
class SectionStep extends StatefulWidget {
  const SectionStep({
    required this.number,
    required this.title,
    required this.onTap,
    super.key,
  });

  final String number;
  final String title;
  final VoidCallback onTap;

  @override
  State<SectionStep> createState() => _SectionStepState();
}

class _SectionStepState extends State<SectionStep>
    with SingleTickerProviderStateMixin {
  // 0–1 over 1.9s: number .15→.9s, rule .4→1.9s.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.value > 0) return;
    final play = ObPageScope.animateInOf(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (play) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final number = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.15 / 1.9, 0.9 / 1.9,
          curve: AppOnboarding.entranceCurve),
    );
    final rule = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.4 / 1.9, 1),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: ObArtboard(
        children: [
          ob.centered(
            top: 352,
            child: ObEntrance(
              delay: const Duration(milliseconds: 100),
              dy: 0,
              duration: const Duration(milliseconds: 500),
              child: Padding(
                // Tracking adds trailing space; nudge to optical centre.
                padding: EdgeInsets.only(left: ob(3)),
                child: Text(
                  l10n.obSection,
                  style: ob.text(13,
                      color: AppOnboarding.textMuted, letterSpacing: 3),
                ),
              ),
            ),
          ),
          ob.at(
            left: 0,
            top: 372,
            width: 440,
            height: 170,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: number,
                builder: (context, child) => FractionalTranslation(
                  translation: Offset(0, 1 - number.value),
                  child: child,
                ),
                child: Center(
                  child: Text(
                    widget.number,
                    style: ob.display(
                      176,
                      weight: 900,
                      color: AppOnboarding.lime,
                      lineHeight: 170,
                    ),
                  ),
                ),
              ),
            ),
          ),
          ob.centered(
            top: 556,
            child: ObEntrance(
              delay: const Duration(milliseconds: 400),
              child: Text(
                widget.title,
                style: ob.display(44, letterSpacing: 1),
              ),
            ),
          ),
          ob.at(
            left: 190,
            top: 636,
            width: 60,
            height: 2,
            child: ObEntrance(
              delay: const Duration(milliseconds: 500),
              dy: 0,
              duration: const Duration(milliseconds: 400),
              child: ColoredBox(
                color: AppOnboarding.limeTrack,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedBuilder(
                    animation: rule,
                    builder: (context, _) => FractionallySizedBox(
                      widthFactor: rule.value,
                      heightFactor: 1,
                      child: const ColoredBox(color: AppOnboarding.lime),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
