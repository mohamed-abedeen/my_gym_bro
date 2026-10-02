import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/auth/auth_notifier.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:my_gym_bro/core/services/notification_service.dart';
import 'package:my_gym_bro/features/onboarding/app_entry.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_persistence.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/widgets/mgb_logo.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/features/settings/app_settings_provider.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart'
    show kBetaFreeAccess;
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/legal_agreement_text.dart';

/// Create Account (/onboarding/signup) — the step after the paywall.
///
/// OAuth-only: Apple (iOS) + Google. No email/password. On success the
/// onboarding answers land on the profile the auth listener bootstrapped
/// (local write, queued sync), then the starter exercises cache and the app
/// opens.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  bool _seeding = false;
  // OAuth completes out-of-band (deep-link → onAuthStateChange), not via the
  // button's future — navigation and onboarding-data merge must react to the
  // state transition. Armed only while a social flow is in flight.
  bool _oauthInFlight = false;

  void _startOAuth(Future<void> Function() flow) {
    setState(() => _oauthInFlight = true);
    flow();
  }

  /// Finish a Google/Apple sign-up: layer the onboarding answers onto the
  /// profile row the auth listener bootstrapped, then seed + continue.
  Future<void> _completeOAuthSignUp() async {
    final l10n = AppLocalizations.of(context);
    final answers = ref.read(onboardingProvider);
    try {
      await OnboardingPersistence.save(
        db: ref.read(databaseProvider),
        sync: ref.read(syncServiceProvider),
        data: answers,
      );
    } on Exception catch (e) {
      // Non-fatal — every answer can be edited later.
      CrashReporter.recordError(e, reason: 'Onboarding answers save failed');
    }
    await _applyReminder(answers, l10n);
    await _seedAndEnter();
  }

  /// The training-days step's reminder switch drives the same setting (and
  /// notification) as Settings → Training reminders.
  Future<void> _applyReminder(
    OnboardingData answers,
    AppLocalizations l10n,
  ) async {
    try {
      await ref
          .read(trainingRemindersEnabledProvider.notifier)
          .set(answers.reminder);
      if (answers.reminder) {
        await NotificationService.scheduleWorkoutReminder(
          title: l10n.trainingReminders,
          body: l10n.trainingReminderBody,
        );
      } else {
        await NotificationService.cancelWorkoutReminder();
      }
    } on Exception catch (e) {
      CrashReporter.recordError(e, reason: 'Onboarding reminder setup failed');
    }
  }

  Future<void> _seedAndEnter() async {
    if (!mounted) return;
    setState(() => _seeding = true);
    await prepareAppEntry(ref);

    if (!mounted) return;
    setState(() => _seeding = false);
    ref.invalidate(onboardingProvider);
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading || _seeding;

    ref.listen<AppAuthState>(authNotifierProvider, (previous, next) {
      if (!_oauthInFlight) return;
      if (next.status == AuthStatus.authenticated) {
        _oauthInFlight = false;
        _completeOAuthSignUp();
      } else if (next.status == AuthStatus.error) {
        _oauthInFlight = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? l10n.signUpError),
            backgroundColor: AppOnboarding.fatigued,
          ),
        );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppOnboarding.background,
        body: ObFrameScope(
          child: Builder(
            builder: (context) {
              final ob = ObFrame.of(context);
              return Stack(
                children: [
                  ObArtboard(
                    children: [
                      // Back to the "LET'S GO" overlay (pushed from it).
                      if (Navigator.of(context).canPop())
                        ob.at(
                          left: 20,
                          top: 52,
                          width: 48,
                          height: 48,
                          child: ObBackButton(
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ob.centered(
                        top: 94,
                        inset: 30,
                        child: Text(
                          l10n.obSignUpTitle,
                          textAlign: TextAlign.center,
                          style: ob.text(30, letterSpacing: -0.3),
                        ),
                      ),
                      ob.at(
                        left: 60,
                        right: 60,
                        top: 141,
                        child: Text(
                          l10n.obSignUpSubtitle,
                          textAlign: TextAlign.center,
                          style: ob.text(11,
                              color: AppOnboarding.textSubtitle,
                              lineHeight: 13),
                        ),
                      ),
                      ob.at(
                        left: 110,
                        top: 300,
                        width: 220,
                        height: 220,
                        child: ObEntrance(
                          dy: 0,
                          scaleFrom: 0.92,
                          child: MgbLogo(size: ob(220)),
                        ),
                      ),
                      if (Platform.isIOS)
                        ob.at(
                          left: 33,
                          top: 662,
                          width: 374,
                          height: 79,
                          child: _ProviderButton(
                            light: true,
                            icon: Icons.apple,
                            label: l10n.continueWithApple,
                            onTap: isLoading
                                ? null
                                : () => _startOAuth(ref
                                    .read(authNotifierProvider.notifier)
                                    .signInWithApple),
                          ),
                        ),
                      ob.at(
                        left: 33,
                        top: 752,
                        width: 374,
                        height: 79,
                        child: _ProviderButton(
                          icon: Icons.g_mobiledata,
                          label: l10n.continueWithGoogle,
                          onTap: isLoading
                              ? null
                              : () => _startOAuth(ref
                                  .read(authNotifierProvider.notifier)
                                  .signInWithGoogle),
                        ),
                      ),
                      // Terms acceptance + the 16+ confirmation (Terms §2,
                      // Apple 1.2 for the Bros/challenges UGC).
                      ob.at(
                        left: 40,
                        right: 40,
                        top: 846,
                        child: LegalAgreementText(
                          style: ob.text(11,
                              weight: FontWeight.w500,
                              color: AppOnboarding.textMuted,
                              lineHeight: 15),
                          linkStyle: const TextStyle(
                            color: AppOnboarding.textPrimary,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppOnboarding.textPrimary,
                          ),
                        ),
                      ),
                      // Dev/beta: into the app without an account — sized to
                      // be found while sign-in isn't fully set up.
                      if (kDebugMode || kBetaFreeAccess)
                        ob.centered(
                          top: 888,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: isLoading ? null : _seedAndEnter,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: ob(20),
                                vertical: ob(8),
                              ),
                              child: Text(
                                l10n.skip,
                                style: ob
                                    .text(17, weight: FontWeight.w600)
                                    .copyWith(
                                      decoration: TextDecoration.underline,
                                      decorationColor:
                                          AppOnboarding.textPrimary,
                                    ),
                              ),
                            ),
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

                  // Exercise seeding overlay
                  if (_seeding)
                    Positioned.fill(
                      child: ColoredBox(
                        color: AppOnboarding.background.withValues(alpha: 0.9),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: AppOnboarding.lime,
                              ),
                              SizedBox(height: ob(24)),
                              Text(
                                l10n.loadingExercises,
                                style: ob.text(17, weight: FontWeight.w500),
                              ),
                            ],
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

/// A 374×79 provider pill: white (Sign in with Apple's style on dark
/// backgrounds) or the flow's dark gradient.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.light = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final fg = light ? Colors.black : AppOnboarding.textPrimary;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: fg, size: ob(light ? 28 : 36)),
        SizedBox(width: ob(10)),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: ob.text(22, color: fg)),
          ),
        ),
      ],
    );
    final button = light
        ? ObPressable(
            onTap: onTap,
            semanticLabel: label,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ob(40)),
              ),
              child: Center(child: content),
            ),
          )
        : ObDarkButton(label: label, fontSize: 22, icon: icon, onTap: onTap);
    // Native Liquid Glass can't sit under a partial opacity; it shows its
    // own disabled state while a sign-in runs.
    if (!light && obNativeGlass) return button;
    return AnimatedOpacity(
      opacity: onTap == null ? 0.5 : 1,
      duration: const Duration(milliseconds: 200),
      child: button,
    );
  }
}
