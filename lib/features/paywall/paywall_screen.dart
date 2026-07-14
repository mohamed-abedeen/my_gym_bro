import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:my_gym_bro/core/services/subscription_sync_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paywall Screen
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

  // RevenueCat product identifiers — update to match your dashboard
  static const _monthlyId = 'mgb_monthly';
  static const _yearlyId = 'mgb_yearly';

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    // When the gate is active (trial elapsed / expired) the paywall is the
    // only way forward — it must not be dismissible by back gesture or a
    // close button. When opened voluntarily (e.g. from Settings) it is.
    final locked = ref.watch(subscriptionLockedProvider);

    final features = [
      (Icons.fitness_center_rounded, l10n.trialFeature1),
      (Icons.library_books_rounded, l10n.trialFeature2),
      (Icons.calendar_month_rounded, l10n.trialFeature3),
      (Icons.insights_rounded, l10n.trialFeature4),
    ];

    return PopScope(
      canPop: !locked,
      child: Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Close button — hidden while the gate is active
            if (!locked)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8.h, right: 16.w),
                  child: IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: colors.textSecondary, size: 24.sp),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    SizedBox(height: 8.h),

                    // ── Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: Text(
                        l10n.trialBadge,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.black,
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // ── Headline
                    Text(
                      l10n.startTrial,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        height: 1.2,
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // ── Feature list
                    ...features.map((f) => Padding(
                          padding: EdgeInsets.only(bottom: 16.h),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  color: colors.card,
                                  borderRadius:
                                      BorderRadius.circular(12.r),
                                ),
                                child: Icon(f.$1,
                                    color: colors.accent, size: 22.sp),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  f.$2,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(Icons.check_circle_rounded,
                                  color: colors.success, size: 20.sp),
                            ],
                          ),
                        )),

                    SizedBox(height: 28.h),

                    // ── Plan selector
                    Row(
                      children: [
                        _PlanCard(
                          label: l10n.monthlyPlan,
                          sublabel: r'$9.99 / mo',
                          selected: _selected == _Plan.monthly,
                          onTap: () =>
                              setState(() => _selected = _Plan.monthly),
                        ),
                        SizedBox(width: 12.w),
                        _PlanCard(
                          label: l10n.yearlyPlan,
                          sublabel: r'$49.99 / yr',
                          badge: l10n.bestValue,
                          selected: _selected == _Plan.yearly,
                          onTap: () =>
                              setState(() => _selected = _Plan.yearly),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    // ── Error message
                    if (_error != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: colors.danger, fontSize: 13.sp),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    SizedBox(height: 8.h),

                    // ── CTA button
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
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
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: _loading
                            ? SizedBox(
                                width: 22.w,
                                height: 22.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colors.black,
                                ),
                              )
                            : Text(l10n.startTrial),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // ── Cancel anytime disclaimer
                    Text(
                      l10n.cancelAnytime,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: colors.textSecondary,
                      ),
                    ),

                    SizedBox(height: 12.h),

                    // ── Restore purchases
                    TextButton(
                      onPressed: _loading ? null : _restore,
                      child: Text(
                        l10n.restoreSubscription,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: colors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          ],
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        setState(() => _error = 'No offerings available. Try again later.');
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
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        setState(() => _error = null);
      } else {
        setState(() => _error = 'Purchase failed. Please try again.');
        CrashReporter.recordError(e, reason: 'Paywall purchase failed');
      }
    } on Exception catch (e) {
      setState(() => _error = 'Purchase failed. Please try again.');
      CrashReporter.recordError(e, reason: 'Paywall purchase exception');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Purchases.restorePurchases();
      await SubscriptionSyncService.syncNow(ref.read(userProfileDaoProvider));
      if (mounted) _dismiss();
    } on Exception catch (e) {
      setState(() => _error = 'Could not restore purchases. Please try again.');
      CrashReporter.recordError(e, reason: 'Paywall restore failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan card widget
// ─────────────────────────────────────────────────────────────────────────────

enum _Plan { monthly, yearly }

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String sublabel;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: selected ? colors.accent.withValues(alpha: 0.12) : colors.card,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? colors.accent : colors.separator,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge != null)
                Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.symmetric(
                      horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.black,
                    ),
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.accent : colors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
