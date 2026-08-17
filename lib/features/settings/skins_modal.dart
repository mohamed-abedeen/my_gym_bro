import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/settings/skin_repository.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

/// Opens the skins picker as a draggable bottom sheet.
void showSkinsModal(BuildContext context, WidgetRef ref) {
  final colors = AppColors.of(context);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.cardElevated,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => _SkinsGrid(
        scrollController: scrollController,
        colors: colors,
      ),
    ),
  );
}

class _SkinsGrid extends ConsumerStatefulWidget {
  const _SkinsGrid({
    required this.scrollController,
    required this.colors,
  });

  final ScrollController scrollController;
  final AppColorsTheme colors;

  @override
  ConsumerState<_SkinsGrid> createState() => _SkinsGridState();
}

class _SkinsGridState extends ConsumerState<_SkinsGrid> {
  /// A purchase/restore round-trip is in flight — block further store taps.
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Unlock every skin the receipt proves + refresh state after a store flow.
  Future<void> _applyReceipt(SkinFlowOutcome outcome) async {
    for (final id in skinIdsForProducts(outcome.ownedProductIds)) {
      await ref.read(ownedSkinsProvider.notifier).unlock(id);
    }
  }

  Future<void> _buy(Skin skin) async {
    final l10n = AppLocalizations.of(context);
    final productId = skin.productId;
    if (productId == null || _busy) return;
    setState(() => _busy = true);
    try {
      final outcome =
          await ref.read(skinRepositoryProvider).purchase(productId);
      if (!mounted) return;
      switch (outcome.status) {
        case SkinFlowStatus.success:
          await _applyReceipt(outcome);
          // Auto-equip what was just bought.
          await selectSkin(ref, skin.id);
          _snack(l10n.skinPurchaseSuccess);
        case SkinFlowStatus.cancelled:
          break;
        case SkinFlowStatus.unavailable:
          _snack(l10n.skinPremiumSoon);
        case SkinFlowStatus.error:
          _snack(l10n.skinPurchaseFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await ref.read(skinRepositoryProvider).restore();
      if (!mounted) return;
      switch (outcome.status) {
        case SkinFlowStatus.success:
          await _applyReceipt(outcome);
          _snack(
            skinIdsForProducts(outcome.ownedProductIds).isEmpty
                ? l10n.skinRestoreNone
                : l10n.restoreSuccess,
          );
        case SkinFlowStatus.cancelled:
          break;
        case SkinFlowStatus.unavailable:
          _snack(l10n.skinPremiumSoon);
        case SkinFlowStatus.error:
          _snack(l10n.restoreFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final l10n = AppLocalizations.of(context);
    // Opening the gallery pulls fresh server grants (new earned skins,
    // purchases from another device) into the offline mirror.
    ref.watch(skinOwnershipRefreshProvider);
    final isFemale =
        ref.watch(anatomyGenderProvider) == AnatomyGender.female;
    final selectedId = ref.watch(selectedSkinProvider);
    final unlockedIds = ref.watch(unlockedSkinIdsProvider);

    // Only show skins that have an asset for the current anatomy gender.
    final visibleSkins = availableSkins
        .where((s) => s.availableForGender(isFemale: isFemale))
        .toList();

    final genderLabel = isFemale ? l10n.female : l10n.male;

    return SafeArea(
      child: Column(
        children: [
          // ── Handle bar ──
          Padding(
            padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: colors.subtitleText.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // ── Title ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Row(
              children: [
                Icon(Icons.palette_outlined,
                    color: colors.textPrimary, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  l10n.skins,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Restore purchases (store requirement for one-time IAP).
                GestureDetector(
                  onTap: _busy ? null : _restore,
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    child: _busy
                        ? SizedBox(
                            width: 14.sp,
                            height: 14.sp,
                            child: CircularProgressIndicator(
                              color: colors.textSecondary,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            l10n.restoreSubscription,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    genderLabel,
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Grid ──
          Expanded(
            child: GridView.builder(
              controller: widget.scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14.h,
                crossAxisSpacing: 14.w,
                childAspectRatio: 0.72,
              ),
              itemCount: visibleSkins.length,
              itemBuilder: (_, index) {
                final skin = visibleSkins[index];
                final isSelected = skin.id == selectedId;
                final isLocked = !unlockedIds.contains(skin.id);
                final assetPath = skin.pathForGender(isFemale: isFemale)!;
                return _SkinCard(
                  skin: skin,
                  assetPath: assetPath,
                  genderLabel: genderLabel,
                  isSelected: isSelected,
                  isLocked: isLocked,
                  colors: colors,
                  onTap: () {
                    if (isLocked) {
                      if (skin.unlock == SkinUnlock.paid) {
                        // Locked paid skin → straight into the store flow;
                        // the system payment sheet is the confirmation.
                        _buy(skin);
                      } else {
                        // Locked progress skin: explain how to unlock.
                        _snack(
                          l10n.skinLockedProgress(skin.requiredSessions ?? 0),
                        );
                      }
                      return;
                    }
                    selectSkin(ref, skin.id);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.assetPath,
    required this.genderLabel,
    required this.isSelected,
    required this.isLocked,
    required this.colors,
    required this.onTap,
  });

  final Skin skin;
  final String assetPath;
  final String genderLabel;
  final bool isSelected;
  final bool isLocked;
  final AppColorsTheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? colors.accent
                : colors.textSecondary.withValues(alpha: 0.15),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // ── Skin preview image (dimmed + lock chip when locked) ──
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 6.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.r),
                        child: Opacity(
                          opacity: isLocked ? 0.35 : 1,
                          child: Image.asset(
                            assetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 52.sp,
                                color: colors.subtitleText
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isLocked)
                    Positioned(
                      top: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: colors.background.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color:
                                colors.textSecondary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 11.sp,
                              color: colors.textSecondary,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              skin.unlock == SkinUnlock.paid
                                  ? l10n.skinPremium
                                  : l10n.skinWorkoutsShort(
                                      skin.requiredSessions ?? 0),
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Label + selected indicator ──
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${skin.name} · $genderLabel',
                      style: TextStyle(
                        color: isSelected ? colors.accent : colors.textPrimary,
                        fontSize: 11.sp,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded,
                        color: colors.accent, size: 16.sp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
