import 'package:flutter/material.dart';
import 'package:my_gym_bro/core/services/program_seeder.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Catalog of curated, ready-to-install programs (not gym splits): quick
/// 5-minute sessions, no-equipment home plans, calisthenics, core work.
///
/// Names, taglines and day labels are l10n selectors resolved at render /
/// install time, so the created schedule is stored in the user's language.
/// Exercise names prefer the bundled starter set so they resolve offline;
/// anything else falls back to the API or a loggable custom row via
/// [ProgramSeeder.buildSchedule].

enum PremadeCategory { quick, home, calisthenics, core }

enum PremadeLevel { beginner, intermediate, advanced }

typedef L10nText = String Function(AppLocalizations l10n);

class PremadeProgramDay {
  const PremadeProgramDay({required this.label, required this.exercises});

  final L10nText label;
  final List<ProgramExercise> exercises;
}

class PremadeProgram {
  const PremadeProgram({
    required this.id,
    required this.category,
    required this.icon,
    required this.color,
    required this.name,
    required this.tagline,
    required this.level,
    required this.minutes,
    required this.days,
  });

  /// Stable id — not persisted yet, but keeps cards keyed and testable.
  final String id;
  final PremadeCategory category;
  final IconData icon;
  final Color color;
  final L10nText name;
  final L10nText tagline;
  final PremadeLevel level;

  /// Approximate minutes per session, shown on the card.
  final int minutes;
  final List<PremadeProgramDay> days;

  int get exerciseCount => days.fold(0, (sum, d) => sum + d.exercises.length);
}

String premadeCategoryLabel(AppLocalizations l10n, PremadeCategory c) =>
    switch (c) {
      PremadeCategory.quick => l10n.premadeCategoryQuick,
      PremadeCategory.home => l10n.premadeCategoryHome,
      PremadeCategory.calisthenics => l10n.premadeCategoryCalisthenics,
      PremadeCategory.core => l10n.premadeCategoryCore,
    };

String premadeLevelLabel(AppLocalizations l10n, PremadeLevel level) =>
    switch (level) {
      PremadeLevel.beginner => l10n.premadeLevelBeginner,
      PremadeLevel.intermediate => l10n.premadeLevelIntermediate,
      PremadeLevel.advanced => l10n.premadeLevelAdvanced,
    };

