import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:my_gym_bro/core/services/notification_service.dart';
import 'package:my_gym_bro/core/services/subscription_sync_service.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_format.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/steps/body_steps.dart'
    show ObRecoveryMap;
import 'package:my_gym_bro/features/onboarding/widgets/ob_curve.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/app_constants.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/legal_agreement_text.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paywall (design_handoff_onboarding v3, screen 22)
//
// One view, three entry points:
//   • the last onboarding step — personal target from the fresh answers, and
//     a "LET'S GO" success overlay that hands off to sign-up;
//   • the paywall gate (/paywall while locked) — not dismissible;
//   • a voluntary open (/paywall from Settings) — back button, pops on buy.
// Apple 3.1.2 disclosures (billed amount, restore, Terms, Privacy,
// auto-renew terms) are always on the page.
// ─────────────────────────────────────────────────────────────────────────────

/// The personal-target inputs for carousel slide 1.
@immutable
class PaywallPlan {
  const PaywallPlan({
    required this.currentKg,
    required this.targetKg,
    required this.metric,
    required this.female,
    this.goal,
    this.trainingDays = 0,
    this.focus = const [],
  });

  /// From the onboarding answers.
  factory PaywallPlan.fromOnboarding(OnboardingData d) => PaywallPlan(
        currentKg: d.weightKg,
        targetKg: d.effectiveTargetKg,
        metric: d.weightMetric,
        female: d.isFemale,
        goal: d.goal,
        trainingDays: d.trainingDays.length,
        focus: FocusArea.values.where(d.focus.contains).toList(),
      );

  final double currentKg;
  final double targetKg;
  final bool metric;
  final bool female;
  final OnboardingGoal? goal;
  final int trainingDays;
  final List<FocusArea> focus;

  OnboardingPrediction get prediction =>
      OnboardingPrediction.of(currentKg: currentKg, targetKg: targetKg);

  /// Rebuilt from the persisted answers (the gate / Settings entry points);
  /// null when the profile never recorded a target.
  static PaywallPlan? fromProfile(UserProfile? p) {
    final current = p?.bodyWeightKg;
    final target = p?.targetWeightKg;
    if (p == null || current == null || target == null) return null;
    List<Object?> list(String? json) {
      if (json == null || json.isEmpty) return const [];
      try {
        return jsonDecode(json) as List<Object?>;
      } on FormatException {
        return const [];
      }
    }

    return PaywallPlan(
      currentKg: current,
      targetKg: target,
      metric: p.weightUnit != 'lbs',
      female: p.gender == 'female',
      goal: OnboardingGoal.fromWire(p.goal),
      trainingDays: list(p.trainingDays).length,
      focus: [
        for (final w in list(p.focusAreas))
          if (FocusArea.fromWire(w as String?) case final a?) a,
      ],
    );
  }
}

/// `/paywall` — the gate and the voluntary open.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When the gate is active (trial elapsed / expired) the paywall is the
    // only way forward — it must not be dismissible by back gesture or a
    // back button. When opened voluntarily (e.g. from Settings) it is.
    final locked = ref.watch(subscriptionLockedProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;

    void dismiss() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    }

    return PopScope(
      canPop: !locked,
      child: Scaffold(
        backgroundColor: AppOnboarding.background,
        body: ObFrameScope(
          child: PaywallView(
            locked: locked,
            plan: PaywallPlan.fromProfile(profile),
            female: profile?.gender == 'female',
            onBack: locked ? null : () => context.pop(),
            // Leave the paywall after a successful purchase/restore. Pushed on
            // top of a stack (voluntary open) → pop; reached via the gate
            // redirect (nothing beneath) → home.
            onPurchased: (_) => dismiss(),
          ),
        ),
      ),
    );
  }
}

enum _Plan { monthly, yearly }

/// The paywall itself. [onBack] draws the header chevron (the onboarding
/// flow draws its own). [onPurchased] receives whether a free trial started.
class PaywallView extends ConsumerStatefulWidget {
  const PaywallView({
    required this.locked,
    required this.onPurchased,
    this.plan,
    this.female = false,
    this.onBack,
    this.onSkip,
    super.key,
  });

