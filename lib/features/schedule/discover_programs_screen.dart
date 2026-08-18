import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/schedule/premade_program_card.dart';
import 'package:my_gym_bro/features/schedule/premade_programs.dart';
import 'package:my_gym_bro/features/schedule/premade_programs_screen.dart';
import 'package:my_gym_bro/features/schedule/split_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Discover Programs — featured picks from the premade catalog with a link
/// into the full library. Level/category chips filter the whole catalog.
class DiscoverProgramsScreen extends ConsumerStatefulWidget {
  const DiscoverProgramsScreen({super.key});

  @override
  ConsumerState<DiscoverProgramsScreen> createState() =>
      _DiscoverProgramsScreenState();
}

class _DiscoverProgramsScreenState
    extends ConsumerState<DiscoverProgramsScreen> {
  PremadeLevel? _level;
  PremadeCategory? _category;

  bool get _filtersActive => _level != null || _category != null;

  /// One program per level (beginner → advanced), topped up to three.
  static List<PremadeProgram> _featured() {
    final picks = <PremadeProgram>[];
    for (final level in PremadeLevel.values) {
      for (final p in premadePrograms) {
        if (p.level == level) {
          picks.add(p);
          break;
        }
      }
    }
    for (final p in premadePrograms) {
      if (picks.length >= 3) break;
      if (!picks.contains(p)) picks.add(p);
    }
    return picks.take(3).toList();
  }

  /// Featured picks by default; matches from the full catalog once a
  /// filter is set.
  List<PremadeProgram> _visiblePrograms() {
    if (!_filtersActive) return _featured();
    return premadePrograms
        .where(
          (p) =>
              (_level == null || p.level == _level) &&
              (_category == null || p.category == _category),
        )
        .toList();
  }

  Future<void> _pickLevel(BuildContext chipContext) async {
    final l10n = AppLocalizations.of(context);
    final choice = await _showFilterMenu<PremadeLevel>(
      chipContext,
      selected: _level,
      allLabel: l10n.premadeCategoryAll,
      options: [
        for (final level in PremadeLevel.values)
          (level, premadeLevelLabel(l10n, level)),
      ],
    );
    if (choice != null && mounted) setState(() => _level = choice.value);
  }

  Future<void> _pickCategory(BuildContext chipContext) async {
    final l10n = AppLocalizations.of(context);
    final choice = await _showFilterMenu<PremadeCategory>(
      chipContext,
      selected: _category,
      allLabel: l10n.premadeCategoryAll,
      options: [
        for (final c in PremadeCategory.values)
          (c, premadeCategoryLabel(l10n, c)),
      ],
    );
    if (choice != null && mounted) setState(() => _category = choice.value);
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final visible = _visiblePrograms();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: back + centered title ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.contentPaddingH.w,
                  8.h,
                  AppSizes.contentPaddingH.w,
                  0,
                ),
                child: SizedBox(
                  height: 48.w,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SplitHeaderButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Center(
                        child: Text(
                          l10n.discoverTitle,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Text(
                  l10n.discoverProgramsTitle,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 34.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              // ── Filter chips — tune chip clears, the others pick ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.discoverFilter,
                      leading: Icons.tune_rounded,
                      active: _filtersActive,
                      onTap: _filtersActive
                          ? () => setState(() {
                              _level = null;
                              _category = null;
                            })
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Builder(
                      builder: (chipContext) => _FilterChip(
                        label: _level == null
                            ? l10n.discoverLevel
                            : premadeLevelLabel(l10n, _level!),
                        dropdown: true,
                        active: _level != null,
                        onTap: () => _pickLevel(chipContext),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Builder(
                      builder: (chipContext) => _FilterChip(
                        label: _category == null
                            ? l10n.discoverCategory
                            : premadeCategoryLabel(l10n, _category!),
                        dropdown: true,
                        active: _category != null,
                        onTap: () => _pickCategory(chipContext),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              // ── Program cards — featured picks, or filtered results ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Column(
                  children: [
                    if (visible.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 30.h),
                        child: Text(
                          l10n.discoverNoMatches,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    for (final program in visible) ...[
                      PremadeProgramCard(
                        l10n: l10n,
                        program: program,
                        onTap: () => showPremadeProgramSheet(
                          context,
                          program: program,
                          onInstalled: (scheduleId) {
                            selectInstalledSchedule(ref, scheduleId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.premadeAdded)),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 14.h),
                    ],
                  ],
                ),
              ),
              // ── Show all → full premade library ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.premadePrograms),
                  child: Container(
                    height: 56.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.panelBackground,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      l10n.discoverShowAll(premadePrograms.length),
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.leading,
    this.dropdown = false,
    this.active = false,
    this.onTap,
  });
  final String label;
  final IconData? leading;
  final bool dropdown;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fg = active ? colors.accent : colors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius: BorderRadius.circular(17.r),
          border: active ? Border.all(color: colors.accent, width: 1.5) : null,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Icon(leading, size: 18.sp, color: fg),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (dropdown) ...[
              SizedBox(width: 4.w),
              Icon(Icons.expand_more_rounded, size: 18.sp, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wraps a menu selection so "All" (null value) is distinguishable from
/// dismissing the menu (null result).
class _FilterChoice<T> {
  const _FilterChoice(this.value);
  final T? value;
}

/// Dropdown under a filter chip — same dark panel as the app's other
/// context menus, in both themes.
Future<_FilterChoice<T>?> _showFilterMenu<T>(
  BuildContext chipContext, {
  required T? selected,
  required String allLabel,
  required List<(T, String)> options,
}) {
  final box = chipContext.findRenderObject()! as RenderBox;
  final offset = box.localToGlobal(Offset.zero);
  final accent = AppColors.of(chipContext).accent;
  final white = Colors.white.withValues(alpha: 0.92);
  final divider = PopupMenuDivider(
    height: 1,
    color: Colors.white.withValues(alpha: 0.14),
  );

  PopupMenuItem<_FilterChoice<T>> item(T? value, String label) =>
      PopupMenuItem<_FilterChoice<T>>(
        value: _FilterChoice<T>(value),
        height: 40.h,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: value == selected ? accent : white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  final items = <PopupMenuEntry<_FilterChoice<T>>>[item(null, allLabel)];
  for (final (value, label) in options) {
    items
      ..add(divider)
      ..add(item(value, label));
  }

  return showMenu<_FilterChoice<T>>(
    context: chipContext,
    position: RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height + 6.h,
      offset.dx + box.size.width,
      0,
    ),
    color: const Color(0xF2202022),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
    elevation: 12,
    items: items,
  );
}