final List<PremadeProgram> premadePrograms = [
  // ── Quick (5-minute) ──────────────────────────────────────────────
  PremadeProgram(
    id: 'wake_up_5min',
    category: PremadeCategory.quick,
    icon: Icons.wb_sunny_rounded,
    color: const Color(0xFFFF9500),
    name: (l) => l.premadeWakeUpName,
    tagline: (l) => l.premadeWakeUpTagline,
    level: PremadeLevel.beginner,
    minutes: 5,
    days: [
      PremadeProgramDay(
        label: (l) => l.premadeDayFullBody,
        exercises: const [
          ProgramExercise('Jumping Jack', 2, 20, 'Cardio'),
          ProgramExercise('Push-Up', 2, 10, 'Chest'),
          ProgramExercise('Bodyweight Squat', 2, 15, 'Quads'),
          ProgramExercise('Mountain Climber', 2, 20, 'Core'),
        ],
      ),
    ],
  ),
  PremadeProgram(
    id: 'core_blast_5min',
    category: PremadeCategory.quick,
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFFF3B30),
    name: (l) => l.premadeCoreBlastName,
    tagline: (l) => l.premadeCoreBlastTagline,
    level: PremadeLevel.beginner,
    minutes: 5,
    days: [
      PremadeProgramDay(
        label: (l) => l.premadeDayCore,
        exercises: const [
          ProgramExercise('Crunch', 2, 15, 'Core'),
          ProgramExercise('Russian Twist', 2, 20, 'Core'),
          ProgramExercise('Lying Leg Raise', 2, 12, 'Core'),
          ProgramExercise('Bicycle Crunch', 2, 15, 'Core'),
        ],
      ),
    ],
  ),
  PremadeProgram(
    id: 'arm_pump_5min',
    category: PremadeCategory.quick,
    icon: Icons.bolt_rounded,
    color: const Color(0xFFFFCC00),
    name: (l) => l.premadeArmPumpName,
    tagline: (l) => l.premadeArmPumpTagline,
    level: PremadeLevel.beginner,
    minutes: 5,
    days: [
      PremadeProgramDay(
        label: (l) => l.premadeDayArms,
        exercises: const [
          ProgramExercise('Dumbbell Standing Biceps Curl', 2, 12, 'Biceps'),
          ProgramExercise('Dumbbell Hammer Curl', 2, 12, 'Biceps'),
          ProgramExercise('Dumbbell Lying Triceps Extension', 2, 12, 'Triceps'),
          ProgramExercise('Bench Dip', 2, 12, 'Triceps'),
        ],
      ),
    ],
  ),

  // ── Home (no / minimal equipment) ─────────────────────────────────
  PremadeProgram(
    id: 'home_full_body',
    category: PremadeCategory.home,
    icon: Icons.home_rounded,
    color: const Color(0xFF007AFF),
    name: (l) => l.premadeHomeFullBodyName,
    tagline: (l) => l.premadeHomeFullBodyTagline,
    level: PremadeLevel.beginner,
    minutes: 30,
    days: [
      PremadeProgramDay(
        label: (l) => '${l.premadeDayFullBody} A',
        exercises: const [
          ProgramExercise('Push-Up', 3, 12, 'Chest'),
          ProgramExercise('Bodyweight Squat', 3, 15, 'Quads'),
          ProgramExercise('Incline Push-Up', 3, 12, 'Chest'),
          ProgramExercise('Glute Bridge', 3, 15, 'Glutes'),
          ProgramExercise('Crunch', 3, 15, 'Core'),
        ],
      ),
      PremadeProgramDay(
        label: (l) => '${l.premadeDayFullBody} B',
        exercises: const [
          ProgramExercise('Bench Dip', 3, 12, 'Triceps'),
          ProgramExercise('Bodyweight Lunge', 3, 12, 'Quads'),
          ProgramExercise('Superman', 3, 15, 'Lower Back'),
          ProgramExercise('Mountain Climber', 3, 20, 'Core'),
          ProgramExercise('Bodyweight Standing Calf Raise', 3, 20, 'Calves'),
        ],
      ),
      PremadeProgramDay(
        label: (l) => '${l.premadeDayFullBody} C',
        exercises: const [
          ProgramExercise('Pike Push-Up', 3, 10, 'Shoulders'),
          ProgramExercise('Split Squat', 3, 12, 'Quads'),
          ProgramExercise('Push-Up', 3, 12, 'Chest'),
          ProgramExercise('Russian Twist', 3, 20, 'Core'),
          ProgramExercise('Glute Bridge', 3, 15, 'Glutes'),
        ],
      ),
    ],
  ),
  PremadeProgram(
    id: 'home_dumbbell',
    category: PremadeCategory.home,
    icon: Icons.fitness_center_rounded,
    color: const Color(0xFF34C759),
    name: (l) => l.premadeHomeDumbbellName,
    tagline: (l) => l.premadeHomeDumbbellTagline,
    level: PremadeLevel.intermediate,
    minutes: 40,
    days: [
      PremadeProgramDay(
        label: (l) => l.premadeDayUpper,
        exercises: const [
          ProgramExercise('Dumbbell Bench Press', 3, 10, 'Chest'),
          ProgramExercise('Dumbbell One Arm Bent-Over Row', 3, 10, 'Lats'),
          ProgramExercise('Dumbbell Seated Shoulder Press', 3, 10, 'Shoulders'),
          ProgramExercise('Dumbbell Standing Biceps Curl', 3, 12, 'Biceps'),
          ProgramExercise('Dumbbell Lying Triceps Extension', 3, 12, 'Triceps'),
        ],
      ),
      PremadeProgramDay(
        label: (l) => l.premadeDayLower,
        exercises: const [
          ProgramExercise('Dumbbell Goblet Squat', 3, 12, 'Quads'),
          ProgramExercise('Dumbbell Lunge', 3, 12, 'Quads'),
          ProgramExercise('Dumbbell Romanian Deadlift', 3, 12, 'Hamstrings'),
          ProgramExercise('Dumbbell Shrug', 3, 15, 'Traps'),
          ProgramExercise('Dumbbell Lateral Raise', 3, 15, 'Shoulders'),
        ],
      ),
    ],
  ),

  // ── Calisthenics ──────────────────────────────────────────────────
  PremadeProgram(
    id: 'calisthenics_basics',
    category: PremadeCategory.calisthenics,
    icon: Icons.accessibility_new_rounded,
    color: const Color(0xFF30B0C7),
    name: (l) => l.premadeCalisthenicsBasicsName,
    tagline: (l) => l.premadeCalisthenicsBasicsTagline,
    level: PremadeLevel.beginner,
    minutes: 35,
    days: [
      PremadeProgramDay(
        label: (l) => l.premadeDayPush,
        exercises: const [
          ProgramExercise('Push-Up', 4, 12, 'Chest'),
          ProgramExercise('Chest Dip', 3, 10, 'Chest'),
          ProgramExercise('Pike Push-Up', 3, 10, 'Shoulders'),
          ProgramExercise('Diamond Push-Up', 3, 10, 'Triceps'),
        ],
      ),
      PremadeProgramDay(
        label: (l) => l.premadeDayPull,
        exercises: const [
          ProgramExercise('Wide Grip Pull-Up', 4, 8, 'Lats'),
          ProgramExercise('Pull Up (Neutral Grip)', 3, 8, 'Lats'),
          ProgramExercise('Inverted Row', 3, 10, 'Upper Back'),
          ProgramExercise('Chin-Up', 3, 8, 'Biceps'),
        ],
      ),
      PremadeProgramDay(
        label: (l) => l.premadeDayLegsCore,
        exercises: const [
          ProgramExercise('Bodyweight Squat', 4, 15, 'Quads'),
          ProgramExercise('Bodyweight Lunge', 3, 12, 'Quads'),
          ProgramExercise('Glute Bridge', 3, 15, 'Glutes'),
          ProgramExercise('Hanging Knee Raise', 3, 12, 'Core'),
          ProgramExercise('Crunch', 3, 20, 'Core'),
        ],
      ),
    ],
  ),
  PremadeProgram(
    id: 'calisthenics_strength',
    category: PremadeCategory.calisthenics,
    icon: Icons.sports_gymnastics_rounded,
    color: const Color(0xFFAF52DE),
    name: (l) => l.premadeCalisthenicsStrengthName,
    tagline: (l) => l.premadeCalisthenicsStrengthTagline,
    level: PremadeLevel.advanced,
    minutes: 45,
    days: [
      PremadeProgramDay(
        label: (l) => l.premadeDayPush,
        exercises: const [
          ProgramExercise('Archer Push-Up', 4, 8, 'Chest'),
          ProgramExercise('Weighted Tricep Dips', 4, 8, 'Triceps'),
          ProgramExercise('Handstand Push-Up', 3, 6, 'Shoulders'),
          ProgramExercise('Diamond Push-Up', 3, 12, 'Triceps'),
        ],
      ),
      PremadeProgramDay(
        label: (l) => l.premadeDayPull,
        exercises: const [
          ProgramExercise('Wide Grip Pull-Up', 4, 10, 'Lats'),
          ProgramExercise('Archer Pull-Up', 3, 6, 'Lats'),
          ProgramExercise('Pull Up (Neutral Grip)', 3, 10, 'Lats'),
          ProgramExercise('Hanging Leg Raise', 3, 12, 'Core'),
        ],
      ),
    ],
  ),

  // ── Core ──────────────────────────────────────────────────────────
  PremadeProgram(
    id: 'core_abs',
    category: PremadeCategory.core,
    icon: Icons.adjust_rounded,
    color: const Color(0xFFFF2D55),
    name: (l) => l.premadeCoreAbsName,
    tagline: (l) => l.premadeCoreAbsTagline,
    level: PremadeLevel.intermediate,
    minutes: 20,
    days: [
      PremadeProgramDay(
        label: (l) => '${l.premadeDayCore} A',
        exercises: const [
          ProgramExercise('Crunch', 3, 20, 'Core'),
          ProgramExercise('Hanging Knee Raise', 3, 12, 'Core'),
          ProgramExercise('Russian Twist', 3, 20, 'Core'),
          ProgramExercise('Bicycle Crunch', 3, 15, 'Core'),
        ],
      ),
      PremadeProgramDay(
        label: (l) => '${l.premadeDayCore} B',
        exercises: const [
          ProgramExercise('Lying Leg Raise', 3, 15, 'Core'),
          ProgramExercise('Mountain Climber', 3, 20, 'Core'),
          ProgramExercise('Sit-Up', 3, 15, 'Core'),
          ProgramExercise('Superman', 3, 15, 'Lower Back'),
        ],
      ),
    ],
  ),
];
