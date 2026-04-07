import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/exercise_dao.dart';
import '../../core/providers/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/liquid_glass_button.dart';
import 'exercise_detail_screen.dart';

// ── Providers ──

final _exerciseDaoProvider = Provider<ExerciseDao>((ref) {
  return ExerciseDao(ref.watch(databaseProvider));
});

final _allExercisesProvider = FutureProvider<List<Exercise>>((ref) {
  return ref.watch(_exerciseDaoProvider).getAll();
});

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _muscleFilterProvider = StateProvider<String?>((ref) => null);
final _equipmentFilterProvider = StateProvider<String?>((ref) => null);
final _difficultyFilterProvider = StateProvider<String?>((ref) => null);

/// Combined AND filter: muscle + equipment + difficulty + search text.
final _filteredExercisesProvider = FutureProvider<List<Exercise>>((ref) {
  final query = ref.watch(_searchQueryProvider);
  final muscleFilter = ref.watch(_muscleFilterProvider);
  final equipmentFilter = ref.watch(_equipmentFilterProvider);
  final difficultyFilter = ref.watch(_difficultyFilterProvider);
  final allAsync = ref.watch(_allExercisesProvider);

  return allAsync.when(
    data: (all) {
      var list = all;

      // 1. Muscle group filter
      if (muscleFilter != null) {
        list = list.where((e) => e.muscleGroup == muscleFilter).toList();
      }

      // 2. Equipment filter (stored as JSON array, e.g. '["barbell","body weight"]')
      if (equipmentFilter != null) {
        final eqLower = equipmentFilter.toLowerCase();
        list = list.where((e) {
          if (e.equipments == null) return false;
          try {
            final equips = (jsonDecode(e.equipments!) as List).cast<String>();
            return equips.any((eq) => eq.toLowerCase() == eqLower);
          } catch (_) {
            return false;
          }
        }).toList();
      }

      // 3. Difficulty filter
      if (difficultyFilter != null) {
        list = list.where((e) => e.difficulty == difficultyFilter).toList();
      }

      // 4. Search text
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        list = list.where((e) => e.name.toLowerCase().contains(q)).toList();
      }

      return list;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Unique muscle groups extracted from all exercises.
final _muscleGroupsProvider = FutureProvider<List<String>>((ref) async {
  final all = await ref.watch(_allExercisesProvider.future);
  final groups = <String>{};
  for (final e in all) {
    if (e.muscleGroup != null && e.muscleGroup!.isNotEmpty) {
      groups.add(e.muscleGroup!);
    }
  }
  final sorted = groups.toList()..sort();
  return sorted;
});

/// Unique equipment values extracted from all exercises.
final _equipmentTypesProvider = FutureProvider<List<String>>((ref) async {
  final all = await ref.watch(_allExercisesProvider.future);
  final equips = <String>{};
  for (final e in all) {
    if (e.equipments != null) {
      try {
        final list = (jsonDecode(e.equipments!) as List).cast<String>();
        for (final eq in list) {
          if (eq.isNotEmpty) equips.add(eq);
        }
      } catch (_) {}
    }
  }
  final sorted = equips.toList()..sort();
  return sorted;
});

/// Unique difficulty levels extracted from all exercises.
final _difficultyLevelsProvider = FutureProvider<List<String>>((ref) async {
  final all = await ref.watch(_allExercisesProvider.future);
  final levels = <String>{};
  for (final e in all) {
    if (e.difficulty != null && e.difficulty!.isNotEmpty) {
      levels.add(e.difficulty!);
    }
  }
  // Fixed order: beginner → intermediate → advanced
  const order = ['beginner', 'intermediate', 'advanced'];
  return order.where(levels.contains).toList();
});

// ═══════════════════════════════════════════════════════════════════
// Exercise Browser — supports single-pick and multi-pick modes
// Header: X + checkmark (glass circles)
// List: circular GIF + name + muscle group + "+" button
// Bottom: 3 filter buttons + search bar with filter icon
// ═══════════════════════════════════════════════════════════════════

class ExerciseBrowserScreen extends ConsumerStatefulWidget {
  /// Legacy single-select mode (kept for backward compat).
  final bool pickMode;
  final void Function(Exercise)? onSelect;

  /// Multi-select mode: user can tap multiple exercises, then confirm.
  final bool multiPickMode;
  final void Function(List<Exercise>)? onMultiSelect;

  const ExerciseBrowserScreen({
    super.key,
    this.pickMode = false,
    this.onSelect,
    this.multiPickMode = false,
    this.onMultiSelect,
  });

  @override
  ConsumerState<ExerciseBrowserScreen> createState() =>
      _ExerciseBrowserScreenState();
}

class _ExerciseBrowserScreenState
    extends ConsumerState<ExerciseBrowserScreen> {
  /// Set of selected exercise IDs for multi-pick.
  final Set<String> _selectedIds = {};

  /// Ordered list to preserve selection order.
  final List<Exercise> _selectedExercises = [];

  bool get _isMultiPick => widget.multiPickMode;

  void _toggleSelection(Exercise exercise) {
    setState(() {
      if (_selectedIds.contains(exercise.exerciseId)) {
        _selectedIds.remove(exercise.exerciseId);
        _selectedExercises
            .removeWhere((e) => e.exerciseId == exercise.exerciseId);
      } else {
        _selectedIds.add(exercise.exerciseId);
        _selectedExercises.add(exercise);
      }
    });
  }

  void _confirmMultiSelect() {
    if (widget.onMultiSelect != null) {
      widget.onMultiSelect!(_selectedExercises);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final exercises = ref.watch(_filteredExercisesProvider);

    return Scaffold(
      backgroundColor: colors.panelBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: X + checkmark ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.contentPaddingH.w, 10.h, AppSizes.contentPaddingH.w, 0,
              ),
              child: Row(
                children: [
                  // Close
                  LiquidGlassButton(
                    width: 40.w,
                    height: 40.w,
                    opacity: 0.15,
                    radius: 20.r,
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded,
                        color: colors.textPrimary, size: 20.sp),
                  ),
                  const Spacer(),
                  // Selected count badge (multi-pick only)
                  if (_isMultiPick && _selectedIds.isNotEmpty)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '${_selectedIds.length} selected',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_isMultiPick && _selectedIds.isNotEmpty)
                    SizedBox(width: 10.w),
                  // Check (accent) — in multi-pick confirms all
                  _isMultiPick
                      ? Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: _selectedIds.isNotEmpty
                                ? colors.accent
                                : Colors.white.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20.r),
                              onTap: _selectedIds.isNotEmpty
                                  ? _confirmMultiSelect
                                  : null,
                              child: Center(
                                child: Icon(
                                  Icons.check_rounded,
                                  color: _selectedIds.isNotEmpty
                                      ? colors.panelBackground
                                      : colors.textSecondary,
                                  size: 22.sp,
                                ),
                              ),
                            ),
                          ),
                        )
                      : LiquidGlassButton(
                          width: 40.w,
                          height: 40.w,
                          opacity: 0.25,
                          radius: 20.r,
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(Icons.check_rounded,
                              color: colors.accent, size: 22.sp),
                        ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // ── Exercise list ──
            Expanded(
              child: exercises.when(
                data: (list) => list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.w),
                          child: Text(
                            l10n.noExercisesFound,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.contentPaddingH.w,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final exercise = list[i];
                          final isSelected =
                              _selectedIds.contains(exercise.exerciseId);

                          return _ExerciseTile(
                            exercise: exercise,
                            pickMode: widget.pickMode || _isMultiPick,
                            isSelected: isSelected,
                            showCheckmark: _isMultiPick,
                            onTap: () {
                              if (_isMultiPick) {
                                _toggleSelection(exercise);
                              } else if (widget.pickMode &&
                                  widget.onSelect != null) {
                                widget.onSelect!(exercise);
                              } else {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (_) => ExerciseDetailScreen(
                                      exercise: exercise,
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: colors.accent,
                    strokeWidth: 2,
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── 3 Filter buttons row (Muscle | Equipment | Difficulty) ──
            _FilterButtonsRow(l10n: l10n),
            SizedBox(height: 10.h),

            // ── Search bar at bottom ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.contentPaddingH.w,
                0,
                AppSizes.contentPaddingH.w,
                8.h,
              ),
              child: Row(
                children: [
                  // Search field
                  Expanded(
                    child: Container(
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(296.r),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: 'What are you looking for ?',
                                hintStyle: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) => ref
                                  .read(_searchQueryProvider.notifier)
                                  .state = v,
                            ),
                          ),
                          Icon(Icons.search_rounded,
                              color: colors.textPrimary, size: 22.sp),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Filter reset button
                  _FilterResetButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3 Filter Buttons — Muscle | Equipment | Difficulty
// Figma: 115x37 each, bg white 5% opacity, rounded 296, 14sp w590
// ═══════════════════════════════════════════════════════════════════

class _FilterButtonsRow extends ConsumerWidget {
  final AppLocalizations l10n;
  const _FilterButtonsRow({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muscleFilter = ref.watch(_muscleFilterProvider);
    final equipFilter = ref.watch(_equipmentFilterProvider);
    final diffFilter = ref.watch(_difficultyFilterProvider);

    final muscleGroups = ref.watch(_muscleGroupsProvider);
    final equipTypes = ref.watch(_equipmentTypesProvider);
    final diffLevels = ref.watch(_difficultyLevelsProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
      child: Row(
        children: [
          // Muscle filter
          Expanded(
            child: _FilterChipButton(
              label: muscleFilter ?? l10n.filterMuscle,
              isActive: muscleFilter != null,
              onTap: () {
                final groups = muscleGroups.valueOrNull ?? [];
                _showFilterMenu(
                  context: context,
                  items: groups,
                  currentValue: muscleFilter,
                  allLabel: l10n.allMuscles,
                  onSelected: (v) =>
                      ref.read(_muscleFilterProvider.notifier).state = v,
                );
              },
            ),
          ),
          SizedBox(width: 8.w),
          // Equipment filter
          Expanded(
            child: _FilterChipButton(
              label: equipFilter != null
                  ? _titleCase(equipFilter)
                  : l10n.filterEquipment,
              isActive: equipFilter != null,
              onTap: () {
                final equips = equipTypes.valueOrNull ?? [];
                _showFilterMenu(
                  context: context,
                  items: equips,
                  currentValue: equipFilter,
                  allLabel: l10n.allEquipment,
                  displayTransform: _titleCase,
                  onSelected: (v) =>
                      ref.read(_equipmentFilterProvider.notifier).state = v,
                );
              },
            ),
          ),
          SizedBox(width: 8.w),
          // Difficulty filter
          Expanded(
            child: _FilterChipButton(
              label: diffFilter != null
                  ? _difficultyLabel(diffFilter, l10n)
                  : l10n.filterDifficulty,
              isActive: diffFilter != null,
              onTap: () {
                final levels = diffLevels.valueOrNull ?? [];
                _showFilterMenu(
                  context: context,
                  items: levels,
                  currentValue: diffFilter,
                  allLabel: l10n.allDifficulties,
                  displayTransform: (v) => _difficultyLabel(v, l10n),
                  onSelected: (v) =>
                      ref.read(_difficultyFilterProvider.notifier).state = v,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) =>
          w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
      .join(' ');

  static String _difficultyLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'beginner':
        return l10n.beginner;
      case 'intermediate':
        return l10n.intermediate;
      case 'advanced':
        return l10n.advanced;
      default:
        return _titleCase(value);
    }
  }

  void _showFilterMenu({
    required BuildContext context,
    required List<String> items,
    required String? currentValue,
    required String allLabel,
    required ValueChanged<String?> onSelected,
    String Function(String)? displayTransform,
  }) {
    final colors = AppColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              // "All" option
              _FilterMenuItem(
                label: allLabel,
                isSelected: currentValue == null,
                onTap: () {
                  onSelected(null);
                  Navigator.pop(ctx);
                },
              ),
              Divider(
                height: 1,
                color: colors.textSecondary.withValues(alpha: 0.15),
              ),
              // Items list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.only(bottom: 16.h),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 20.w,
                    endIndent: 20.w,
                    color: colors.textSecondary.withValues(alpha: 0.1),
                  ),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final display =
                        displayTransform?.call(item) ?? item;
                    return _FilterMenuItem(
                      label: display,
                      isSelected: currentValue == item,
                      onTap: () {
                        onSelected(item);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Individual filter chip button (Figma: 115x37, white 5%, rounded pill) ──

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 37.h,
        decoration: BoxDecoration(
          color: isActive
              ? colors.accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(296.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? colors.accent : colors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.29,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            SizedBox(width: 3.w),
            Icon(
              Icons.unfold_more_rounded,
              color: isActive ? colors.accent : colors.textPrimary,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter menu item inside the bottom sheet ──

class _FilterMenuItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterMenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? colors.accent : colors.textPrimary,
                  fontSize: 15.sp,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                color: colors.accent,
                size: 20.sp,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Filter reset button (pill circle, right of search bar) ──

class _FilterResetButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final hasActiveFilter = ref.watch(_muscleFilterProvider) != null ||
        ref.watch(_equipmentFilterProvider) != null ||
        ref.watch(_difficultyFilterProvider) != null;

    return GestureDetector(
      onTap: () {
        ref.read(_muscleFilterProvider.notifier).state = null;
        ref.read(_equipmentFilterProvider.notifier).state = null;
        ref.read(_difficultyFilterProvider.notifier).state = null;
      },
      child: Container(
        width: 48.w,
        height: 48.h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          shape: BoxShape.circle,
        ),
        child: Icon(
          hasActiveFilter ? Icons.filter_alt_off_rounded : Icons.tune_rounded,
          color: hasActiveFilter ? colors.accent : colors.textPrimary,
          size: 20.sp,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Exercise Tile — circular GIF + name + group + "+" / checkmark
// ═══════════════════════════════════════════════════════════════════

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final bool pickMode;
  final bool isSelected;
  final bool showCheckmark;
  final VoidCallback onTap;

  const _ExerciseTile({
    required this.exercise,
    required this.onTap,
    this.pickMode = false,
    this.isSelected = false,
    this.showCheckmark = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        decoration: isSelected
            ? BoxDecoration(
                color: colors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12.r),
              )
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              // Circular GIF thumbnail with selection overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: exercise.gifUrl != null
                        ? CachedNetworkImage(
                            imageUrl: exercise.gifUrl!,
                            width: 58.w,
                            height: 58.w,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _thumbPlaceholder(context),
                            errorWidget: (_, __, ___) => _thumbPlaceholder(context),
                          )
                        : _thumbPlaceholder(context),
                  ),
                  // Green checkmark overlay when selected
                  if (showCheckmark && isSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                          size: 14.sp,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 14.w),
              // Name + muscle group
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (exercise.muscleGroup != null)
                      Text(
                        exercise.muscleGroup!,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              // + icon or checkmark indicator
              if (showCheckmark)
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.accent
                        : Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.add_rounded,
                    color: isSelected ? Colors.black : colors.textPrimary,
                    size: 20.sp,
                  ),
                )
              else
                Icon(Icons.add_rounded,
                    color: colors.textPrimary, size: 24.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
        width: 58.w,
        height: 58.w,
        decoration: BoxDecoration(
          color: colors.separator,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(
          Icons.fitness_center_rounded,
          color: colors.textSecondary,
          size: 22.sp,
        ),
      );
  }
}
