import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
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

class _SkinsGrid extends ConsumerWidget {
  const _SkinsGrid({
    required this.scrollController,
    required this.colors,
  });

  final ScrollController scrollController;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isFemale =
        ref.watch(anatomyGenderProvider) == AnatomyGender.female;
    final selectedId = ref.watch(selectedSkinProvider);

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
              controller: scrollController,
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
                final assetPath = skin.pathForGender(isFemale: isFemale)!;
                return _SkinCard(
                  skin: skin,
                  assetPath: assetPath,
                  genderLabel: genderLabel,
                  isSelected: isSelected,
                  colors: colors,
                  onTap: () {
                    ref.read(selectedSkinProvider.notifier).select(skin.id);
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
    required this.colors,
    required this.onTap,
  });

  final Skin skin;
  final String assetPath;
  final String genderLabel;
  final bool isSelected;
  final AppColorsTheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            // ── Skin preview image ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 6.h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 52.sp,
                        color: colors.subtitleText.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
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
