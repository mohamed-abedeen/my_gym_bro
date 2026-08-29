import 'package:my_gym_bro/core/security/input_sanitiser.dart';

/// What a share link carries: a whole program (split) or a single day.
enum RoutineShareKind { program, day }

/// Versioned wire format for a shared routine.
///
/// The payload is fully self-contained — exercise NAMES always travel with
/// the ids so the recipient can preview and import even when an id doesn't
/// resolve on their device (custom exercises, stale catalogue). Sanitisation
/// runs on encode AND decode; the server (`create_routine_share`, migration
/// 020) scrubs a third time and its copy is authoritative.
class RoutineSharePayload {
  const RoutineSharePayload({
    required this.kind,
    required this.title,
    required this.days,
  });

  static const int version = 1;
  static const int maxDays = 31;
  static const int maxExercisesPerDay = 50;
  static const int maxTitleLength = 80;

  final RoutineShareKind kind;
  final String title;
  final List<SharedDay> days;

  /// Total non-rest exercises — zero means there is nothing worth sharing.
  int get exerciseCount => days
      .where((d) => !d.isRest)
      .fold(0, (sum, d) => sum + d.exercises.length);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': version,
        'kind': kind.name,
        'title': InputSanitiser.sanitise(title, maxLength: maxTitleLength),
        'days': [
          for (final day in days.take(maxDays)) day.toJson(),
        ],
      };

  /// Decodes (and re-sanitises) a payload received from the server.
  static RoutineShareDecodeResult decode(Object? json) {
    if (json is! Map) return const RoutineShareMalformed();
    final v = json['v'];
    if (v is! int) return const RoutineShareMalformed();
    if (v > version) return const RoutineShareUnsupportedVersion();
    if (v != version) return const RoutineShareMalformed();

    final kind = switch (json['kind']) {
      'program' => RoutineShareKind.program,
      'day' => RoutineShareKind.day,
      _ => null,
    };
    final rawTitle = json['title'];
    final rawDays = json['days'];
    if (kind == null || rawTitle is! String || rawDays is! List) {
      return const RoutineShareMalformed();
    }
    final title =
        InputSanitiser.sanitise(rawTitle, maxLength: maxTitleLength);
    if (title.isEmpty) return const RoutineShareMalformed();

    final days = <SharedDay>[];
    for (final rawDay in rawDays.take(maxDays)) {
      final day = SharedDay._decode(rawDay);
      if (day == null) return const RoutineShareMalformed();
      days.add(day);
    }
    if (days.isEmpty || kind == RoutineShareKind.day && days.length != 1) {
      return const RoutineShareMalformed();
    }
    final payload = RoutineSharePayload(kind: kind, title: title, days: days);
    if (payload.exerciseCount == 0) return const RoutineShareMalformed();
    return RoutineShareDecoded(payload);
  }
}

/// One day of the shared cycle (days are an ordered cycle, not weekdays).
class SharedDay {
  const SharedDay({
    required this.label,
    required this.isRest,
    required this.exercises,
  });

  static const int maxLabelLength = 60;

  final String label;
  final bool isRest;
  final List<SharedExercise> exercises;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': InputSanitiser.sanitise(label, maxLength: maxLabelLength),
        'rest': isRest,
        'exercises': [
          if (!isRest)
            for (final e
                in exercises.take(RoutineSharePayload.maxExercisesPerDay))
              if (e._isEncodable) e.toJson(),
        ],
      };

  static SharedDay? _decode(Object? json) {
    if (json is! Map) return null;
    final rawExercises = json['exercises'];
    final isRest = json['rest'] == true;
    if (rawExercises is! List) return null;
    final exercises = <SharedExercise>[];
    if (!isRest) {
      for (final raw
          in rawExercises.take(RoutineSharePayload.maxExercisesPerDay)) {
        final exercise = SharedExercise._decode(raw);
        if (exercise != null) exercises.add(exercise);
      }
    }
    return SharedDay(
      label: InputSanitiser.sanitise(
        json['label'] is String ? json['label'] as String : '',
        maxLength: maxLabelLength,
      ),
      isRest: isRest,
      exercises: exercises,
    );
  }
}

