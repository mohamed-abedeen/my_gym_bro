import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_format.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/steps/body_steps.dart';
import 'package:my_gym_bro/features/onboarding/steps/choice_steps.dart';
import 'package:my_gym_bro/features/onboarding/steps/consent_step.dart';
import 'package:my_gym_bro/features/onboarding/steps/intro_steps.dart';
import 'package:my_gym_bro/features/onboarding/steps/timeline_step.dart';
import 'package:my_gym_bro/features/onboarding/steps/wheel_steps.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/features/paywall/paywall_screen.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// The onboarding flow (/onboarding): Welcome → three question sections →
/// the optimized timeline → the paywall, as one screen.
///
/// Steps live in one stack rather than one route each because the header
/// (back + segmented progress) and the frosted Continue button are shared
/// chrome that must stay put — the progress fills animate between steps —
/// while pages push underneath with the handoff's iOS-style motion
/// (incoming 100% → 0, outgoing 0 → −28% at 35% opacity, .42s).
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({
    super.key,
    this.initialStep = OnboardingStep.welcome,
  });

  /// Where the flow opens. The app always starts at Welcome; tests jump
  /// straight to a step.
  final OnboardingStep initialStep;

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _push =
      AnimationController(vsync: this, duration: AppOnboarding.push);

  late OnboardingStep _step = widget.initialStep;
  OnboardingStep? _leaving;
  bool _forward = true;

  /// Whether each step plays its entrance: steps reached by going back
  /// appear settled, like the handoff.
  late final Map<OnboardingStep, bool> _animateIn = {widget.initialStep: true};

  Timer? _sectionTimer;

  /// Set once the paywall purchase succeeds: back is gone and the
  /// "LET'S GO" overlay covers the flow.
  bool? _trialStarted;

  @override
  void dispose() {
    _sectionTimer?.cancel();
    _push.dispose();
    super.dispose();
  }

  bool get _purchased => _trialStarted != null;

  void _goTo(OnboardingStep next, {required bool forward}) {
    if (next == _step) return;
    _sectionTimer?.cancel();
    setState(() {
      _leaving = _step;
      _step = next;
      _forward = forward;
      _animateIn[next] = forward;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _push.value = 1;
      setState(() => _leaving = null);
    } else {
      _push.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) setState(() => _leaving = null);
      });
    }
    // Section interstitials move on by themselves (forward only).
    if (next.isSection && forward) {
      _sectionTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _step == next) _next();
      });
    }
  }

  void _next() {
    if (_push.isAnimating) return;
    final flow = ref.read(onboardingProvider).flow;
    final i = flow.indexOf(_step);
    if (i >= 0 && i < flow.length - 1) _goTo(flow[i + 1], forward: true);
  }

  void _back() {
    if (_push.isAnimating || _purchased) return;
    final flow = ref.read(onboardingProvider).flow;
    var j = flow.indexOf(_step) - 1;
    // Back skips over the section interstitials.
    if (j >= 0 && flow[j].isSection) j--;
    if (j >= 0) _goTo(flow[j], forward: false);
  }

  void _continue() {
    if (ref.read(onboardingProvider).canContinue(_step)) _next();
  }

  /// Paywall done (or skipped in dev/beta) → create the account.
  void _toSignUp() => context.push(AppRoutes.onboardingSignup);

  Widget _buildStep(OnboardingStep step, AppLocalizations l10n) =>
      switch (step) {
        OnboardingStep.welcome => WelcomeStep(
            onGetStarted: _next,
            onSignIn: () => context.push(AppRoutes.signIn),
            onSkip: () => context.go(AppRoutes.home),
          ),
        OnboardingStep.gender => const GenderStep(),
        OnboardingStep.goal => const GoalStep(),
        OnboardingStep.goalDetail => const GoalDetailStep(),
        OnboardingStep.focus => const FocusStep(),
        OnboardingStep.healthConsent => HealthConsentStep(
            onDecline: () {
              if (_push.isAnimating) return;
              ref.read(onboardingProvider.notifier).declineHealthConsent();
              _next();
            },
          ),
        OnboardingStep.section2 => SectionStep(
            number: '02',
            title: l10n.obSectionBodyData,
            onTap: _next,
          ),
        OnboardingStep.birthdate => const BirthdateStep(),
        OnboardingStep.height => const HeightStep(),
        OnboardingStep.weight => const WeightStep(),
        OnboardingStep.target => const WeightStep(target: true),
        OnboardingStep.timeline1 => const TimelineStep(),
        OnboardingStep.section3 => SectionStep(
            number: '03',
            title: l10n.obSectionAboutYou,
            onTap: _next,
          ),
        OnboardingStep.issues => const IssuesStep(),
        OnboardingStep.issueDetail => const IssueDetailStep(),
        OnboardingStep.injuries => const InjuriesStep(),
        OnboardingStep.restDays => const RestDaysStep(),
        OnboardingStep.recovery => const RecoveryStep(),
        OnboardingStep.experience => const ExperienceStep(),
        OnboardingStep.compete => const CompeteStep(),
        OnboardingStep.trainingDays => const TrainingDaysStep(),
        OnboardingStep.timeline2 => const TimelineStep(optimized: true),
        OnboardingStep.paywall => Consumer(
            builder: (context, ref, _) {
              final data = ref.watch(onboardingProvider);
              return PaywallView(
                locked: false,
                // The personal-target slide is built from health data.
                plan: data.hasHealthConsent
                    ? PaywallPlan.fromOnboarding(data)
                    : null,
                female: data.isFemale,
                onPurchased: (trial) => setState(() => _trialStarted = trial),
                onSkip: paywallSkipAvailable ? _toSignUp : null,
              );
            },
          ),
      };

  /// One page of the stack. The wrapper types never change between the
  /// animating and resting states, so a page keeps its element (and state)
  /// when the push finishes.
  Widget _page(
    OnboardingStep step,
    AppLocalizations l10n, {
    required double dx,
    required double opacity,
  }) =>
      KeyedSubtree(
        key: ValueKey(step),
        child: IgnorePointer(
          ignoring: step != _step,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Opacity(
              opacity: opacity,
              child: ObPageScope(
                animateIn: _animateIn[step] ?? true,
                child: _buildStep(step, l10n),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(onboardingProvider);
    final width = MediaQuery.sizeOf(context).width;
    final progress = _step.progress;
    final showHeader = progress != null || _step == OnboardingStep.paywall;
    final showContinue = progress != null;

    return PopScope(
      canPop: _step == OnboardingStep.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppOnboarding.background,
          resizeToAvoidBottomInset: false,
          body: ObFrameScope(
            child: Builder(
              builder: (context) {
                final ob = ObFrame.of(context);
                return Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _push,
                      builder: (context, _) {
                        final t =
                            AppOnboarding.pushCurve.transform(_push.value);
                        final leaving = _leaving;
                        if (leaving == null) {
                          return Stack(
                            children: [
                              _page(_step, l10n, dx: 0, opacity: 1),
                            ],
                          );
                        }
                        // Forward: the new page slides over the old one.
                        // Back: the old page slides off, revealing the
                        // previous one. The mover is painted last.
                        final under = _forward ? leaving : _step;
                        final over = _forward ? _step : leaving;
                        final underT = _forward ? t : 1 - t;
                        return Stack(
                          children: [
                            _page(
                              under,
                              l10n,
                              dx: -0.28 * width * underT,
                              opacity: 1 - 0.65 * underT,
                            ),
                            _page(
                              over,
                              l10n,
                              dx: width * (_forward ? 1 - t : t),
                              opacity: 1,
                            ),
                          ],
                        );
                      },
                    ),

                    // ── Global header
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !showHeader || _purchased,
                        child: AnimatedOpacity(
                          opacity: showHeader && !_purchased ? 1 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: _ArtboardOverlay(
                            child: ObHeader(
                              progress: progress,
                              onBack: _back,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Global Continue
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !showContinue,
                        child: AnimatedOpacity(
                          opacity: showContinue ? 1 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: _ArtboardOverlay(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ob.at(
                                  left: 33,
                                  top: 841,
                                  width: 374,
                                  height: 79,
                                  child: ObGlassButton(
                                    label: l10n.continueButton,
                                    enabled: data.canContinue(_step),
                                    onTap: _continue,
                                  ),
                                ),
                                ob.centered(
                                  top: 932,
                                  child: Text(
                                    l10n.obPrivacyNote,
                                    style: ob.text(10,
                                        weight: FontWeight.w600,
                                        color: AppOnboarding.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── iOS-style edge swipe back
                    if (showHeader && !_purchased)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 20,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragEnd: (d) {
                            if ((d.primaryVelocity ?? 0) > 250) _back();
                          },
                        ),
                      ),

                    // ── "LET'S GO" after the purchase
                    if (_purchased)
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 400),
                          builder: (context, o, child) =>
                              Opacity(opacity: o, child: child),
                          child: PaywallSuccess(
                            line: _successLine(l10n, data),
                            onStart: _toSignUp,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _successLine(AppLocalizations l10n, OnboardingData data) {
    final trial = _trialStarted ?? false;
    if (!data.hasHealthConsent) {
      return trial ? l10n.obTrialStartedPlain : l10n.obSubscribedPlain;
    }
    final target = ObUnits.headlineWeight(
      data.effectiveTargetKg,
      metric: data.weightMetric,
    );
    final date = obShortDate(context, data.prediction().optimizedDate);
    return trial
        ? l10n.obTrialStartedLine(target, date)
        : l10n.obSubscribedLine(target, date);
  }
}

/// Positions a transparent child layer on the artboard (for chrome drawn
/// above the pages).
class _ArtboardOverlay extends StatelessWidget {
  const _ArtboardOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final size = ob.artboardSize;
    return Stack(
      children: [
        Positioned(
          left: ob.origin.dx,
          top: ob.origin.dy,
          width: size.width,
          height: size.height,
          child: child,
        ),
      ],
    );
  }
}
