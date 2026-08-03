import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:my_gym_bro/core/services/subscription_sync_service.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paywall Screen
//
// Layout follows the Figma spec: a swipeable anatomy showcase (male body with
// one muscle group lit in the brand accent per page) fills the top, stacked
// plan pills + the accent "Free Trial" CTA anchor the bottom. Apple-required
// disclosures (auto-renew, restore, Terms/Privacy) stay in a compact footer.
// ─────────────────────────────────────────────────────────────────────────────

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Plan _selected = _Plan.yearly;
  bool _loading = false;
  String? _error;

  // Store-localized prices from RevenueCat offerings (Apple 3.1.2). Null
  // until fetched — the plan cards fall back to static placeholder strings.
  String? _monthlyPrice;
  String? _yearlyPrice;
  String? _yearlyPerMonth;

  // Anatomy showcase — each page lights one muscle group in the accent.
  final _heroController = PageController();
  int _heroPage = 0;
  static const _heroMuscles = <String>[
    'Chest',
    'Lats',
    'Shoulders',
    'Biceps',
    'Core',
    'Quads',
    'Calves',
  ];

  // RevenueCat product identifiers — update to match your dashboard
  static const _monthlyId = 'mgb_premium_monthly';
  static const _yearlyId = 'mgb_premium_annual';

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrices());
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  /// Fetch store prices for the plan cards. RevenueCat is not configured in
  /// dev (placeholder keys skip `Purchases.configure`), so any failure just
  /// keeps the static fallback prices — the screen must always render.
  Future<void> _loadPrices() async {
    try {
      if (!await Purchases.isConfigured) return;
      final current = (await Purchases.getOfferings()).current;
      if (current == null || !mounted) return;
      final monthly = _productFor(current, _monthlyId, current.monthly);
      final annual = _productFor(current, _yearlyId, current.annual);
      setState(() {
        _monthlyPrice = monthly?.priceString;
        _yearlyPrice = annual?.priceString;
        _yearlyPerMonth = annual == null ? null : _perMonth(annual);
      });
    } on Exception {
      // Offerings unavailable — keep fallbacks.
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

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    // When the gate is active (trial elapsed / expired) the paywall is the
    // only way forward — it must not be dismissible by back gesture or a
    // back button. When opened voluntarily (e.g. from Settings) it is.
    final locked = ref.watch(subscriptionLockedProvider);

    final screenH = MediaQuery.of(context).size.height;
    final heroH = (screenH * 0.42).clamp(240.0, 440.0);

    return PopScope(
      canPop: !locked,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Back button — hidden while the gate is active
                SizedBox(
                  height: 44.h,
                  child: locked
                      ? null
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 8.w),
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: colors.textPrimary,
                                size: 22.sp,
                              ),
                              onPressed: () => context.pop(),
                            ),
                          ),
                        ),
                ),

                // ── Anatomy showcase carousel
                SizedBox(
                  height: heroH,
                  child: PageView.builder(
                    controller: _heroController,
                    onPageChanged: (i) => setState(() => _heroPage = i),
                    itemCount: _heroMuscles.length,
                    itemBuilder: (_, i) => Center(
                      child: AnatomyBody(
                        gender: AnatomyGender.male,
                        height: heroH,
                        highlightColor: colors.accent,
                        muscleStates: [
                          MuscleStateInfo(
                            muscleGroup: _heroMuscles[i],
                            state: MuscleState.recovering,
                            recoveryPercent: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Page dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _heroMuscles.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.symmetric(horizontal: 3.w),
                        width: (i == _heroPage ? 8 : 6).w,
                        height: (i == _heroPage ? 8 : 6).w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _heroPage
                              ? colors.accent
                              : colors.textSecondary.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 24.h),

                // ── Plan pills + CTA + disclosures
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    children: [
                      _PlanPill(
                        label: l10n.monthlyPlan,
                        sublabel: l10n
                            .pricePerMonth(_monthlyPrice ?? r'$7.99'),
                        selected: _selected == _Plan.monthly,
                        onTap: () =>
                            setState(() => _selected = _Plan.monthly),
                      ),
                      SizedBox(height: 12.h),
                      _PlanPill(
                        label: l10n.yearlyPlan,
                        sublabel: l10n
                            .pricePerMonth(_yearlyPerMonth ?? r'$4.20'),
                        selected: _selected == _Plan.yearly,
                        onTap: () =>
                            setState(() => _selected = _Plan.yearly),
                      ),

                      SizedBox(height: 8.h),

                      // ── Yearly billed-amount caption
                      Text(
                        l10n.pricePerYear(_yearlyPrice ?? r'$49.99'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: colors.textSecondary,
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // ── Error message
                      if (_error != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Text(
                            _error!,
                            style: TextStyle(
                                color: colors.danger, fontSize: 13.sp),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // ── CTA button
                      SizedBox(
                        width: double.infinity,
                        height: 64.h,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _purchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: colors.black,
                            disabledBackgroundColor:
                                colors.accent.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.button),
                            ),
                            textStyle: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _loading
                              ? SizedBox(
                                  width: 24.w,
                                  height: 24.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colors.black,
                                  ),
                                )
                              : Text(locked
                                  ? l10n.subscribeToContinue
                                  : l10n.freeTrial),
                        ),
                      ),

                      SizedBox(height: 14.h),

                      // ── Yearly-savings blurb
                      Text(
                        l10n.saveWithYearly,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // ── Cancel-anytime disclaimer — trial copy only
                      if (!locked) ...[
                        Text(
                          l10n.cancelAnytime,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                      ],

                      // ── Auto-renewal disclosure (Apple 3.1.2)
                      Text(
                        l10n.autoRenewDisclosure,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: colors.textSecondary,
                        ),
                      ),

                      // ── Terms / Privacy / Restore
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _footerLink(
                              l10n.termsOfUse, 'https://mygymbro.app/terms'),
                          _footerDot(colors),
                          _footerLink(l10n.privacyPolicy,
                              'https://mygymbro.app/privacy'),
                          _footerDot(colors),
                          TextButton(
                            onPressed: _loading ? null : _restore,
                            child: Text(
                              l10n.restoreSubscription,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: colors.textSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Leave the paywall after a successful purchase/restore. If it was pushed
  /// on top of a stack (voluntary open) pop back; if it was reached via the
  /// gate redirect (nothing beneath it) go to home instead.
  void _dismiss() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

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
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        setState(() => _error = l10n.noOfferingsAvailable);
        return;
      }

      final productId =
          _selected == _Plan.yearly ? _yearlyId : _monthlyId;
      final package = current.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier == productId,
        orElse: () => _selected == _Plan.yearly
            ? (current.annual ?? current.availablePackages.first)
            : (current.monthly ?? current.availablePackages.first),
      );

      await Purchases.purchasePackage(package);
      // Reconcile entitlement → local profile so the paywall gate
      // (`subscriptionLockedProvider`) releases.
      await SubscriptionSyncService.syncNow(ref.read(userProfileDaoProvider));
      if (mounted) _dismiss();
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
      await Purchases.restorePurchases();
      await SubscriptionSyncService.syncNow(ref.read(userProfileDaoProvider));
      if (mounted) _dismiss();
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

  Widget _footerDot(AppColorsTheme colors) => Text(
        '·',
        style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
      );

  Widget _footerLink(String label, String url) {
    final colors = AppColors.of(context);
    return TextButton(
      onPressed: () => _openLink(url),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.sp,
          color: colors.textSecondary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  /// Same URLs + launch mechanism as the settings screen.
  Future<void> _openLink(String url) async {
    final l10n = AppLocalizations.of(context);
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.couldNotOpenLink)));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan pill widget
// ─────────────────────────────────────────────────────────────────────────────

enum _Plan { monthly, yearly }

class _PlanPill extends StatelessWidget {
  const _PlanPill({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.10)
              : colors.card,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
            color: selected ? colors.accent : colors.separator,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                color: selected ? colors.accent : colors.textPrimary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
