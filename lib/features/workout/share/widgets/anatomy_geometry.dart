import 'dart:ui';

/// Where each muscle group's highlight sits on the 900×1140 anatomy sheet
/// (2026-08 art set: back view left half, front view right half), as
/// fractions of the sheet.
///
/// `front` / `back` are the centroid of the LEFT UNIT of the highlight in
/// that view (the left pec / left delt / left glute…) — the natural point
/// for a callout to target; `null` when that view shows under 3% of the
/// group's pixels. `frontShare` is the fraction of the group's highlight
/// pixels that are in the front view — it drives which figure(s) the
/// Anatomy share card shows.
///
/// GENERATED DATA — measured by rasterising the muscle SVGs
/// (`assets/anatomy/*_<base>.svg`) on their shared canvas and scanning
/// pixels. If the SVG set or artwork changes, re-measure rather than
/// hand-tuning:
///
///   flutter test test/measure_muscle_bounds_test.dart --run-skipped
typedef MuscleGeometry = ({Offset? front, Offset? back, double frontShare});

const muscleGeometryMale = <String, MuscleGeometry>{
  'Chest': (front: Offset(0.6940, 0.2206), back: null, frontShare: 1.000),
  'Lats': (front: Offset(0.6219, 0.2838), back: Offset(0.2185, 0.3196), frontShare: 0.081),
  'Upper Back': (front: null, back: Offset(0.2421, 0.2354), frontShare: 0.000),
  'Lower Back': (front: null, back: Offset(0.2314, 0.4053), frontShare: 0.000),
  'Traps': (front: Offset(0.6638, 0.1495), back: Offset(0.2437, 0.1534), frontShare: 0.184),
  'Shoulders': (front: Offset(0.5997, 0.2064), back: Offset(0.1532, 0.1994), frontShare: 0.602),
  'Front Delt': (front: Offset(0.6203, 0.2012), back: null, frontShare: 1.000),
  'Side Delt': (front: Offset(0.5736, 0.2186), back: null, frontShare: 1.000),
  'Rear Delt': (front: null, back: Offset(0.1532, 0.1994), frontShare: 0.000),
  'Biceps': (front: Offset(0.5817, 0.2829), back: Offset(0.3945, 0.3098), frontShare: 0.928),
  'Triceps': (front: Offset(0.5324, 0.2757), back: Offset(0.1360, 0.2723), frontShare: 0.129),
  'Forearms': (front: Offset(0.5403, 0.3675), back: Offset(0.0845, 0.3872), frontShare: 0.543),
  'Quads': (front: Offset(0.6834, 0.5619), back: Offset(0.1275, 0.5792), frontShare: 0.916),
  'Hamstrings': (front: null, back: Offset(0.1766, 0.6091), frontShare: 0.000),
  'Glutes': (front: Offset(0.6510, 0.4502), back: Offset(0.2104, 0.4737), frontShare: 0.124),
  'Calves': (front: Offset(0.6115, 0.7794), back: Offset(0.1694, 0.7935), frontShare: 0.239),
  'Core': (front: Offset(0.6878, 0.3394), back: Offset(0.1790, 0.3764), frontShare: 0.879),
  'Neck': (front: Offset(0.7105, 0.1426), back: Offset(0.2355, 0.1326), frontShare: 0.848),
};

const muscleGeometryFemale = <String, MuscleGeometry>{
  'Chest': (front: Offset(0.7077, 0.2360), back: null, frontShare: 1.000),
  'Lats': (front: Offset(0.6484, 0.2683), back: Offset(0.2131, 0.3095), frontShare: 0.039),
  'Upper Back': (front: null, back: Offset(0.2366, 0.2282), frontShare: 0.000),
  'Lower Back': (front: null, back: Offset(0.2530, 0.3790), frontShare: 0.000),
  'Traps': (front: Offset(0.6882, 0.1603), back: Offset(0.2392, 0.1505), frontShare: 0.160),
  'Shoulders': (front: Offset(0.6255, 0.2051), back: Offset(0.1525, 0.1968), frontShare: 0.553),
  'Front Delt': (front: Offset(0.6366, 0.2070), back: null, frontShare: 1.000),
  'Side Delt': (front: Offset(0.6027, 0.2110), back: null, frontShare: 1.000),
  'Rear Delt': (front: null, back: Offset(0.1525, 0.1968), frontShare: 0.000),
  'Biceps': (front: Offset(0.6036, 0.2843), back: null, frontShare: 1.000),
  'Triceps': (front: Offset(0.9238, 0.2547), back: Offset(0.1361, 0.2734), frontShare: 0.074),
  'Forearms': (front: Offset(0.5665, 0.3874), back: Offset(0.0821, 0.3892), frontShare: 0.479),
  'Quads': (front: Offset(0.6805, 0.5694), back: Offset(0.1206, 0.5719), frontShare: 0.906),
  'Hamstrings': (front: null, back: Offset(0.1755, 0.6093), frontShare: 0.000),
  'Glutes': (front: Offset(0.6598, 0.4604), back: Offset(0.1986, 0.4722), frontShare: 0.107),
  'Calves': (front: Offset(0.5965, 0.8133), back: Offset(0.1700, 0.7784), frontShare: 0.346),
  'Core': (front: Offset(0.7172, 0.3613), back: Offset(0.1820, 0.3725), frontShare: 0.854),
  'Neck': (front: Offset(0.7249, 0.1523), back: null, frontShare: 1.000),
};