  final bool locked;
  final PaywallPlan? plan;
  final bool female;
  final VoidCallback? onBack;
  final void Function(bool trialStarted) onPurchased;

  /// Dev/beta bypass (shown only when non-null).
  final VoidCallback? onSkip;

  @override
  ConsumerState<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends ConsumerState<PaywallView> {
  // RevenueCat product identifiers — must match the dashboard.
  static const _monthlyId = 'mgb_premium_monthly';
  static const _yearlyId = 'mgb_premium_annual';

  // Static placeholders until store prices load (dev builds never load them).
  static const _fallbackMonthly = 7.99;
  static const _fallbackYearly = 49.99;

  _Plan _selected = _Plan.yearly;
  bool _loading = false;
  String? _error;

  // Store-localized prices from RevenueCat offerings (Apple 3.1.2).
  String? _monthlyPrice;
  String? _yearlyPrice;
  String? _yearlyPerMonth;
  double? _monthlyAmount;
  double? _yearlyAmount;

  /// Free-trial length from the product's intro offer (1 week in ASC).
  int _trialDays = 7;

  /// False once RevenueCat says the user can't get the intro offer.
  bool _trialEligible = true;

  int _slide = 0;
  Timer? _carousel;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStore());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _restartCarousel();
  }

  @override
  void dispose() {
    _carousel?.cancel();
    super.dispose();
  }

  bool get _trialOffered => !widget.locked && _trialEligible;

  void _restartCarousel() {
    _carousel?.cancel();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _carousel = Timer.periodic(const Duration(milliseconds: 3300), (_) {
      if (mounted) setState(() => _slide = (_slide + 1) % _slideCount);
    });
  }

  void _goToSlide(int i) {
    setState(() => _slide = i % _slideCount);
    _restartCarousel();
  }

  int get _slideCount =>
      (widget.plan != null ? 1 : 0) + 2 + (_trialOffered ? 1 : 0);

  /// Prices + trial eligibility. RevenueCat is not configured in dev
  /// (placeholder keys skip `Purchases.configure`), so any failure keeps
  /// the static fallbacks — the screen must always render.
  Future<void> _loadStore() async {
    try {
      if (!await Purchases.isConfigured) return;
      final current = (await Purchases.getOfferings()).current;
      if (current == null || !mounted) return;
      final monthly = _productFor(current, _monthlyId, current.monthly);
      final annual = _productFor(current, _yearlyId, current.annual);
      final intro = (annual ?? monthly)?.introductoryPrice;
      setState(() {
        _monthlyPrice = monthly?.priceString;
        _yearlyPrice = annual?.priceString;
        _yearlyPerMonth = annual == null ? null : _perMonth(annual);
        _monthlyAmount = monthly?.price;
        _yearlyAmount = annual?.price;
        if (intro != null && intro.price == 0) {
          _trialDays = switch (intro.periodUnit) {
            PeriodUnit.day => intro.periodNumberOfUnits,
            PeriodUnit.week => intro.periodNumberOfUnits * 7,
            _ => _trialDays,
          };
        }
      });
      await _loadEligibility();
    } on Exception {
      // Offerings unavailable — keep fallbacks.
    }
  }

  /// iOS knows intro-offer eligibility up front; Android reports "unknown"
  /// and Play only attaches the free phase to eligible users, so unknown
  /// keeps the trial copy. Any failure keeps it too (the store sheet always
  /// shows the real terms before the user confirms).
  Future<void> _loadEligibility() async {
    try {
      final eligibility =
          await Purchases.checkTrialOrIntroductoryPriceEligibility(
        [_monthlyId, _yearlyId],
      );
      final statuses = eligibility.values.map((e) => e.status).toSet();
      if (!mounted || statuses.isEmpty) return;
      setState(() {
        _trialEligible = statuses.any(
          (s) =>
              s == IntroEligibilityStatus.introEligibilityStatusEligible ||
              s == IntroEligibilityStatus.introEligibilityStatusUnknown,
        );
        _slide = _slide.clamp(0, _slideCount - 1);
      });
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[Paywall] eligibility check failed: $e');
    }
  }

  static StoreProduct? _productFor(
    Offering offering,
    String productId,
    Package? fallback,
  ) {
    for (final p in offering.availablePackages) {
      if (p.storeProduct.identifier == productId) return p.storeProduct;
    }
    return fallback?.storeProduct;
  }

  /// The yearly plan's effective monthly cost, formatted to mirror the store's
  /// own currency presentation (symbol/placement) by swapping the numeric part
  /// of the annual `priceString`. Returns null if the string has no number.
  static String? _perMonth(StoreProduct annual) {
    final match = RegExp('[0-9][0-9.,]*').firstMatch(annual.priceString);
    if (match == null) return null;
    final original = match.group(0)!;
    // Treat ',' as the decimal separator when it trails any '.' (e.g. 49,99).
    final decimalIsComma = original.contains(',') &&
        (!original.contains('.') ||
            original.lastIndexOf(',') > original.lastIndexOf('.'));
    final perMonth = (annual.price / 12.0)
        .toStringAsFixed(2)
        .replaceAll('.', decimalIsComma ? ',' : '.');
    return annual.priceString.replaceRange(match.start, match.end, perMonth);
  }

  /// Real yearly saving vs. twelve months, from store prices when known.
  int get _savingPercent {
    final m = _monthlyAmount ?? _fallbackMonthly;
    final y = _yearlyAmount ?? _fallbackYearly;
    if (m <= 0) return 0;
    return ((1 - y / (m * 12)) * 100).round().clamp(0, 99);
  }

  String get _monthly => _monthlyPrice ?? r'$7.99';
  String get _yearly => _yearlyPrice ?? r'$49.99';
  String get _yearlyMonthly => _yearlyPerMonth ?? r'$4.17';

  Future<void> _purchase() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Unconfigured Purchases fatalErrors on iOS — bail with the normal
      // "no offerings" copy instead of dying.
      if (!await Purchases.isConfigured) {
        setState(() => _error = l10n.noOfferingsAvailable);
        return;
      }
      final current = (await Purchases.getOfferings()).current;
      if (current == null) {
        setState(() => _error = l10n.noOfferingsAvailable);
        return;
      }
      final productId = _selected == _Plan.yearly ? _yearlyId : _monthlyId;
      final package = current.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier == productId,
        orElse: () => _selected == _Plan.yearly
            ? (current.annual ?? current.availablePackages.first)
            : (current.monthly ?? current.availablePackages.first),
      );

      final info = await Purchases.purchasePackage(package);
      // Reconcile entitlement → local profile so the paywall gate
      // (`subscriptionLockedProvider`) releases. Pre-sign-up (onboarding)
      // there's no profile yet; sign-in's RevenueCat login syncs it then.
      await SubscriptionSyncService.syncNow(ref.read(userProfileDaoProvider));
      final trial = info.entitlements.active[SubscriptionSyncService.entitlementId]
              ?.periodType ==
          PeriodType.trial;
      if (trial) unawaited(_scheduleTrialReminder(l10n));
      if (mounted) widget.onPurchased(trial);
    } on PlatformException catch (e) {
      // purchases_flutter surfaces errors as PlatformException — map to a
      // PurchasesErrorCode; user cancelling the sheet is not an error.
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        setState(() => _error = l10n.purchaseFailed);
        CrashReporter.recordError(e, reason: 'Paywall purchase failed');
      }
    } on Exception catch (e) {
      setState(() => _error = l10n.purchaseFailed);
      CrashReporter.recordError(e, reason: 'Paywall purchase exception');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The "DAY 5 · Reminder" the trial timeline promises: a heads-up two days
  /// before the first charge.
  Future<void> _scheduleTrialReminder(AppLocalizations l10n) async {
    try {
      await NotificationService.scheduleTrialEndingReminder(
        title: l10n.obTrialReminderTitle,
        body: l10n.obTrialReminderBody,
        when: DateTime.now().add(Duration(days: _trialDays - 2)),
      );
    } on Exception catch (e) {
      CrashReporter.recordError(e, reason: 'Trial reminder scheduling failed');
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await Purchases.isConfigured) {
        setState(() => _error = l10n.restoreFailed);
        return;
      }
      final info = await Purchases.restorePurchases();
      await SubscriptionSyncService.syncNow(ref.read(userProfileDaoProvider));
      if (!info.entitlements.active
          .containsKey(SubscriptionSyncService.entitlementId)) {
        setState(() => _error = l10n.restoreFailed);
        return;
      }
      if (mounted) widget.onPurchased(false);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        setState(() => _error = l10n.restoreFailed);
        CrashReporter.recordError(e, reason: 'Paywall restore failed');
      }
    } on Exception catch (e) {
      setState(() => _error = l10n.restoreFailed);
      CrashReporter.recordError(e, reason: 'Paywall restore failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Layout ──────────────────────────────────────────────────────────────

  /// Artboard y of the dots; the plan/CTA block sits 18 units above the
  /// handoff so Restore · Terms · Privacy fit on the first screen.
  static const _dotsY = 580.0;
  static const _monthlyY = 611.0;
  static const _yearlyY = 700.0;
  static const _captionY = 786.0;
  static const _ctaY = 808.0;
  static const _noteY = 897.0;
  static const _linksY = 915.0;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final slides = <Widget>[
      if (widget.plan != null) _TargetSlide(plan: widget.plan!),
      _RecoverySlide(female: widget.plan?.female ?? widget.female),
      const _RanksSlide(),
      if (_trialOffered)
        _TrialSlide(
          days: _trialDays,
          charge: _selected == _Plan.yearly
              ? l10n.obTrialThenYearly(_yearly)
              : l10n.obTrialThenMonthly(_monthly),
        ),
    ];
    final active = _slide.clamp(0, slides.length - 1);
    final muted =
        ob.text(10, weight: FontWeight.w600, color: AppOnboarding.textMuted);
    final bold = ob.text(10);

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: SizedBox(
          height: box.maxHeight + ob(96),
          child: ObArtboard(
            children: [
              if (widget.onBack != null)
                ob.at(
                  left: 20,
                  top: 52,
                  width: 48,
                  height: 48,
                  child: ObBackButton(onTap: widget.onBack!),
                ),
              if (widget.onSkip != null)
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
                              color: AppOnboarding.textMuted),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Carousel (swipe or tap a dot; auto-advances every 3.3s)
              ob.at(
                left: 0,
                top: 96,
                width: 440,
                height: 490,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v.abs() < 150) return;
                    _goToSlide(active + (v < 0 ? 1 : slides.length - 1));
                  },
                  child: Stack(
                    children: [
                      for (final (i, slide) in slides.indexed)
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: i != active,
                            child: AnimatedOpacity(
                              opacity: i == active ? 1 : 0,
                              duration: const Duration(milliseconds: 450),
                              child: AnimatedSlide(
                                offset: Offset(
                                  i == active ? 0 : (i < active ? -24 : 24) / 440,
                                  0,
                                ),
                                duration: const Duration(milliseconds: 600),
                                curve: AppOnboarding.entranceCurve,
                                child: slide,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              ob.centered(
                top: _dotsY,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < slides.length; i++)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _goToSlide(i),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: ob(3.5),
                            vertical: ob(8),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: AppOnboarding.entranceCurve,
                            width: ob(i == active ? 22 : 7),
                            height: ob(7),
                            decoration: BoxDecoration(
                              color: i == active
                                  ? AppOnboarding.lime
                                  : AppOnboarding.dotInactive,
                              borderRadius: BorderRadius.circular(ob(4)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Plans
              ob.at(
                left: 33,
                top: _monthlyY,
                width: 374,
                height: 79,
                child: _PlanPill(
                  title: l10n.monthlyPlan,
                  subtitle: l10n.pricePerMonth(_monthly),
                  selected: _selected == _Plan.monthly,
                  onTap: () => setState(() => _selected = _Plan.monthly),
                ),
              ),
              ob.at(
                left: 33,
                top: _yearlyY,
                width: 374,
                height: 79,
                child: _PlanPill(
                  title: l10n.yearlyPlan,
                  subtitle: l10n.pricePerMonth(_yearlyMonthly),
                  badge: _savingPercent > 0
                      ? l10n.obDiscount(_savingPercent)
                      : null,
                  selected: _selected == _Plan.yearly,
                  onTap: () => setState(() => _selected = _Plan.yearly),
                ),
              ),
              ob.centered(
                top: _captionY,
                child: Text(l10n.pricePerYear(_yearly), style: muted),
              ),

              // ── CTA
              ob.at(
                left: 33,
                top: _ctaY,
                width: 374,
                height: 79,
                // Lime glass: natively `.prominentGlass()` on iOS 26. Off
                // iOS, inside this scroll view the Flutter shader can't run,
                // so it's the frosted fallback with a lit rim.
                child: ObLiquidGlassButton(
                  label: widget.locked
                      ? l10n.subscribeToContinue
                      : _trialOffered
                          ? l10n.freeTrial
                          : l10n.obSubscribe,
                  labelColor: Colors.black,
                  tint: AppOnboarding.lime,
                  loading: _loading,
                  onTap: _purchase,
                ),
              ),

              // ── Note (or the purchase error)
              ob.centered(
                top: _noteY,
                inset: 24,
                child: _error != null
                    ? Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: ob.text(11, color: AppOnboarding.fatigued),
                      )
                    : Text.rich(
                        TextSpan(
                          style: muted,
                          children: _selected == _Plan.yearly
                              ? [
                                  TextSpan(text: l10n.obSave, style: bold),
                                  TextSpan(
                                    text:
                                        ' ${l10n.obSaveYearlyRest(_savingPercent)}',
                                  ),
                                ]
                              : obHighlight(
                                  build: (price) => _trialOffered
                                      ? l10n.obMonthlyTrialNote(
                                          _trialDays, price)
                                      : l10n.obMonthlyNote(price),
                                  value: _monthly,
                                  highlight: bold,
                                ),
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),

              // ── Restore · Terms · Privacy (Apple 3.1.2). One line that
              // shrinks for long translations / large text settings.
              ob.centered(
                top: _linksY,
                inset: 16,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FooterLink(
                        label: l10n.restoreSubscription,
                        onTap: _loading ? null : _restore,
                      ),
                      Text('  ·  ', style: muted),
                      _FooterLink(
                        label: l10n.termsOfUse,
                        onTap: () =>
                            openLegalLink(context, AppConstants.termsUrl),
                      ),
                      Text('  ·  ', style: muted),
                      _FooterLink(
                        label: l10n.privacyPolicy,
                        onTap: () =>
                            openLegalLink(context, AppConstants.privacyUrl),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Auto-renewal disclosure, just below the fold.
              ob.at(
                left: 40,
                right: 40,
                top: 962,
                child: Text(
                  l10n.autoRenewDisclosure,
                  textAlign: TextAlign.center,
                  style: ob.text(10,
                      weight: FontWeight.w500,
                      color: AppOnboarding.textMuted,
                      lineHeight: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return Semantics(
      link: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: ob(4)),
          child: Text(
            label,
            style: ob
                .text(10, weight: FontWeight.w600, color: AppOnboarding.textMuted)
                .copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppOnboarding.textMuted,
                ),
          ),
        ),
      ),
    );
  }
}

class _PlanPill extends StatelessWidget {
  const _PlanPill({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return Semantics(
      selected: selected,
      child: ObPressable(
        pressedScale: 0.98,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppOnboarding.select,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ob(40)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF101010)],
            ),
            border: Border.all(
              color: selected
                  ? AppOnboarding.lime
                  : Colors.white.withValues(alpha: 0.14),
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: ob.text(30, lineHeight: 32)),
                    Text(subtitle, style: ob.text(13)),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  right: ob(26),
                  top: ob(27) - (selected ? 2 : 1),
                  child: Container(
                    height: ob(24),
                    padding: EdgeInsets.symmetric(horizontal: ob(10)),
                    decoration: BoxDecoration(
                      color: AppOnboarding.lime,
                      borderRadius: BorderRadius.circular(ob(12)),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        badge!,
                        style: ob.text(12,
                            weight: FontWeight.w800, color: Colors.black),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carousel slides (490 tall, copy at 404 / 434) ─────────────────────────

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.title, required this.body, this.inset = 50});

  final String title;
  final String body;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return Stack(
      children: [
        ob.centered(
          top: 404,
          inset: 30,
          child: Text(title, textAlign: TextAlign.center, style: ob.text(20)),
        ),
        ob.at(
          left: inset,
          right: inset,
          top: 434,
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: ob.text(13,
                weight: FontWeight.w600,
                color: AppOnboarding.textMuted,
                lineHeight: 17),
          ),
        ),
      ],
    );
  }
}

class _TargetSlide extends StatelessWidget {
  const _TargetSlide({required this.plan});

  final PaywallPlan plan;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final date = obShortDate(context, plan.prediction.optimizedDate);
    final weight =
        '${ObUnits.displayWeight(plan.targetKg, metric: plan.metric).floor()}'
        '${plan.metric ? 'KG' : 'LB'}';
    final summary = [
      l10n.goalLabel(plan.goal ?? OnboardingGoal.buildMuscle),
      l10n.obPlanSummaryDays(plan.trainingDays == 0 ? 3 : plan.trainingDays),
      if (plan.focus.isNotEmpty)
        l10n.obPlanSummaryFocus(
          plan.focus.map((a) => obMidSentence(context, l10n.focusLabel(a))).join(', '),
        ),
    ].join(' · ');
    const curve = ObCurve.paywall;
    const dotX = 348.0;

    return Stack(
      children: [
        ob.centered(
          top: 22,
          child: Text(
            l10n.obYourTarget,
            style: ob.text(13, color: AppOnboarding.textMuted),
          ),
        ),
        ob.centered(
          top: 40,
          inset: 12,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                style: ob.display(64, lineHeight: 68, letterSpacing: .5),
                children: [
                  TextSpan(text: '$weight '),
                  TextSpan(
                    text: l10n.obTargetBy(date).toUpperCase(),
                    style: const TextStyle(color: AppOnboarding.lime),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
        // The handoff squeezes a 258-tall curve into 220.
        ob.at(
          left: 0,
          top: 150,
          width: 440,
          height: 220,
          child: CustomPaint(
            painter: _MiniCurvePainter(
              scale: ob.scale,
              dotX: dotX,
              curve: curve,
            ),
          ),
        ),
        _SlideCopy(title: l10n.obBuiltAround, body: summary, inset: 40),
      ],
    );
  }
}

class _MiniCurvePainter extends CustomPainter {
  _MiniCurvePainter({
    required this.scale,
    required this.dotX,
    required this.curve,
  });

  final double scale;
  final double dotX;
  final ObCurve curve;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = scale;
    final sy = scale * 220 / 258;
    canvas.drawPath(
      curve.line(sx: sx, sy: sy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * scale
        ..strokeCap = StrokeCap.round
        ..color = AppOnboarding.graphLine,
    );
    final dot = Paint()..color = AppOnboarding.lime;
    canvas
      ..drawCircle(
        Offset(ObCurve.todayX * sx, curve.startY * sy),
        7 * scale,
        dot,
      )
      ..drawCircle(Offset(dotX * sx, curve.yAt(dotX) * sy), 7 * scale, dot);
  }

  @override
  bool shouldRepaint(_MiniCurvePainter old) =>
      old.scale != scale || old.dotX != dotX || old.curve != curve;
}

class _RecoverySlide extends StatelessWidget {
  const _RecoverySlide({required this.female});

  final bool female;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        ob.at(
          left: 72,
          top: 26,
          width: 296,
          height: 340,
          child: ObRecoveryMap(female: female),
        ),
        _SlideCopy(title: l10n.obTrainReady, body: l10n.obTrainReadyBody),
      ],
    );
  }
}

class _RanksSlide extends StatelessWidget {
  const _RanksSlide();

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        ob.at(
          left: 100,
          top: 40,
          width: 240,
          height: 240,
          child: Image.asset(
            'assets/badges/gold_3.png',
            excludeFromSemantics: true,
          ),
        ),
        ob.centered(
          top: 292,
          inset: 20,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              l10n.obRankRange(l10n.rankBronze, l10n.rankElite).toUpperCase(),
              style: ob.display(40, letterSpacing: 1),
            ),
          ),
        ),
        _SlideCopy(title: l10n.obClimbRanks, body: l10n.obClimbRanksBody),
      ],
    );
  }
}

class _TrialSlide extends StatelessWidget {
  const _TrialSlide({required this.days, required this.charge});

  final int days;

  /// "49.99$ yearly" / "7.99$ monthly" — the first charge.
  final String charge;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final reminderDay = (days - 2).clamp(1, days);
    double x(int day) => 66 + 308 * day / days;
    final nodes = [
      (x(0), l10n.obTrialToday, l10n.obTrialFullAccess, true),
      (x(reminderDay), l10n.obTrialDay(reminderDay), l10n.obTrialReminder, false),
      (x(days), l10n.obTrialDay(days), charge, false),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ob.centered(
          top: 40,
          child: Text(
            l10n.obTrialDaysBig(days).toUpperCase(),
            style: ob.display(128,
                weight: 900, color: AppOnboarding.lime, lineHeight: 120),
          ),
        ),
        ob.centered(
          top: 160,
          child: Padding(
            padding: EdgeInsets.only(left: ob(6)),
            child: Text(
              l10n.obFree.toUpperCase(),
              style: ob.display(46, letterSpacing: 6),
            ),
          ),
        ),
        ob.at(
          left: 66,
          top: 282,
          width: 308,
          height: 2,
          child: const ColoredBox(color: AppOnboarding.track),
        ),
        for (final (cx, key, value, lit) in nodes)
          ob.at(
            left: cx - 60,
            top: 276,
            width: 120,
            child: Column(
              children: [
                Container(
                  width: ob(22),
                  height: ob(22),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppOnboarding.background,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: ob(14),
                    height: ob(14),
                    decoration: BoxDecoration(
                      color: lit ? AppOnboarding.lime : AppOnboarding.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(height: ob(10)),
                Text(
                  key,
                  style: ob.mono(12,
                      color: lit ? AppOnboarding.lime : AppOnboarding.textMuted),
                ),
                SizedBox(height: ob(4)),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: ob.text(13, lineHeight: 16),
                ),
              ],
            ),
          ),
        _SlideCopy(
          title: l10n.obCancelBeforeDay(days),
          body: l10n.obNotChargedUntil,
        ),
      ],
    );
  }
}

/// "LET'S GO" — the onboarding paywall's success state.
class PaywallSuccess extends StatelessWidget {
  const PaywallSuccess({
    required this.line,
    required this.onStart,
    super.key,
  });

  final String line;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    return ObArtboard(
      children: [
        ob.centered(
          top: 360,
          child: ObEntrance(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 700),
            dy: 30,
            child: Text(
              l10n.obLetsGo.toUpperCase(),
              style: ob.display(92,
                  weight: 900, color: AppOnboarding.lime, lineHeight: 92),
            ),
          ),
        ),
        ob.at(
          left: 50,
          right: 50,
          top: 470,
          child: ObEntrance(
            delay: const Duration(milliseconds: 250),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: ob.text(15, weight: FontWeight.w600, lineHeight: 20),
            ),
          ),
        ),
        ob.at(
          left: 33,
          top: 826,
          width: 374,
          height: 79,
          child: ObEntrance(
            // Native glass shows only once the overlay's 400ms fade is done.
            delay: Duration(milliseconds: obNativeGlass ? 450 : 400),
            fade: !obNativeGlass,
            child: ObDarkButton(
              label: l10n.obStartTraining,
              onTap: onStart,
            ),
          ),
        ),
      ],
    );
  }
}

/// Whether the dev/beta bypass shows on the onboarding paywall.
bool get paywallSkipAvailable => kDebugMode || kBetaFreeAccess;
