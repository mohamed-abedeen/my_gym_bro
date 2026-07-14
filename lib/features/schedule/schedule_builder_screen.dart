import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/features/exercises/exercise_browser_screen.dart';
import 'package:my_gym_bro/features/exercises/exercise_detail_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';
import 'package:my_gym_bro/shared/widgets/oc_glass_btn.dart';

// ── Local UI Models ──

class _DayModel {

  _DayModel({
    required this.label,
    List<_ExerciseModel>? exercises,
  }) : exercises = exercises ?? [];
  String label;
  String dayOfWeek = ''; // e.g. "Saturday", "Monday"
  bool isRestDay = false;
  final List<_ExerciseModel> exercises;
}

class _ExerciseModel {

  _ExerciseModel({
    required this.exerciseId,
    required this.name,
    this.gifUrl,
    List<_SetModel>? sets,
  }) : sets = sets ?? [_SetModel(), _SetModel(), _SetModel()];
  final String exerciseId;
  final String name;
  final String? gifUrl;
  final List<_SetModel> sets;
  bool showSets = false;
}

class _SetModel {
  _SetModel();
  double weight = 60;
  int reps = 10;
}

// ═══════════════════════════════════════════════════════════════════
// Schedule Builder — matches Figma "Create Schedule" / "Edit Schedule"
// ═══════════════════════════════════════════════════════════════════

class ScheduleBuilderScreen extends ConsumerStatefulWidget {

  const ScheduleBuilderScreen({super.key, this.scheduleId});
  final int? scheduleId;

  @override
  ConsumerState<ScheduleBuilderScreen> createState() =>
      _ScheduleBuilderScreenState();
}

