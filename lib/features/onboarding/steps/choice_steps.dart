import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/onboarding/onboarding_format.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// Stagger helper: the handoff's per-item `delay` in seconds.
Duration _s(double seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

// ─────────────────────────────────────────────────────────────────────────────
// 02 — Gender
// ─────────────────────────────────────────────────────────────────────────────

class GenderStep extends ConsumerWidget {
  const GenderStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final gender = ref.watch(onboardingProvider.select((d) => d.gender));
    final notifier = ref.read(onboardingProvider.notifier);

    return ObArtboard(
      children: [
        ob.centered(
          top: 94,
          child: Text(
            l10n.selectGender,
            style: ob.text(30, letterSpacing: -0.3),
          ),
        ),
        ob.at(
          left: 60,
          right: 60,
          top: 137,
          child: Text(
            l10n.obGenderSubtitle,
            textAlign: TextAlign.center,
            style: ob.text(11,
                color: AppOnboarding.textSubtitle, lineHeight: 13),
          ),
        ),
        ob.at(
          left: 20,
          top: 230,
          width: 215,
          height: 530,
          child: ObEntrance(
            delay: _s(.1),
            duration: const Duration(seconds: 1),
            child: _GenderFigure(
              asset: 'assets/onboarding/male.png',
              imageWidth: 215,
              imageHeight: 470,
              label: l10n.male,
              selected: gender == 'male',
              dimmed: gender == 'female',
              brightnessBoost: 1,
              onTap: () => notifier.setGender('male'),
            ),
          ),
        ),
        ob.at(
          left: 235,
          top: 250,
          width: 180,
          height: 505,
          child: ObEntrance(
            delay: _s(.3),
            duration: const Duration(seconds: 1),
            child: _GenderFigure(
              asset: 'assets/onboarding/female.png',
              imageWidth: 180,
              imageHeight: 445,
              label: l10n.female,
              selected: gender == 'female',
              dimmed: gender == 'male',
              // The female render is darker; the handoff lifts it 1.9×.
              brightnessBoost: 1.9,
              onTap: () => notifier.setGender('female'),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderFigure extends StatelessWidget {
  const _GenderFigure({
    required this.asset,
    required this.imageWidth,
    required this.imageHeight,
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.brightnessBoost,
    required this.onTap,
  });

  final String asset;
  final double imageWidth;
  final double imageHeight;
  final String label;
  final bool selected;
  final bool dimmed;
  final double brightnessBoost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final brightness =
        (selected ? 1.05 : dimmed ? 0.32 : 0.62) * brightnessBoost;
    final scale = selected ? 1.03 : dimmed ? 0.97 : 1.0;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Soft white light behind the picked figure.
            Positioned(
              left: ob(-20),
              right: ob(-20),
              top: ob(-30),
              height: ob(imageHeight),
              child: AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                // `ellipse 50% 48% at 50% 42%` of a (width + 40) × height
                // box: the circle's radius is half the (shorter) width,
                // stretched vertically to 48% of the height.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.16),
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.7],
                      transform: ObEllipse(
                        center: const Alignment(0, -0.16),
                        sy: 0.48 * imageHeight / (0.5 * (imageWidth + 40)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: ob(imageWidth),
              height: ob(imageHeight),
              child: AnimatedScale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                duration: const Duration(milliseconds: 500),
                curve: AppOnboarding.entranceCurve,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: brightness),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.ease,
                  builder: (context, b, child) => ColorFiltered(
                    colorFilter: ColorFilter.matrix([
                      b, 0, 0, 0, 0, //
                      0, b, 0, 0, 0, //
                      0, 0, b, 0, 0, //
                      0, 0, 0, 1, 0, //
                    ]),
                    child: child,
                  ),
                  child: Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: ob(imageHeight + 4),
              child: Column(
                children: [
                  ObAnimatedTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: ob.text(
                      selected ? 22 : 18,
                      color: selected
                          ? AppOnboarding.textPrimary
                          : AppOnboarding.textFigure,
                    ),
                    child: Text(label),
                  ),
                  SizedBox(height: ob(6)),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: AppOnboarding.entranceCurve,
                    width: ob(selected ? 24 : 0),
                    height: ob(3),
                    decoration: BoxDecoration(
                      color: AppOnboarding.lime,
                      borderRadius: BorderRadius.circular(ob(2)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 03 / 13 — Goals & Issues grids, 04 / 14 — their detail screens
// ─────────────────────────────────────────────────────────────────────────────

/// One card of the 2×2 icon grid.
class _GridItem {
  const _GridItem({
    required this.art,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Asset stem, e.g. `goal_muscle` → `_lime.png` / `_ink.png`.
  final String art;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.items});

  final List<_GridItem> items;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return Wrap(
      spacing: ob(11),
      runSpacing: ob(12),
      children: [
        for (var i = 0; i < items.length; i++)
          ObEntrance(
            delay: _s(.06 + i * .05),
            child: SizedBox(
              width: ob(193),
              height: ob(220),
              child: ObChoice(
                selected: items[i].selected,
                onTap: items[i].onTap,
                radius: 24,
                semanticLabel: items[i].label,
                child: Stack(
                  children: [
                    Positioned(
                      left: ob(31),
                      top: ob(30),
                      width: ob(131),
                      height: ob(114),
                      child: AnimatedScale(
                        scale: items[i].selected ? 1.04 : 1,
                        duration: const Duration(milliseconds: 350),
                        curve: AppOnboarding.entranceCurve,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedOpacity(
                              opacity: items[i].selected ? 0 : 1,
                              duration: const Duration(milliseconds: 180),
                              child: Image.asset(
                                'assets/onboarding/${items[i].art}_lime.png',
                                excludeFromSemantics: true,
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: items[i].selected ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Image.asset(
                                'assets/onboarding/${items[i].art}_ink.png',
                                excludeFromSemantics: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: ob(8),
                      right: ob(8),
                      top: ob(160),
                      child: ObChoiceLabel(
                        items[i].label,
                        selected: items[i].selected,
                        style: ob.text(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class GoalStep extends ConsumerWidget {
  const GoalStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final goal = ref.watch(onboardingProvider.select((d) => d.goal));
    final notifier = ref.read(onboardingProvider.notifier);

    return ObArtboard(
      children: [
        ob.centered(
          top: 94,
          inset: 20,
          child: Text(
            l10n.obGoalsTitle,
            textAlign: TextAlign.center,
            style: ob.text(30, letterSpacing: -0.3),
          ),
        ),
        ob.centered(
          top: 145,
          inset: 30,
          child: Text(
            l10n.obGoalsSubtitle,
            textAlign: TextAlign.center,
            style: ob.text(11, color: AppOnboarding.textSubtitle),
          ),
        ),
        ob.at(
          left: 21,
          top: 259,
          width: 397,
          child: _IconGrid(
            items: [
              for (final g in OnboardingGoal.values)
                _GridItem(
                  art: 'goal_${g.art}',
                  label: l10n.goalLabel(g),
                  selected: goal == g,
                  onTap: () => notifier.setGoal(g),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class IssuesStep extends ConsumerWidget {
  const IssuesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final issue = ref.watch(onboardingProvider.select((d) => d.issue));
    final notifier = ref.read(onboardingProvider.notifier);

    return ObArtboard(
      children: [
        ob.at(
          left: 50,
          right: 50,
          top: 98,
          child: Text(
            l10n.obIssuesTitle,
            textAlign: TextAlign.center,
            style: ob.text(22, lineHeight: 30),
          ),
        ),
        ob.at(
          left: 21,
          top: 283,
          width: 397,
          child: _IconGrid(
            items: [
              for (final i in HealthIssue.values)
                _GridItem(
                  art: 'issue_${i.art}',
                  label: l10n.issueLabel(i),
                  selected: issue == i,
                  onTap: () => notifier.setIssue(i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Large lime icon + headline + body, shared by goal and issue detail.
class _DetailLayout extends StatelessWidget {
  const _DetailLayout({
    required this.title,
    required this.art,
    required this.head,
    required this.body,
    required this.imageTop,
    required this.headTop,
    required this.bodyTop,
    required this.bodyInset,
  });

  final String title;
  final String art;
  final String head;
  final String body;
  final double imageTop;
  final double headTop;
  final double bodyTop;
  final double bodyInset;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return ObArtboard(
      children: [
        ob.centered(
          top: 100,
          inset: 30,
          child: Text(title, textAlign: TextAlign.center, style: ob.text(22)),
        ),
        ob.at(
          left: 40,
          top: imageTop,
          width: 360,
          height: 315,
          child: ObEntrance(
            delay: _s(.12),
            duration: const Duration(milliseconds: 800),
            dy: 0,
            scaleFrom: 0.92,
            child: Image.asset(
              'assets/onboarding/${art}_lime.png',
              excludeFromSemantics: true,
            ),
          ),
        ),
        ob.at(
          left: 30,
          right: 30,
          top: headTop,
          child: ObEntrance(
            delay: _s(.35),
            child: Text(head, textAlign: TextAlign.center, style: ob.text(22)),
          ),
        ),
        ob.at(
          left: bodyInset,
          right: bodyInset,
          top: bodyTop,
          child: ObEntrance(
            delay: _s(.45),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: ob.text(15, weight: FontWeight.w600, lineHeight: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class GoalDetailStep extends ConsumerWidget {
  const GoalDetailStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final goal = ref.watch(onboardingProvider.select((d) => d.goal)) ??
        OnboardingGoal.buildMuscle;
    return _DetailLayout(
      title: l10n.goalLabel(goal),
      art: 'goal_${goal.art}',
      head: l10n.goalHead(goal),
      body: l10n.goalBody(goal),
      imageTop: 235,
      headTop: 567,
      bodyTop: 618,
      bodyInset: 55,
    );
  }
}

class IssueDetailStep extends ConsumerWidget {
  const IssueDetailStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final issue = ref.watch(onboardingProvider.select((d) => d.issue)) ??
        HealthIssue.sitting;
    return _DetailLayout(
      title: l10n.issueLabel(issue),
      art: 'issue_${issue.art}',
      head: l10n.issueHead(issue),
      body: l10n.issueBody(issue),
      imageTop: 245,
      headTop: 586,
      bodyTop: 637,
      bodyInset: 34,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 18 — Experience
// ─────────────────────────────────────────────────────────────────────────────

class ExperienceStep extends ConsumerWidget {
  const ExperienceStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final picked = ref.watch(onboardingProvider.select((d) => d.experience));
    final notifier = ref.read(onboardingProvider.notifier);

    return ObArtboard(
      children: [
        ob.at(
          left: 60,
          right: 60,
          top: 94,
          child: Text(
            l10n.obExperienceTitle,
            textAlign: TextAlign.center,
            style: ob.text(22, lineHeight: 28),
          ),
        ),
        for (final (i, level) in ExperienceLevel.values.indexed)
          ob.at(
            left: 38,
            top: 214 + i * 187.0,
            width: 358,
            height: 176,
            child: ObEntrance(
              delay: _s(.08 + i * .07),
              child: ObChoice(
                selected: picked == level,
                onTap: () => notifier.setExperience(level),
                radius: 24,
                semanticLabel:
                    '${l10n.experienceLabel(level)}, ${l10n.experienceSub(level)}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ob(24)),
                  child: Stack(
                    children: [
                      Positioned(
                        left: ob(224),
                        top: 0,
                        width: ob(134),
                        height: ob(176),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedOpacity(
                              opacity: picked == level ? 0 : 1,
                              duration: const Duration(milliseconds: 180),
                              child: Image.asset(
                                'assets/onboarding/exp_$i.png',
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: picked == level ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Image.asset(
                                'assets/onboarding/exp_${i}_lime.png',
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: ob(8),
                        width: ob(208),
                        top: ob(66),
                        child: ObChoiceLabel(
                          l10n.experienceLabel(level),
                          selected: picked == level,
                          style: ob.text(20),
                        ),
                      ),
                      Positioned(
                        left: ob(8),
                        width: ob(208),
                        top: ob(93),
                        child: ObChoiceLabel(
                          l10n.experienceSub(level),
                          selected: picked == level,
                          style: ob.text(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 20 — Training days
// ─────────────────────────────────────────────────────────────────────────────

class TrainingDaysStep extends ConsumerWidget {
  const TrainingDaysStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final days = ref.watch(onboardingProvider.select((d) => d.trainingDays));
    final reminder = ref.watch(onboardingProvider.select((d) => d.reminder));
    final notifier = ref.read(onboardingProvider.notifier);

    return ObArtboard(
      children: [
        ob.at(
          left: 40,
          right: 40,
          top: 98,
          child: Text(
            l10n.obDaysTitle,
            textAlign: TextAlign.center,
            style: ob.text(22, lineHeight: 30),
          ),
        ),
        ob.at(
          left: 40,
          top: 308,
          width: 360,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: ob(10),
            runSpacing: ob(11),
            children: [
              for (var weekday = 1; weekday <= 7; weekday++)
                ObEntrance(
                  delay: _s(.06 + (weekday - 1) * .04),
                  duration: const Duration(milliseconds: 550),
                  child: SizedBox(
                    width: ob(175),
                    height: ob(72),
                    child: ObChoice(
                      selected: days.contains(weekday),
                      onTap: () => notifier.toggleTrainingDay(weekday),
                      radius: 36,
                      semanticLabel: obWeekdayName(context, weekday),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: ob(12)),
                          child: ObChoiceLabel(
                            obWeekdayName(context, weekday),
                            selected: days.contains(weekday),
                            style: ob.text(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ob.at(
          left: 33,
          top: 761,
          width: 374,
          height: 60,
          child: Semantics(
            toggled: reminder,
            label: l10n.obReminderTitle,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                notifier.setReminder(on: !reminder);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppOnboarding.card,
                  borderRadius: BorderRadius.circular(ob(30)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: ob(22),
                      top: ob(14),
                      right: ob(80),
                      child: Text(
                        l10n.obReminderTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ob.text(15),
                      ),
                    ),
                    Positioned(
                      left: ob(22),
                      top: ob(33),
                      right: ob(80),
                      child: Text(
                        l10n.obReminderBody,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ob.text(10, color: AppOnboarding.textMuted),
                      ),
                    ),
                    Positioned(
                      left: ob(311),
                      top: ob(14),
                      child: ObSwitch(value: reminder),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
