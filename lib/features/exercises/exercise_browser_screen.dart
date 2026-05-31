import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';
import 'package:my_gym_bro/features/exercises/exercise_detail_screen.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';
import 'package:my_gym_bro/shared/widgets/shimmer_box.dart';

// ── Providers ──

/// Immutable state for the paginated exercise catalogue.
class _CatalogueState {
  const _CatalogueState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.fromCache = false,
    this.error,
  });

  final List<Exercise> items;
  final bool isLoading; // initial / reset load in flight
  final bool isLoadingMore; // appending a further page
  final bool hasMore;
  final bool fromCache; // last result served from the local cache (offline)
  final Object? error; // only meaningful when [items] is empty

  _CatalogueState copyWith({
    List<Exercise>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? fromCache,
    Object? error,
    bool clearError = false,
  }) {
    return _CatalogueState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      fromCache: fromCache ?? this.fromCache,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives catalogue browse/search against [ExerciseRepository] with
/// pagination. The accumulated list is what the in-memory filters and sections
/// operate on. Offline (or free-plan search) the repository transparently
/// serves the local cache, flagged via [_CatalogueState.fromCache].
class _CatalogueNotifier extends StateNotifier<_CatalogueState> {
  _CatalogueNotifier(this._repo)
      : super(const _CatalogueState(isLoading: true)) {
    _load(reset: true);
  }

  final ExerciseRepository _repo;
  String _query = '';

  /// When the API rate-limits us mid-pagination, back off briefly before
  /// retrying so repeated scrolling can't hammer the quota.
  DateTime? _retryAfter;

  /// Re-run the current query from the first page.
  Future<void> refresh() {
    _retryAfter = null;
    return _load(reset: true);
  }

  /// Append the next page when browsing (no-op while searching or exhausted).
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final retryAfter = _retryAfter;
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) return;
    await _load(reset: false);
  }

  /// Switch to a search query (empty restores full-catalogue browse).
  Future<void> setSearch(String query) async {
    final q = query.trim();
    if (q == _query) return;
    _query = q;
    await _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    final offset = reset ? 0 : state.items.length;
    try {
      final page = _query.isEmpty
          ? await _repo.browse(offset: offset)
          : await _repo.searchByName(_query);

      final prevLen = state.items.length;
      final merged =
          reset ? page.items : _dedupAppend(state.items, page.items);

      // Decide whether more pages remain:
      //  • search isn't paginated → no more;
      //  • a cache fallback means the API was unavailable (rate-limited /
      //    offline / quota) — the cache can't report the true remaining count,
      //    so DON'T conclude we've hit the end; preserve hasMore so a later
      //    scroll retries, and back off briefly to spare the quota;
      //  • online with a grand total → page until we reach it;
      //  • online without a total (bare array) → page until a page adds nothing.
      final bool hasMore;
      if (_query.isNotEmpty) {
        hasMore = false;
      } else if (page.fromCache) {
        hasMore = reset ? merged.length < page.total : state.hasMore;
        if (!reset) _retryAfter = DateTime.now().add(const Duration(seconds: 5));
      } else if (page.items.isEmpty) {
        hasMore = false;
      } else if (page.total < 0) {
        hasMore = reset || merged.length > prevLen;
      } else {
        _retryAfter = null;
        hasMore = merged.length < page.total;
      }

      state = _CatalogueState(
        items: merged,
        hasMore: hasMore,
        fromCache: page.fromCache,
      );
    } on Object catch (e) {
      // The repository falls back to cache internally, so this is rare.
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: state.items.isEmpty ? e : null,
      );
    }
  }

  static List<Exercise> _dedupAppend(
      List<Exercise> existing, List<Exercise> next) {
    final seen = existing.map((e) => e.exerciseId).toSet();
    return [
      ...existing,
      for (final e in next)
        if (seen.add(e.exerciseId)) e,
    ];
  }
}

final _catalogueProvider =
    StateNotifierProvider<_CatalogueNotifier, _CatalogueState>((ref) {
  return _CatalogueNotifier(ref.watch(exerciseRepositoryProvider));
});

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _muscleFilterProvider = StateProvider<String?>((ref) => null);
final _equipmentFilterProvider =
    StateProvider<_EquipmentFilterValue?>((ref) => null);
