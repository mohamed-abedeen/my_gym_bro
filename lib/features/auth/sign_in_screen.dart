import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:my_gym_bro/core/auth/auth_notifier.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/onboarding/app_entry.dart';
import 'package:my_gym_bro/features/onboarding/widgets/mgb_logo.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart'
    show kBetaFreeAccess;
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/legal_agreement_text.dart';

enum _Provider { google, apple }

/// Sign In (/auth/signin)
/// OAuth-only: Google (all platforms) + Apple (iOS). No email/password.
/// l10n.noAccount → back into the onboarding flow.
///
/// Built like the sign-up step on the onboarding's 440×956 artboard and
/// fixed black/lime palette, so it reads as one family with the Welcome
/// screen that pushes it.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  // OAuth completes out-of-band (deep-link → onAuthStateChange), not via the
  // button's future — so navigation must react to the state transition.
  // Which provider is in flight, so only its button shows the spinner.
  _Provider? _inFlight;
  bool _skipping = false;

  void _startOAuth(_Provider provider, Future<void> Function() flow) {
    setState(() => _inFlight = provider);
    flow();
  }

  /// Dev/beta (`kDebugMode || kBetaFreeAccess`, like the onboarding's Skips):
  /// into the app without an account, for while sign-in isn't fully set up.
  Future<void> _skipToApp() async {
    setState(() => _skipping = true);
    await prepareAppEntry(ref);
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  // No account → the onboarding flow (it ends in sign-up).
  // Pushed from its Welcome step → just pop back there.
  void _toOnboarding() => context.canPop()
      ? context.pop()
      : context.go(AppRoutes.onboarding);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading || _skipping;

    ref.listen<AppAuthState>(authNotifierProvider, (previous, next) {
      if (_inFlight == null) return;
      if (next.status == AuthStatus.authenticated) {
        _inFlight = null;
        context.go('/');
      } else if (next.status == AuthStatus.error) {
        _inFlight = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ??
                AppLocalizations.of(context).signInError),
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
              return ObArtboard(
                children: [
                  // One column from the title down to the footer link, so
                  // longer translations push things down instead of
                  // overlapping; the logo takes whatever height is left.
                  ob.at(
                    left: 0,
                    right: 0,
                    top: 94,
                    bottom: 26,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: ob(72)),
                          child: Text(
                            l10n.signInTitle,
                            textAlign: TextAlign.center,
                            style: ob.text(30, letterSpacing: -0.3),
                          ),
                        ),
                        SizedBox(height: ob(8)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: ob(48)),
                          child: Text(
                            l10n.signInSubtitle,
                            textAlign: TextAlign.center,
                            style: ob.text(15,
                                weight: FontWeight.w500,
                                color: AppOnboarding.textMuted,
                                lineHeight: 20),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ObEntrance(
                                dy: 0,
                                scaleFrom: 0.92,
                                child: MgbLogo(size: ob(200)),
                              ),
                            ),
                          ),
                        ),
                        if (Platform.isIOS) ...[
                          _ProviderButton(
                            light: true,
                            leading: Icon(
                              Icons.apple,
                              color: Colors.black,
                              size: ob(28),
                            ),
                            label: l10n.continueWithApple,
                            loading: isLoading && _inFlight == _Provider.apple,
                            onTap: isLoading
                                ? null
                                : () => _startOAuth(
                                    _Provider.apple,
                                    ref
                                        .read(authNotifierProvider.notifier)
                                        .signInWithApple),
                          ),
                          SizedBox(height: ob(12)),
                        ],
                        _ProviderButton(
                          leading: SvgPicture.asset(
                            'assets/icons/google_g.svg',
                            width: ob(26),
                            height: ob(26),
                            excludeFromSemantics: true,
                          ),
                          label: l10n.continueWithGoogle,
                          loading: isLoading && _inFlight == _Provider.google,
                          onTap: isLoading
                              ? null
                              : () => _startOAuth(
                                  _Provider.google,
                                  ref
                                      .read(authNotifierProvider.notifier)
                                      .signInWithGoogle),
                        ),
                        SizedBox(height: ob(16)),
                        // Signing in with a new Google/Apple account creates
                        // one, so the Terms acceptance + 16+ confirmation
                        // apply here too.
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: ob(40)),
                          child: LegalAgreementText(
                            style: ob.text(12,
                                weight: FontWeight.w500,
                                color: AppOnboarding.textMuted,
                                lineHeight: 16),
                            linkStyle: const TextStyle(
                              color: AppOnboarding.textPrimary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: AppOnboarding.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(height: ob(8)),
                        ObTextLink(
                          lead: l10n.noAccount,
                          link: l10n.signUp,
                          onTap: _toOnboarding,
                        ),
                      ],
                    ),
                  ),
                  if (context.canPop())
                    ob.at(
                      left: 20,
                      top: 52,
                      width: 48,
                      height: 48,
                      child: ObBackButton(onTap: () => context.pop()),
                    ),
                  // Dev/beta: into the app without an account (same spot
                  // and style as the Welcome step's Skip).
                  if (kDebugMode || kBetaFreeAccess)
                    ob.at(
                      right: 20,
                      top: 52,
                      height: 48,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: isLoading ? null : _skipToApp,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: ob(8)),
                          child: Center(
                            child: Text(
                              l10n.skip,
                              style: ob.text(13,
                                  weight: FontWeight.w600,
                                  color: AppOnboarding.textPrimary
                                      .withValues(alpha: .7)),
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

/// A 374×79 provider pill: white for Apple (Sign in with Apple's style on
/// dark backgrounds), the onboarding's dark glass for Google with the
/// standard multicolour "G" (Google's sign-in branding). Always the Flutter
/// glass: native Liquid Glass stays on the onboarding buttons only.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.leading,
    required this.label,
    required this.onTap,
    this.light = false,
    this.loading = false,
  });

  final Widget leading;
  final String label;
  final VoidCallback? onTap;
  final bool light;

  /// Spinner in place of the content (this provider's sign-in is running).
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final fg = light ? Colors.black : AppOnboarding.textPrimary;
    final content = loading
        ? SizedBox.square(
            dimension: ob(28),
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              SizedBox(width: ob(12)),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child:
                      Text(label, maxLines: 1, style: ob.text(22, color: fg)),
                ),
              ),
            ],
          );
    return SizedBox(
      width: ob(374),
      height: ob(79),
      child: AnimatedOpacity(
        opacity: onTap == null && !loading ? 0.5 : 1,
        duration: const Duration(milliseconds: 200),
        curve: AppOnboarding.entranceCurve,
        child: ObPressable(
          onTap: onTap,
          child: light
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ob(40)),
                  ),
                  child: Center(child: content),
                )
              : ObLiquidGlass(
                  tint: ObLiquidGlass.dark,
                  child: Center(child: content),
                ),
        ),
      ),
    );
  }
}
