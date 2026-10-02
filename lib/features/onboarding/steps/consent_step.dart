import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/app_constants.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/legal_agreement_text.dart';

Duration _s(double seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

/// Health-data consent — before the body-data section (Art. 9 GDPR).
///
/// Weight, height, target weight, health issues and injuries are health
/// data, so they're only asked with explicit consent: an unticked box the
/// user ticks, then Continue. "Continue without health data" skips those
/// questions entirely (the flow drops them) and nothing health-related is
/// stored — consent must be freely given, so the app stays usable without.
class HealthConsentStep extends ConsumerWidget {
  const HealthConsentStep({required this.onDecline, super.key});

  /// Records the decline and moves on (the flow screen's `_next`).
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final consented =
        ref.watch(onboardingProvider.select((d) => d.hasHealthConsent));
    final notifier = ref.read(onboardingProvider.notifier);
    final points = [
      l10n.obConsentPointUse,
      l10n.obConsentPointPrivate,
      l10n.obConsentPointWithdraw,
    ];

    return ObArtboard(
      children: [
        ob.centered(
          top: 100,
          inset: 24,
          child: Text(
            l10n.obConsentTitle,
            textAlign: TextAlign.center,
            style: ob.text(22),
          ),
        ),
        ob.at(
          left: 170,
          top: 160,
          width: 100,
          height: 100,
          child: ObEntrance(
            delay: _s(.08),
            dy: 0,
            scaleFrom: .92,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppOnboarding.card,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.health_and_safety_rounded,
                color: AppOnboarding.lime,
                size: ob(50),
              ),
            ),
          ),
        ),
        // Body → points → consent card → policy link flow in one column:
        // German/Spanish run a line or two longer per block than English,
        // so fixed tops would collide. Spare room splits 2:1 above/below
        // the card (English lands where the fixed layout had it); if large
        // system text still overflows, the block scrolls — the decline link
        // below stays pinned, so saying no never hides below the fold.
        ob.at(
          left: 24,
          right: 24,
          top: 288,
          height: 474,
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: ob(16)),
                        child: ObEntrance(
                          delay: _s(.18),
                          child: Text(
                            l10n.obConsentBody,
                            textAlign: TextAlign.center,
                            style: ob.text(15,
                                weight: FontWeight.w600, lineHeight: 21),
                          ),
                        ),
                      ),
                      SizedBox(height: ob(18)),
                      Padding(
                        padding: EdgeInsets.only(left: ob(20), right: ob(16)),
                        child: ObEntrance(
                          delay: _s(.28),
                          child: Column(
                            children: [
                              for (final point in points)
                                Padding(
                                  padding: EdgeInsets.only(bottom: ob(12)),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check_rounded,
                                        color: AppOnboarding.lime,
                                        size: ob(18),
                                      ),
                                      SizedBox(width: ob(12)),
                                      Expanded(
                                        child: Text(
                                          point,
                                          style: ob.text(13, lineHeight: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: ob(16)),
                      const Spacer(flex: 2),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: ob(9)),
                        child: ObEntrance(
                          delay: _s(.38),
                          child: _ConsentCard(
                            checked: consented,
                            text: l10n.obConsentAgree,
                            onTap: notifier.toggleHealthConsent,
                          ),
                        ),
                      ),
                      SizedBox(height: ob(8)),
                      ObEntrance(
                        delay: _s(.46),
                        dy: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => openLegalLink(
                              context, AppConstants.healthDataUrl),
                          child: Padding(
                            padding: EdgeInsets.all(ob(6)),
                            child: Text(
                              l10n.privacyPolicy,
                              style: _underlined(
                                ob.text(12,
                                    weight: FontWeight.w600,
                                    color: AppOnboarding.textMuted),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ob.centered(
          top: 772,
          child: ObEntrance(
            delay: _s(.5),
            dy: 0,
            child: Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onDecline();
                },
                child: Padding(
                  padding: EdgeInsets.all(ob(8)),
                  child: Text(
                    l10n.obConsentDecline,
                    style: _underlined(
                      ob.text(15, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static TextStyle _underlined(TextStyle s) => s.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: s.color,
      );
}

/// The unticked-by-default consent box with its statement; the whole card
/// toggles.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.checked,
    required this.text,
    required this.onTap,
  });

  final bool checked;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return MergeSemantics(
      child: Semantics(
        checked: checked,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: AppOnboarding.select,
            padding: EdgeInsets.all(ob(18)),
            decoration: BoxDecoration(
              color: AppOnboarding.card,
              borderRadius: BorderRadius.circular(ob(24)),
              border: Border.all(
                color: checked ? AppOnboarding.lime : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: AppOnboarding.select,
                  width: ob(26),
                  height: ob(26),
                  decoration: BoxDecoration(
                    color: checked ? AppOnboarding.lime : Colors.transparent,
                    borderRadius: BorderRadius.circular(ob(8)),
                    border: Border.all(
                      color:
                          checked ? AppOnboarding.lime : AppOnboarding.textMuted,
                      width: 2,
                    ),
                  ),
                  child: checked
                      ? Icon(Icons.check_rounded,
                          color: Colors.black, size: ob(18))
                      : null,
                ),
                SizedBox(width: ob(14)),
                Expanded(
                  child: Text(
                    text,
                    style: ob.text(13, weight: FontWeight.w600, lineHeight: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