final _difficultyFilterProvider = StateProvider<String?>((ref) => null);

/// Applies all active filters then splits the result into two sorted sections:
/// up to 25 recents (frequency DESC) and the A-Z remainder. Maps the catalogue
/// notifier's state into an [AsyncValue] so the screen's `.when` rendering
/// (loading skeleton / error+retry / data) keeps working unchanged.
final _filteredExercisesProvider =
    Provider<AsyncValue<_ExerciseSections>>((ref) {
  final cat = ref.watch(_catalogueProvider);
  if (cat.isLoading && cat.items.isEmpty) {
    return const AsyncValue.loading();
  }
  if (cat.error != null && cat.items.isEmpty) {
    return AsyncValue.error(cat.error!, StackTrace.empty);
  }

  final query = ref.watch(_searchQueryProvider);
  final muscleFilter = ref.watch(_muscleFilterProvider);
  final equipmentFilter = ref.watch(_equipmentFilterProvider);
  final difficultyFilter = ref.watch(_difficultyFilterProvider);

  var list = cat.items;

  // 1. Muscle group filter — 'Shoulders' is the umbrella value that
  // matches every deltoid sub-group as well as unclassified shoulder work.
  if (muscleFilter != null) {
    if (muscleFilter == 'Shoulders') {
      const shoulderGroups = {
        'Shoulders', 'Front Delt', 'Side Delt', 'Rear Delt',
      };
      list =
          list.where((e) => shoulderGroups.contains(e.muscleGroup)).toList();
    } else {
      final mf = muscleFilter.trim().toLowerCase();
      list = list
          .where((e) => e.muscleGroup?.trim().toLowerCase() == mf)
          .toList();
    }
  }

  // 2. Equipment filter — OR-matches any exercise whose equipment array
  // contains at least one value from the selected category's raw set.
  if (equipmentFilter != null) {
    final rawSet =
        equipmentFilter.rawValues.map((v) => v.toLowerCase()).toSet();
    list = list.where((e) {
      if (e.equipments == null) return false;
      try {
        final equips = (jsonDecode(e.equipments!) as List).cast<String>();
        return equips.any((eq) => rawSet.contains(eq.toLowerCase()));
      } on FormatException catch (fe) {
        debugPrint(
            'exercise_browser: bad equipments JSON for "${e.name}": $fe');
        return false;
      }
    }).toList();
  }

  // 3. Difficulty filter
  if (difficultyFilter != null) {
    list = list.where((e) => e.difficulty == difficultyFilter).toList();
  }

  // 4. Search text — client-side narrowing over the loaded/cached items
  // (the catalogue notifier already issued the server-side search).
  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    list = list.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  // 5. Split: top-25 recents pinned by frequency DESC, rest sorted A-Z.
  // Exercises that have never been used go directly into the rest section.
  final used = list.where((e) => e.usageCount > 0).toList()
    ..sort((a, b) {
      final byUsage = b.usageCount.compareTo(a.usageCount);
      return byUsage != 0 ? byUsage : a.name.compareTo(b.name);
    });
  final recents = used.take(25).toList();
  final recentIds = recents.map((e) => e.exerciseId).toSet();
  final rest = list.where((e) => !recentIds.contains(e.exerciseId)).toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  return AsyncValue.data(_ExerciseSections(recents: recents, rest: rest));
});