class _ScheduleBuilderScreenState
    extends ConsumerState<ScheduleBuilderScreen> {
  final _nameController = TextEditingController(text: 'Program 1');
  final List<_DayModel> _days = [];
  int _expandedDay = -1;
  bool _saving = false;
  bool get _isEditMode => widget.scheduleId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadExistingSchedule();
    }
  }

  Future<void> _loadExistingSchedule() async {
    final dao = ref.read(scheduleDaoProvider);
    final exerciseDao = ref.read(exerciseDaoProvider);

    final schedules = await dao.getAll();
    final schedule =
        schedules.where((s) => s.localId == widget.scheduleId).firstOrNull;
    if (schedule == null) return;

    _nameController.text = schedule.name;

    final days = await dao.getDays(schedule.localId);
    final dayModels = <_DayModel>[];

    for (final day in days) {
      if (day.isRestDay ||
          (day.label?.toLowerCase().contains('rest') ?? false)) {
        continue;
      }
      final scheduledExercises = await dao.getExercises(day.localId);
      final exerciseIds =
          scheduledExercises.map((se) => se.exerciseId).toList();
      final exercises = exerciseIds.isNotEmpty
          ? await exerciseDao.findByExerciseIds(exerciseIds)
          : <Exercise>[];
      final exerciseMap = {for (final e in exercises) e.exerciseId: e};

      final exModels = scheduledExercises.map((se) {
        final ex = exerciseMap[se.exerciseId];
        final sets = List.generate(
          se.targetSets,
          (_) => _SetModel()..reps = se.targetReps,
        );
        return _ExerciseModel(
          exerciseId: se.exerciseId,
          name: ex?.name ?? se.exerciseId,
          gifUrl: ex?.gifUrl,
          sets: sets,
        );
      }).toList();

      dayModels.add(_DayModel(
        label: day.label ?? '',
        exercises: exModels,
      ));
    }

    if (mounted) {
      setState(() {
        _days
          ..clear()
          ..addAll(dayModels);
        _expandedDay = _days.isNotEmpty ? 0 : -1;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: X + (trash in edit mode) + checkmark ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.contentPaddingH.w, 10.h, AppSizes.contentPaddingH.w, 0,
              ),
              child: Row(
                children: [
                  // Close — liquid glass
                  OcGlassBtn(
                    type: OcGlassBtnType.close,
                    size: 40,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (_isEditMode) ...[
                    // Delete — liquid glass (red-tinted)
                    OcGlassBtn(
                      type: OcGlassBtnType.delete,
                      size: 40,
                      onTap: _deleteSchedule,
                    ),
                    SizedBox(width: 10.w),
                    // Share — liquid glass
                    const OcGlassBtn(
                      type: OcGlassBtnType.share,
                      size: 40,
                    ),
                    SizedBox(width: 10.w),
                  ],
                  // Done / Save — liquid glass (green checkmark when ready)
                  OcGlassBtn(
                    type: OcGlassBtnType.done,
                    size: 40,
                    isActive: !_saving,
                    onTap: _saving ? null : _saveSchedule,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // ── Title ──
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.contentPaddingH.w,
              ),
              child: Text(
                _isEditMode ? _nameController.text : _nameController.text,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 30.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // ── Scrollable content ──
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                children: [
                  // ── Schedule Name field ──
                  _buildNameField(),
                  SizedBox(height: 10.h),

                  // ── Day cards (collapsed or expanded) ──
                  for (var i = 0; i < _days.length; i++) ...[
                    _buildDayCard(i, l10n),
                    SizedBox(height: 10.h),
                  ],

                  // ── Add Day button ──
                  _buildAddDayButton(l10n),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Schedule Name Field ──
  Widget _buildNameField() {
    final colors = AppColors.of(context);
    return Container(
      height: 60.h,
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(25.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Text('Tt',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
              )),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Schedule Name',
                hintStyle: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Icon(Icons.edit_rounded,
              color: colors.textPrimary, size: 16.sp),
        ],
      ),
    );
  }

  // ── Add Day Button ──
  Widget _buildAddDayButton(AppLocalizations l10n) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: _addDay,
      child: Container(
        height: 60.h,
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(25.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: colors.accent, size: 20.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                l10n.addDay,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // + button
            LiquidGlassButton(
              width: 40.w,
              height: 40.h,
              opacity: 0.15,
              radius: 20.r,
              child: Icon(Icons.add_rounded,
                  color: colors.textPrimary, size: 22.sp),
            ),
          ],
        ),
      ),
    );
  }

  // ── Day Card (collapsed / expanded) ──
  Widget _buildDayCard(int i, AppLocalizations l10n) {
    final colors = AppColors.of(context);
    final day = _days[i];
    final isExpanded = i == _expandedDay;
    final dayLabel = day.label.isNotEmpty ? day.label : 'Day ${i + 1}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(25.r),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Day header row ──
          GestureDetector(
            onTap: () => setState(() {
              _expandedDay = _expandedDay == i ? -1 : i;
            }),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: colors.accent, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    dayLabel,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _days.removeAt(i);
                        if (_expandedDay >= _days.length) {
                          _expandedDay = _days.length - 1;
                        }
                      });
                    },
                    child: Icon(Icons.delete_outline_rounded,
                        color: colors.textPrimary, size: 20.sp),
                  ),
                  SizedBox(width: 12.w),
                ],
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: colors.textPrimary,
                  size: 28.sp,
                ),
              ],
            ),
          ),

          // ── Expanded content ──
          if (isExpanded) ...[
            SizedBox(height: 10.h),

            // ── Tag pills (day of week + label) ──
            _buildTagPills(i),
            SizedBox(height: 16.h),

            // ── Exercises (drag-to-reorder) ──
            // shrinkWrap + NeverScrollableScrollPhysics prevent scroll
            // conflicts with the outer ListView.
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  // Standard Flutter reorder correction.
                  if (newIndex > oldIndex) newIndex -= 1;
                  final moved = _days[i].exercises.removeAt(oldIndex);
                  _days[i].exercises.insert(newIndex, moved);
                });
              },
              children: [
                for (var exIdx = 0; exIdx < day.exercises.length; exIdx++)
                  _buildExerciseRow(
                    i, exIdx, day.exercises[exIdx], l10n,
                    // exerciseId is guaranteed unique within a day.
                    key: ValueKey(day.exercises[exIdx].exerciseId),
                  ),
              ],
            ),

            // Divider before Add Exercise
            if (day.exercises.isNotEmpty) ...[
              Container(
                height: 1,
                color: colors.divider,
                margin: EdgeInsets.symmetric(vertical: 8.h),
              ),
            ],

            // ── Add Exercise button ──
            GestureDetector(
              onTap: () => _pickExercise(i),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  children: [
                    LiquidGlassButton(
                      width: 36.w,
                      height: 36.h,
                      opacity: 0.15,
                      radius: 18.r,
                      child: Icon(Icons.add_rounded,
                          color: colors.textPrimary, size: 20.sp),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      l10n.addExercise,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tag pills for day-of-week and label ──
  Widget _buildTagPills(int dayIndex) {
    final colors = AppColors.of(context);
    final day = _days[dayIndex];

    return Row(
      children: [
        // Day of week pill
        GestureDetector(
          onTap: () => _showDayOfWeekPicker(dayIndex),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: day.dayOfWeek.isNotEmpty
                  ? const Color(0xFF4B4F24)
                  : colors.divider,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Text(
              day.dayOfWeek.isNotEmpty ? day.dayOfWeek : 'Day',
              style: TextStyle(
                color: day.dayOfWeek.isNotEmpty
                    ? colors.accent
                    : colors.textPrimary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        // Label pill (editable)
        GestureDetector(
          onTap: () => _editDayLabel(dayIndex),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: colors.divider,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Text(
              day.label.isNotEmpty ? day.label : 'Label',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Exercise Row with action buttons and sets ──
  // [key] is required by ReorderableListView — callers pass ValueKey(ex.exerciseId).
  Widget _buildExerciseRow(
      int dayIdx, int exIdx, _ExerciseModel ex, AppLocalizations l10n,
      {Key? key}) {
    final colors = AppColors.of(context);
    return Padding(
      key: key,
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider above exercise
          Container(
            height: 1,
            color: colors.divider,
            margin: EdgeInsets.only(bottom: 10.h),
          ),

          // Exercise header: drag handle + GIF + name + action buttons
          Row(
            children: [
              // Drag handle — hold to reorder within the day
              ReorderableDragStartListener(
                index: exIdx,
                child: Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: Icon(
                    Icons.drag_handle,
                    color: colors.textSecondary,
                    size: 22.sp,
                  ),
                ),
              ),
              // Rounded square GIF thumbnail (Figma: 58x58, radius 12)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: ex.gifUrl != null
                    ? CachedNetworkImage(
                        cacheManager: ExerciseGifCache.instance,
                        imageUrl: ex.gifUrl!,
                        width: 50.w,
                        height: 50.h,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                        memCacheHeight: 120,
                        placeholder: (_, __) => _exercisePlaceholder(),
                        errorWidget: (_, __, ___) => _exercisePlaceholder(),
                      )
                    : _exercisePlaceholder(),
              ),
              SizedBox(width: 10.w),
              // Exercise name
              Expanded(
                child: Text(
                  ex.name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Action buttons pill (?, checkmark/edit, delete)
              _buildActionPill(dayIdx, exIdx, ex),
            ],
          ),

          // ── Sets table (shown when checkmark is tapped) ──
          if (ex.showSets) ...[
            SizedBox(height: 12.h),
            _buildSetsTable(dayIdx, exIdx, ex, l10n),
          ],
        ],
      ),
    );
  }

  // ── Action pill: ? + check/edit + trash ──
  Widget _buildActionPill(int dayIdx, int exIdx, _ExerciseModel ex) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.of(context).white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ? info button — opens How-To detail
          _miniActionButton(
            icon: Icons.help_outline_rounded,
            onTap: () => _showExerciseInfo(ex),
          ),
          SizedBox(width: 4.w),
          // Checkmark / edit toggle sets visibility
          _miniActionButton(
            icon: ex.showSets ? Icons.check_rounded : Icons.edit_outlined,
            onTap: () {
              setState(() {
                _days[dayIdx].exercises[exIdx].showSets =
                    !_days[dayIdx].exercises[exIdx].showSets;
              });
            },
          ),
          SizedBox(width: 4.w),
          // Delete
          _miniActionButton(
            icon: Icons.delete_outline_rounded,
            onTap: () {
              setState(() {
                _days[dayIdx].exercises.removeAt(exIdx);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _miniActionButton(
      {required IconData icon, required VoidCallback onTap}) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28.w,
        height: 28.h,
        decoration: BoxDecoration(
          color: AppColors.of(context).white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Icon(icon, color: colors.textPrimary, size: 16.sp),
      ),
    );
  }

  // ── Sets Table ──
  Widget _buildSetsTable(
      int dayIdx, int exIdx, _ExerciseModel ex, AppLocalizations l10n) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.only(left: 8.w, right: 8.w),
          child: Row(
            children: [
              SizedBox(
                width: 50.w,
                child: Text('Sets',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              Expanded(
                child: Center(
                  child: Text('weights kg',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ),
              SizedBox(
                width: 50.w,
                child: Text('Rips',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
        ),
        SizedBox(height: 6.h),

        // Set rows
        ...ex.sets.asMap().entries.map((entry) {
          final setIdx = entry.key;
          final setModel = entry.value;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
            child: Row(
              children: [
                SizedBox(
                  width: 50.w,
                  child: Text(
                    '${setIdx + 1}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _editWeight(dayIdx, exIdx, setIdx),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.unfold_more,
                              color: colors.textSecondary, size: 14.sp),
                          Text(
                            '${setModel.weight.toInt()}',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 50.w,
                  child: GestureDetector(
                    onTap: () => _editReps(dayIdx, exIdx, setIdx),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.unfold_more,
                            color: colors.textSecondary, size: 14.sp),
                        Text(
                          '${setModel.reps}',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Add Set pill
        Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: GestureDetector(
            onTap: () {
              setState(() {
                ex.sets.add(_SetModel());
              });
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6.h),
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Text(
                l10n.addSet,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _exercisePlaceholder() {
    final colors = AppColors.of(context);
    return Container(
        width: 50.w,
        height: 50.h,
        decoration: BoxDecoration(
          color: colors.separator,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(Icons.fitness_center_rounded,
            color: colors.textSecondary, size: 22.sp),
      );
  }

  // ── Actions ──

  void _addDay() {
    setState(() {
      _days.add(_DayModel(label: ''));
      _expandedDay = _days.length - 1;
    });
  }

  void _showDayOfWeekPicker(int dayIndex) {
    final colors = AppColors.of(context);
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        height: 250.h,
        color: colors.panelBackground,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              height: 44.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text('Cancel',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 14.sp)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text('Done',
                        style: TextStyle(
                            color: colors.accent, fontSize: 14.sp)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                backgroundColor: colors.panelBackground,
                itemExtent: 36.h,
                onSelectedItemChanged: (idx) {
                  setState(() {
                    _days[dayIndex].dayOfWeek = weekdays[idx];
                  });
                },
                children: weekdays
                    .map((d) => Center(
                          child: Text(d,
                              style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 16.sp)),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editDayLabel(int dayIndex) {
    final colors = AppColors.of(context);
    final controller = TextEditingController(text: _days[dayIndex].label);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.panelBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        title: Text('Day Label',
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary, fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: 'e.g. Chest Day',
            hintStyle:
                TextStyle(color: colors.textSecondary, fontSize: 16.sp),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.accent)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: colors.textSecondary, fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _days[dayIndex].label = controller.text;
              });
              Navigator.pop(ctx);
            },
            child: Text('Save',
                style:
                    TextStyle(color: colors.accent, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  void _editWeight(int dayIdx, int exIdx, int setIdx) {
    _showNumberPicker(
      title: 'Weight (kg)',
      initial: _days[dayIdx].exercises[exIdx].sets[setIdx].weight.toInt(),
      min: 0,
      max: 500,
      onDone: (value) {
        setState(() {
          _days[dayIdx].exercises[exIdx].sets[setIdx].weight = value.toDouble();
        });
      },
    );
  }

  void _editReps(int dayIdx, int exIdx, int setIdx) {
    _showNumberPicker(
      title: 'Reps',
      initial: _days[dayIdx].exercises[exIdx].sets[setIdx].reps,
      min: 1,
      max: 100,
      onDone: (value) {
        setState(() {
          _days[dayIdx].exercises[exIdx].sets[setIdx].reps = value;
        });
      },
    );
  }

  void _showNumberPicker({
    required String title,
    required int initial,
    required int min,
    required int max,
    required ValueChanged<int> onDone,
  }) {
    final colors = AppColors.of(context);
    var selected = initial;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        height: 250.h,
        color: colors.panelBackground,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              height: 44.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text('Cancel',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 14.sp)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(title,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text('Done',
                        style: TextStyle(
                            color: colors.accent, fontSize: 14.sp)),
                    onPressed: () {
                      onDone(selected);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                backgroundColor: colors.panelBackground,
                itemExtent: 36.h,
                scrollController:
                    FixedExtentScrollController(initialItem: initial - min),
                onSelectedItemChanged: (idx) => selected = min + idx,
                children: List.generate(
                  max - min + 1,
                  (i) => Center(
                    child: Text(
                      '${min + i}',
                      style: TextStyle(
                          color: colors.textPrimary, fontSize: 18.sp),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExercise(int dayIndex) async {
    if (dayIndex >= _days.length) return;

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ExerciseBrowserScreen(
          multiPickMode: true,
          onMultiSelect: (exercises) {
            setState(() {
              for (final exercise in exercises) {
                // Avoid duplicate exercises in the same day
                final alreadyAdded = _days[dayIndex]
                    .exercises
                    .any((e) => e.exerciseId == exercise.exerciseId);
                if (!alreadyAdded) {
                  _days[dayIndex].exercises.add(
                    _ExerciseModel(
                      exerciseId: exercise.exerciseId,
                      name: exercise.name,
                      gifUrl: exercise.gifUrl,
                    ),
                  );
                }
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _showExerciseInfo(_ExerciseModel ex) async {
    final exerciseDao = ExerciseDao(ref.read(databaseProvider));
    final exercises = await exerciseDao.findByExerciseIds([ex.exerciseId]);
    if (exercises.isNotEmpty && mounted) {
      unawaited(Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => ExerciseDetailScreen(exercise: exercises.first),
        ),
      ));
    }
  }

  Future<void> _saveSchedule() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _days.isEmpty) return;

    setState(() => _saving = true);

    try {
      final scheduleDao = ScheduleDao(ref.read(databaseProvider));

      int scheduleId;

      if (_isEditMode) {
        scheduleId = widget.scheduleId!;
        await scheduleDao.updateSchedule(
          scheduleId,
          SchedulesCompanion(
            name: Value(name),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await scheduleDao.clearScheduleContent(scheduleId);
      } else {
        scheduleId = await scheduleDao.createSchedule(
          SchedulesCompanion(
            name: Value(name),
            isActive: const Value(true),
            createdAt: Value(DateTime.now()),
          ),
        );
        await scheduleDao.setActive(scheduleId);
      }

      var dayIndex = 0;
      for (var d = 0; d < _days.length; d++) {
        final day = _days[d];
        final label = day.label.isNotEmpty
            ? day.label
            : (day.dayOfWeek.isNotEmpty
                ? day.dayOfWeek
                : 'Day ${d + 1}');
        final dayId = await scheduleDao.addDay(
          ScheduleDaysCompanion(
            scheduleId: Value(scheduleId),
            dayIndex: Value(dayIndex),
            label: Value(label),
            isRestDay: const Value(false),
            createdAt: Value(DateTime.now()),
          ),
        );
        dayIndex++;

        for (var e = 0; e < day.exercises.length; e++) {
          final ex = day.exercises[e];
          await scheduleDao.addExercise(
            ScheduledExercisesCompanion(
              scheduleDayId: Value(dayId),
              exerciseId: Value(ex.exerciseId),
              orderIndex: Value(e),
              targetSets: Value(ex.sets.length),
              targetReps: Value(ex.sets.isNotEmpty ? ex.sets.first.reps : 10),
              createdAt: Value(DateTime.now()),
            ),
          );
        }

      }

      // Cache-on-save: make sure every exercise referenced by this schedule is
      // in the local cache so muscle-recovery and history resolve offline —
      // covers ids that arrived via an imported/shared schedule rather than
      // the (already-cached) browser. Best-effort; never blocks the save.
      final savedIds = <String>[
        for (final day in _days)
          for (final ex in day.exercises) ex.exerciseId,
      ];
      await ref.read(exerciseRepositoryProvider).ensureCached(savedIds);

      if (mounted) Navigator.of(context).pop();
    } on Exception catch (_) {
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteSchedule() async {
    if (!_isEditMode) return;
    final colors = AppColors.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Delete Schedule',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this schedule? This cannot be undone.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: colors.textPrimary, fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: colors.danger, fontSize: 14.sp)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final dao = ref.read(scheduleDaoProvider);
    await dao.deleteSchedule(widget.scheduleId!);
    if (mounted) Navigator.of(context).pop();
  }
}