/// One exercise slot: portable catalogue id when available, name always.
class SharedExercise {
  const SharedExercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.exerciseId,
    this.muscleGroup,
    this.durationSeconds,
    this.distance,
  });

  static const int maxNameLength = 120;
  static const int maxMuscleLength = 40;

  /// ExerciseDB catalogue id. Device-local `custom_*` ids are stripped on
  /// encode — [name] + [muscleGroup] carry the meaning for the recipient.
  final String? exerciseId;
  final String name;
  final String? muscleGroup;
  final int sets;
  final int reps;
  final int? durationSeconds;
  final double? distance;

  static final _idRx = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  bool get _isEncodable =>
      InputSanitiser.sanitise(name, maxLength: maxNameLength).isNotEmpty ||
      _portableId != null;

  String? get _portableId {
    final id = exerciseId;
    if (id == null || id.startsWith('custom_') || !_idRx.hasMatch(id)) {
      return null;
    }
    return id;
  }

  Map<String, dynamic> toJson() {
    var cleanName = InputSanitiser.sanitise(name, maxLength: maxNameLength);
    final id = _portableId;
    if (cleanName.isEmpty && id != null) cleanName = id;
    final muscle = muscleGroup == null
        ? null
        : InputSanitiser.sanitise(muscleGroup!, maxLength: maxMuscleLength);
    return <String, dynamic>{
      if (id != null) 'id': id,
      'name': cleanName,
      if (muscle != null && muscle.isNotEmpty) 'muscle': muscle,
      'sets': sets.clamp(1, 30),
      'reps': reps.clamp(1, 999),
      if (durationSeconds != null)
        'durationSeconds': durationSeconds!.clamp(1, 86400),
      if (distance != null) 'distance': distance!.clamp(0, 1000).toDouble(),
    };
  }

  static SharedExercise? _decode(Object? json) {
    if (json is! Map) return null;
    final rawId = json['id'];
    final id = rawId is String &&
            _idRx.hasMatch(rawId) &&
            !rawId.startsWith('custom_')
        ? rawId
        : null;
    var name = InputSanitiser.sanitise(
      json['name'] is String ? json['name'] as String : '',
      maxLength: maxNameLength,
    );
    if (name.isEmpty) {
      if (id == null) return null; // nothing to identify the exercise by
      name = id;
    }
    final rawMuscle = json['muscle'];
    final muscle = rawMuscle is String
        ? InputSanitiser.sanitise(rawMuscle, maxLength: maxMuscleLength)
        : '';
    final duration = _positiveInt(json['durationSeconds'], max: 86400);
    final distance = _positiveNum(json['distance'], max: 1000);
    return SharedExercise(
      exerciseId: id,
      name: name,
      muscleGroup: muscle.isEmpty ? null : muscle,
      sets: (_positiveInt(json['sets'], max: 30) ?? 3).clamp(1, 30),
      reps: (_positiveInt(json['reps'], max: 999) ?? 10).clamp(1, 999),
      durationSeconds: duration,
      distance: distance,
    );
  }

  static int? _positiveInt(Object? value, {required int max}) {
    if (value is! num) return null;
    final n = value.toInt();
    if (n < 1) return null;
    return n > max ? max : n;
  }

  static double? _positiveNum(Object? value, {required num max}) {
    if (value is! num) return null;
    final n = value.toDouble();
    if (n < 0) return null;
    return n > max ? max.toDouble() : n;
  }
}

/// Sealed decode outcome so the UI can distinguish "malformed" from
/// "made by a newer app version" (→ "update the app" message).
sealed class RoutineShareDecodeResult {
  const RoutineShareDecodeResult();
}

class RoutineShareDecoded extends RoutineShareDecodeResult {
  const RoutineShareDecoded(this.payload);
  final RoutineSharePayload payload;
}

class RoutineShareUnsupportedVersion extends RoutineShareDecodeResult {
  const RoutineShareUnsupportedVersion();
}

class RoutineShareMalformed extends RoutineShareDecodeResult {
  const RoutineShareMalformed();
}