/// Unique difficulty levels extracted from the loaded catalogue.
final _difficultyLevelsProvider = FutureProvider<List<String>>((ref) async {
  final all = ref.watch(_catalogueProvider).items;
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

// ── Muscle Category Data ──

class _MuscleCategory {
  const _MuscleCategory({
    required this.label,
    required this.muscles,
    this.allValue,
  });

  final String label;

  /// Leaf-level filter values shown as sub-items when expanded.
  final List<String> muscles;

  /// When non-null, an "All {label}" row is prepended to the sub-list that
  /// sets the filter to this value. The filter provider treats this value as
  /// an umbrella match (e.g. 'Shoulders' matches all deltoid sub-groups).
  final String? allValue;

  /// True when the category has only one muscle and no "All" option —
  /// tapping the header directly selects it without expanding.
  bool get isSingle => muscles.length == 1 && allValue == null;

  bool get hasAllOption => allValue != null;
}

const _muscleCategories = <_MuscleCategory>[
  _MuscleCategory(label: 'Chest',     muscles: ['Chest']),
  _MuscleCategory(label: 'Back',      muscles: ['Lats', 'Upper Back', 'Lower Back', 'Traps']),
  _MuscleCategory(
    label: 'Shoulders',
    muscles: ['Front Delt', 'Side Delt', 'Rear Delt'],
    allValue: 'Shoulders', // umbrella value — matches all three heads + unclassified
  ),
  _MuscleCategory(label: 'Arms',      muscles: ['Biceps', 'Triceps', 'Forearms']),
  _MuscleCategory(label: 'Legs',      muscles: ['Quads', 'Hamstrings', 'Glutes', 'Calves']),
  _MuscleCategory(label: 'Core',      muscles: ['Core']),
  _MuscleCategory(label: 'Other',     muscles: ['Neck', 'Cardio']),
];

// ── Sectioned exercise list data ──

/// Two-section result produced by [_filteredExercisesProvider].
class _ExerciseSections {
  const _ExerciseSections({required this.recents, required this.rest});

  /// Up to 25 exercises that have been used, sorted by frequency DESC.
  final List<Exercise> recents;

  /// All remaining filtered exercises, sorted A-Z. Never overlaps [recents].
  final List<Exercise> rest;

  bool get isEmpty => recents.isEmpty && rest.isEmpty;
}

// ── Equipment Category Data ──

/// Active equipment filter — may target one raw DB value (specific sub-type)
/// or several (category-level "All X" selection).
class _EquipmentFilterValue {
  const _EquipmentFilterValue({
    required this.displayLabel,
    required this.rawValues,
  });

  /// Label shown on the filter chip.
  final String displayLabel;

  /// Raw equipment values (as stored in the DB) to match against.
  /// Multiple values are OR-ed during filtering.
  final List<String> rawValues;
}

class _EquipmentCategory {
  const _EquipmentCategory({
    required this.label,
    required this.rawValues,
  });

  final String label;

  /// All raw DB equipment strings that belong to this category.
  final List<String> rawValues;

  /// True when the category has more than one raw value and should render as
  /// an expandable accordion showing individual sub-type options.
  bool get hasSubTypes => rawValues.length > 1;
}

const _equipmentCategories = <_EquipmentCategory>[
  _EquipmentCategory(
    label: 'None',
    rawValues: ['body weight'],
  ),
  _EquipmentCategory(
    label: 'Barbell',
    rawValues: ['barbell', 'trap bar', 'ez barbell', 'olympic barbell'],
  ),
  _EquipmentCategory(
    label: 'Dumbbell',
    rawValues: ['dumbbell'],
  ),
  _EquipmentCategory(
    label: 'Kettlebell',
    rawValues: ['kettlebell'],
  ),
  _EquipmentCategory(
    label: 'Machine',
    rawValues: ['leverage machine', 'sled machine', 'smith machine', 'cable', 'hammer'],
  ),
  _EquipmentCategory(
    label: 'Resistance Band',
    rawValues: ['resistance band', 'band'],
  ),
  _EquipmentCategory(
    label: 'Cardio',
    rawValues: ['stepmill machine', 'skierg machine', 'elliptical machine', 'stationary bike'],
  ),
  _EquipmentCategory(
    label: 'Other',
    rawValues: [
      'tire', 'upper body ergometer', 'wheel roller', 'roller',
      'bosu ball', 'assisted', 'stability ball', 'medicine ball',
      'rope', 'weighted',
    ],
  ),
];

// ── Shared title-case helper ──

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
    .join(' ');

// ═══════════════════════════════════════════════════════════════════
// Exercise Browser — supports single-pick and multi-pick modes
// Header: X + checkmark (glass circles)
// List: circular GIF + name + muscle group + "+" button
// Bottom: 3 filter buttons + search bar with filter icon
// ═══════════════════════════════════════════════════════════════════

class ExerciseBrowserScreen extends ConsumerStatefulWidget {

  const ExerciseBrowserScreen({
    super.key,
    this.pickMode = false,
    this.onSelect,
    this.multiPickMode = false,
    this.onMultiSelect,
  });
  /// Legacy single-select mode (kept for backward compat).
  final bool pickMode;
  final void Function(Exercise)? onSelect;

  /// Multi-select mode: user can tap multiple exercises, then confirm.
  final bool multiPickMode;
  final void Function(List<Exercise>)? onMultiSelect;

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

  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Infinite scroll — fetch the next catalogue page as the list nears bottom.
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(_catalogueProvider.notifier).loadMore();
    }
  }

  /// The API returns small pages (the free plan caps at ~10 items), so a single
  /// page often doesn't fill the screen — then there's nothing to scroll and
  /// [_onScroll] never fires. Proactively fetch the next page until the list
  /// overflows the viewport (or the catalogue is exhausted).
  ///
  /// Gated to the plain browse view: with a filter/search active a narrow match
  /// could otherwise page through the entire catalogue and burn API quota.
  void _maybeAutoPaginate() {
    if (!_scrollController.hasClients) return;
    final filtered = ref.read(_searchQueryProvider).isNotEmpty ||
        ref.read(_muscleFilterProvider) != null ||
        ref.read(_equipmentFilterProvider) != null ||
        ref.read(_difficultyFilterProvider) != null;
    if (filtered) return;
    final cat = ref.read(_catalogueProvider);
    if (cat.hasMore &&
        !cat.isLoading &&
        !cat.isLoadingMore &&
        _scrollController.position.maxScrollExtent <= 0) {
      ref.read(_catalogueProvider.notifier).loadMore();
    }
  }

  /// Debounced search — update the instant client-side filter immediately, then
  /// issue the server-side search after a short pause to conserve API quota.
  void _onSearchChanged(String value) {
    ref.read(_searchQueryProvider.notifier).state = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(_catalogueProvider.notifier).setSearch(value);
    });
  }

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
    widget.onMultiSelect?.call(_selectedExercises);
    Navigator.of(context).pop();
  }

  Widget _buildSectionHeader(String title) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 16.h, 4.w, 4.h),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildExerciseTile(Exercise exercise) {
    final isSelected = _selectedIds.contains(exercise.exerciseId);
    return _ExerciseTile(
      exercise: exercise,
      pickMode: widget.pickMode || _isMultiPick,
      isSelected: isSelected,
      showCheckmark: _isMultiPick,
      onTap: () {
        if (_isMultiPick) {
          _toggleSelection(exercise);
        } else if (widget.pickMode) {
          if (widget.onSelect != null) {
            widget.onSelect!(exercise);
          } else {
            Navigator.of(context).pop(exercise.exerciseId);
          }
        } else {
          Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => ExerciseDetailScreen(exercise: exercise),
            ),
          );
        }
      },
    );
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
                        l10n.nSelected(_selectedIds.length),
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
                  if (_isMultiPick) Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: _selectedIds.isNotEmpty
                                ? colors.accent
                                : AppColors.of(context).white.withValues(alpha: 0.10),
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
                        ) else LiquidGlassButton(
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
            SizedBox(height: 12.h),

            // ── Offline banner — shown when results came from the local cache ──
            if (ref.watch(_catalogueProvider).fromCache &&
                ref.watch(_catalogueProvider).items.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.contentPaddingH.w,
                  0,
                  AppSizes.contentPaddingH.w,
                  8.h,
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        color: colors.textSecondary, size: 14.sp),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        l10n.exercisesOfflineCached,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Exercise list ──
            Expanded(
              child: exercises.when(
                data: (sections) {
                  if (sections.isEmpty) {
                    final hasFilters =
                        ref.watch(_muscleFilterProvider) != null ||
                        ref.watch(_equipmentFilterProvider) != null ||
                        ref.watch(_difficultyFilterProvider) != null;
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.noExercisesFound,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14.sp,
                              ),
                            ),
                            if (hasFilters) ...[
                              SizedBox(height: 16.h),
                              GestureDetector(
                                onTap: () {
                                  ref
                                      .read(_muscleFilterProvider.notifier)
                                      .state = null;
                                  ref
                                      .read(_equipmentFilterProvider.notifier)
                                      .state = null;
                                  ref
                                      .read(_difficultyFilterProvider.notifier)
                                      .state = null;
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(
                                      color: colors.accent.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.clearFilters,
                                    style: TextStyle(
                                      color: colors.accent,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  // Flatten into a single list: header strings interleaved
                  // with Exercise objects so one ListView.builder handles both.
                  final items = <Object>[];
                  if (sections.recents.isNotEmpty) {
                    items.add('Recent Exercises');
                    items.addAll(sections.recents);
                  }
                  if (sections.rest.isNotEmpty) {
                    items.add('All Exercises');
                    items.addAll(sections.rest);
                  }

                  // Fill the viewport when a small page doesn't overflow it.
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _maybeAutoPaginate());
                  final loadingMore =
                      ref.watch(_catalogueProvider).isLoadingMore;
                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.contentPaddingH.w,
                    ),
                    itemCount: items.length + (loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= items.length) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Center(
                            child: SizedBox(
                              width: 22.w,
                              height: 22.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.accent,
                              ),
                            ),
                          ),
                        );
                      }
                      final item = items[i];
                      if (item is String) return _buildSectionHeader(item);
                      return _buildExerciseTile(item as Exercise);
                    },
                  );
                },
                loading:
                    () => ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.contentPaddingH.w,
                      ),
                      itemCount: 8,
                      itemBuilder:
                          (_, __) => Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: _ExerciseTileSkeleton(),
                          ),
                    ),
                error:
                    (_, __) => Center(
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(_catalogueProvider.notifier).refresh(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: colors.textSecondary,
                              size: 32.sp,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              AppLocalizations.of(context).failedToLoadExercises,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  color: colors.accent,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  AppLocalizations.of(context).retry,
                                  style: TextStyle(
                                    color: colors.accent,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
                        color: AppColors.of(context).white.withValues(alpha: 0.07),
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
                                hintText: l10n.exerciseSearchHint,
                                hintStyle: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: _onSearchChanged,
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
  const _FilterButtonsRow({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muscleFilter = ref.watch(_muscleFilterProvider);
    final equipFilter = ref.watch(_equipmentFilterProvider);
    final diffFilter = ref.watch(_difficultyFilterProvider);

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
              onTap: () => _showMuscleFilterSheet(
                context: context,
                currentValue: muscleFilter,
                allLabel: l10n.allMuscles,
                onSelected: (v) =>
                    ref.read(_muscleFilterProvider.notifier).state = v,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Equipment filter
          Expanded(
            child: _FilterChipButton(
              label: equipFilter?.displayLabel ?? l10n.filterEquipment,
              isActive: equipFilter != null,
              onTap: () => _showEquipmentFilterSheet(
                context: context,
                currentValue: equipFilter,
                allLabel: l10n.allEquipment,
                onSelected: (v) =>
                    ref.read(_equipmentFilterProvider.notifier).state = v,
              ),
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

  void _showEquipmentFilterSheet({
    required BuildContext context,
    required _EquipmentFilterValue? currentValue,
    required String allLabel,
    required ValueChanged<_EquipmentFilterValue?> onSelected,
  }) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      builder: (ctx) => _EquipmentFilterSheet(
        currentValue: currentValue,
        allLabel: allLabel,
        onSelected: (v) {
          onSelected(v);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showMuscleFilterSheet({
    required BuildContext context,
    required String? currentValue,
    required String allLabel,
    required ValueChanged<String?> onSelected,
  }) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      builder: (ctx) => _MuscleFilterSheet(
        currentValue: currentValue,
        allLabel: allLabel,
        onSelected: (v) {
          onSelected(v);
          Navigator.pop(ctx);
        },
      ),
    );
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

    showModalBottomSheet<void>(
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

  const _FilterChipButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

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
              : AppColors.of(context).white.withValues(alpha: 0.05),
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

  const _FilterMenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

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
          color: AppColors.of(context).white.withValues(alpha: 0.07),
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
// Muscle Filter Accordion Sheet
// ═══════════════════════════════════════════════════════════════════

class _MuscleFilterSheet extends StatefulWidget {
  const _MuscleFilterSheet({
    required this.currentValue,
    required this.allLabel,
    required this.onSelected,
  });

  final String? currentValue;
  final String allLabel;
  final ValueChanged<String?> onSelected;

  @override
  State<_MuscleFilterSheet> createState() => _MuscleFilterSheetState();
}

class _MuscleFilterSheetState extends State<_MuscleFilterSheet>
    with TickerProviderStateMixin {
  final _controllers = <String, AnimationController>{};
  final _animations = <String, CurvedAnimation>{};

  @override
  void initState() {
    super.initState();
    for (final cat in _muscleCategories) {
      if (cat.isSingle) continue;
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      final anim = CurvedAnimation(
        parent: ctrl,
        curve: Curves.easeInOutCubic,
      );
      _controllers[cat.label] = ctrl;
      _animations[cat.label] = anim;
      // Auto-expand the group that contains the current selection,
      // including when the "All X" umbrella value itself is selected.
      if (widget.currentValue != null &&
          (cat.muscles.contains(widget.currentValue) ||
           cat.allValue == widget.currentValue)) {
        ctrl.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _toggle(String label) {
    final ctrl = _controllers[label]!;
    if (ctrl.status == AnimationStatus.dismissed ||
        ctrl.status == AnimationStatus.reverse) {
      ctrl.forward();
    } else {
      ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
            label: widget.allLabel,
            isSelected: widget.currentValue == null,
            onTap: () => widget.onSelected(null),
          ),
          Divider(
            height: 1,
            color: colors.textSecondary.withValues(alpha: 0.15),
          ),
          // Accordion list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(bottom: 16.h),
              itemCount: _muscleCategories.length,
              itemBuilder: (_, i) {
                final cat = _muscleCategories[i];
                final isLast = i == _muscleCategories.length - 1;

                // Single-muscle category: tap header to select directly
                if (cat.isSingle) {
                  final muscle = cat.muscles.first;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FilterMenuItem(
                        label: cat.label,
                        isSelected: widget.currentValue == muscle,
                        onTap: () => widget.onSelected(muscle),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 20.w,
                          endIndent: 20.w,
                          color: colors.textSecondary.withValues(alpha: 0.1),
                        ),
                    ],
                  );
                }

                // Multi-muscle category: accordion
                final anim = _animations[cat.label]!;
                // Group header is highlighted when any child — or the "All X"
                // umbrella value — is the current selection.
                final isGroupSelected = widget.currentValue != null &&
                    (cat.muscles.contains(widget.currentValue) ||
                     cat.allValue == widget.currentValue);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _toggle(cat.label),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 14.h,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                cat.label,
                                style: TextStyle(
                                  color: isGroupSelected
                                      ? colors.accent
                                      : colors.textPrimary,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Dot indicator when a child is selected
                            if (isGroupSelected)
                              Container(
                                width: 7.w,
                                height: 7.w,
                                margin: EdgeInsets.only(right: 8.w),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            RotationTransition(
                              turns: Tween<double>(begin: 0, end: 0.5)
                                  .animate(anim),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: colors.textSecondary,
                                size: 22.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expanding children
                    SizeTransition(
                      sizeFactor: anim,
                      axisAlignment: -1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // "All X" option — only shown for categories that
                          // have an umbrella filter value (e.g. Shoulders).
                          if (cat.hasAllOption)
                            _SubMuscleItem(
                              label: 'All ${cat.label}',
                              isSelected:
                                  widget.currentValue == cat.allValue,
                              onTap: () =>
                                  widget.onSelected(cat.allValue),
                              isAllOption: true,
                            ),
                          ...cat.muscles.map(
                            (muscle) => _SubMuscleItem(
                              label: muscle,
                              isSelected: widget.currentValue == muscle,
                              onTap: () => widget.onSelected(muscle),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 20.w,
                        endIndent: 20.w,
                        color: colors.textSecondary.withValues(alpha: 0.1),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Indented sub-muscle row ──

class _SubMuscleItem extends StatelessWidget {
  const _SubMuscleItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isAllOption = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  /// True for the "All X" umbrella row — rendered slightly bolder and with a
  /// bottom divider to visually separate it from the specific sub-items.
  final bool isAllOption;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: 36.w,
          right: 20.w,
          top: 11.h,
          bottom: 11.h,
        ),
        child: Row(
          children: [
            Container(
              width: 5.w,
              height: 5.w,
              margin: EdgeInsets.only(right: 10.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.accent
                    : colors.textSecondary.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? colors.accent : colors.textPrimary,
                  fontSize: isAllOption ? 14.sp : 14.sp,
                  fontWeight: isAllOption
                      ? FontWeight.w700
                      : (isSelected ? FontWeight.w600 : FontWeight.w500),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, color: colors.accent, size: 18.sp),
          ],
        ),
      ),
    );

    if (!isAllOption) return row;

    // "All X" row gets a subtle bottom border to separate it from specifics
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Divider(
          height: 1,
          indent: 36.w,
          endIndent: 20.w,
          color: colors.textSecondary.withValues(alpha: 0.12),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Equipment Filter Accordion Sheet
// ═══════════════════════════════════════════════════════════════════

class _EquipmentFilterSheet extends StatefulWidget {
  const _EquipmentFilterSheet({
    required this.currentValue,
    required this.allLabel,
    required this.onSelected,
  });

  final _EquipmentFilterValue? currentValue;
  final String allLabel;
  final ValueChanged<_EquipmentFilterValue?> onSelected;

  @override
  State<_EquipmentFilterSheet> createState() => _EquipmentFilterSheetState();
}

class _EquipmentFilterSheetState extends State<_EquipmentFilterSheet>
    with TickerProviderStateMixin {
  final _controllers = <String, AnimationController>{};
  final _animations = <String, CurvedAnimation>{};

  @override
  void initState() {
    super.initState();
    for (final cat in _equipmentCategories) {
      if (!cat.hasSubTypes) continue;
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      final anim = CurvedAnimation(
        parent: ctrl,
        curve: Curves.easeInOutCubic,
      );
      _controllers[cat.label] = ctrl;
      _animations[cat.label] = anim;
      // Auto-expand the category that contains the current selection.
      if (_isGroupHighlighted(cat)) ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _toggle(String label) {
    final ctrl = _controllers[label]!;
    if (ctrl.status == AnimationStatus.dismissed ||
        ctrl.status == AnimationStatus.reverse) {
      ctrl.forward();
    } else {
      ctrl.reverse();
    }
  }

  /// True when the current filter exactly matches this whole category
  /// (i.e. "All [Category]" is selected).
  bool _isCategorySelected(_EquipmentCategory cat) {
    if (widget.currentValue == null) return false;
    final currentSet =
        widget.currentValue!.rawValues.map((v) => v.toLowerCase()).toSet();
    final catSet = cat.rawValues.map((v) => v.toLowerCase()).toSet();
    return currentSet.length == catSet.length && currentSet.containsAll(catSet);
  }

  /// True when a specific single raw value is the current filter.
  bool _isSubValueSelected(String rawValue) {
    if (widget.currentValue == null) return false;
    return widget.currentValue!.rawValues.length == 1 &&
        widget.currentValue!.rawValues.first.toLowerCase() ==
            rawValue.toLowerCase();
  }

  /// True when any raw value in [cat] overlaps with the current filter —
  /// used to highlight the group header and auto-expand on open.
  bool _isGroupHighlighted(_EquipmentCategory cat) {
    if (widget.currentValue == null) return false;
    final currentSet =
        widget.currentValue!.rawValues.map((v) => v.toLowerCase()).toSet();
    return cat.rawValues.any((rv) => currentSet.contains(rv.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
          // "All Equipment" option
          _FilterMenuItem(
            label: widget.allLabel,
            isSelected: widget.currentValue == null,
            onTap: () => widget.onSelected(null),
          ),
          Divider(
            height: 1,
            color: colors.textSecondary.withValues(alpha: 0.15),
          ),
          // Accordion list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(bottom: 16.h),
              itemCount: _equipmentCategories.length,
              itemBuilder: (_, i) {
                final cat = _equipmentCategories[i];
                final isLast = i == _equipmentCategories.length - 1;

                // Single-value category: tap header selects directly.
                if (!cat.hasSubTypes) {
                  final isSelected = _isGroupHighlighted(cat);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FilterMenuItem(
                        label: cat.label,
                        isSelected: isSelected,
                        onTap: () => widget.onSelected(
                          _EquipmentFilterValue(
                            displayLabel: cat.label,
                            rawValues: cat.rawValues,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 20.w,
                          endIndent: 20.w,
                          color: colors.textSecondary.withValues(alpha: 0.1),
                        ),
                    ],
                  );
                }

                // Multi-value category: animated accordion.
                final anim = _animations[cat.label]!;
                final isGroupHighlighted = _isGroupHighlighted(cat);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _toggle(cat.label),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 14.h,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                cat.label,
                                style: TextStyle(
                                  color: isGroupHighlighted
                                      ? colors.accent
                                      : colors.textPrimary,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isGroupHighlighted)
                              Container(
                                width: 7.w,
                                height: 7.w,
                                margin: EdgeInsets.only(right: 8.w),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            RotationTransition(
                              turns: Tween<double>(begin: 0, end: 0.5)
                                  .animate(anim),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: colors.textSecondary,
                                size: 22.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expanding sub-items
                    SizeTransition(
                      sizeFactor: anim,
                      axisAlignment: -1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // "All [Category]" — matches every raw value in the group
                          _SubMuscleItem(
                            label: 'All ${cat.label}',
                            isSelected: _isCategorySelected(cat),
                            isAllOption: true,
                            onTap: () => widget.onSelected(
                              _EquipmentFilterValue(
                                displayLabel: cat.label,
                                rawValues: cat.rawValues,
                              ),
                            ),
                          ),
                          // Individual sub-type rows
                          ...cat.rawValues.map(
                            (rawValue) => _SubMuscleItem(
                              label: _titleCase(rawValue),
                              isSelected: _isSubValueSelected(rawValue),
                              onTap: () => widget.onSelected(
                                _EquipmentFilterValue(
                                  displayLabel: _titleCase(rawValue),
                                  rawValues: [rawValue],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 20.w,
                        endIndent: 20.w,
                        color: colors.textSecondary.withValues(alpha: 0.1),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Exercise Tile — circular GIF + name + group + "+" / checkmark
// ═══════════════════════════════════════════════════════════════════

class _ExerciseTile extends StatelessWidget {

  const _ExerciseTile({
    required this.exercise,
    required this.onTap,
    this.pickMode = false,
    this.isSelected = false,
    this.showCheckmark = false,
  });
  final Exercise exercise;
  final bool pickMode;
  final bool isSelected;
  final bool showCheckmark;
  final VoidCallback onTap;

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
                          color: AppColors.of(context).black,
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
                        : AppColors.of(context).white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.add_rounded,
                    color: isSelected ? AppColors.of(context).black : colors.textPrimary,
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

// ═══════════════════════════════════════════════════════════════════
// Skeleton tile shown while exercises are loading
// ═══════════════════════════════════════════════════════════════════

class _ExerciseTileSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
      child: Row(
        children: [
          ShimmerBox(
            width: 58.w,
            height: 58.w,
            borderRadius: BorderRadius.circular(12.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140.w, height: 14.h),
                SizedBox(height: 6.h),
                ShimmerBox(width: 80.w, height: 10.h),
              ],
            ),
          ),
          ShimmerBox(
            width: 32.w,
            height: 32.w,
            borderRadius: BorderRadius.circular(16.r),
          ),
        ],
      ),
    );
  }
}
