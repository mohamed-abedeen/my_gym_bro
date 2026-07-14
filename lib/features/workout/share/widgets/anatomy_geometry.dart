import 'dart:ui';

/// Where each muscle group's highlight sits on the 900×1140 anatomy sheet
/// (front view left half, back view right half), as fractions of the sheet.
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
  'Chest': (front: Offset(0.1794, 0.2235), back: null, frontShare: 1.000),
  'Lats': (front: Offset(0.1341, 0.2653), back: Offset(0.6901, 0.2677), frontShare: 0.053),
  'Upper Back': (front: Offset(0.1341, 0.2653), back: Offset(0.6901, 0.2677), frontShare: 0.053),
  'Lower Back': (front: null, back: Offset(0.7441, 0.3628), frontShare: 0.000),
  'Traps': (front: Offset(0.1856, 0.1548), back: Offset(0.7334, 0.1875), frontShare: 0.112),
  'Shoulders': (front: Offset(0.1063, 0.2009), back: Offset(0.6342, 0.1827), frontShare: 0.576),
  'Front Delt': (front: Offset(0.1155, 0.1980), back: null, frontShare: 1.000),
  'Side Delt': (front: Offset(0.0879, 0.2068), back: null, frontShare: 1.000),
  'Rear Delt': (front: null, back: Offset(0.6342, 0.1827), frontShare: 0.000),
  'Biceps': (front: Offset(0.0908, 0.2692), back: Offset(0.6288, 0.2830), frontShare: 0.913),
  'Triceps': (front: Offset(0.0540, 0.2559), back: Offset(0.5999, 0.2625), frontShare: 0.076),
  'Forearms': (front: Offset(0.0462, 0.3455), back: Offset(0.5680, 0.3613), frontShare: 0.508),
  'Quads': (front: Offset(0.1615, 0.5237), back: Offset(0.7279, 0.5724), frontShare: 0.950),
  'Hamstrings': (front: null, back: Offset(0.6866, 0.5560), frontShare: 0.000),
  'Glutes': (front: Offset(0.1439, 0.4252), back: Offset(0.6986, 0.4528), frontShare: 0.147),
  'Calves': (front: Offset(0.1280, 0.7323), back: Offset(0.6619, 0.7006), frontShare: 0.454),
  'Core': (front: Offset(0.2011, 0.3442), back: Offset(0.6841, 0.3559), frontShare: 0.915),
  'Neck': (front: Offset(0.2220, 0.1440), back: Offset(0.7329, 0.1040), frontShare: 0.773),
};

const muscleGeometryFemale = <String, MuscleGeometry>{
  'Chest': (front: Offset(0.1855, 0.2275), back: null, frontShare: 1.000),
  'Lats': (front: null, back: Offset(0.7105, 0.2619), frontShare: 0.000),
  'Upper Back': (front: null, back: Offset(0.7105, 0.2619), frontShare: 0.000),
  'Lower Back': (front: null, back: Offset(0.7510, 0.3566), frontShare: 0.000),
  'Traps': (front: Offset(0.1953, 0.1566), back: Offset(0.7471, 0.1904), frontShare: 0.094),
  'Shoulders': (front: Offset(0.1247, 0.1940), back: Offset(0.6554, 0.1904), frontShare: 0.512),
  'Front Delt': (front: Offset(0.1277, 0.1982), back: null, frontShare: 1.000),
  'Side Delt': (front: Offset(0.1203, 0.1876), back: null, frontShare: 1.000),
  'Rear Delt': (front: null, back: Offset(0.6554, 0.1904), frontShare: 0.000),
  'Biceps': (front: Offset(0.1194, 0.2680), back: null, frontShare: 1.000),
  'Triceps': (front: Offset(0.1134, 0.2986), back: Offset(0.6438, 0.2672), frontShare: 0.148),
  'Forearms': (front: Offset(0.0843, 0.3668), back: Offset(0.6127, 0.3656), frontShare: 0.486),
  'Quads': (front: Offset(0.1715, 0.5320), back: Offset(0.7323, 0.5313), frontShare: 0.819),
  'Hamstrings': (front: null, back: Offset(0.6908, 0.5862), frontShare: 0.000),
  'Glutes': (front: Offset(0.1493, 0.4718), back: Offset(0.6987, 0.4482), frontShare: 0.284),
  'Calves': (front: Offset(0.1715, 0.7667), back: Offset(0.6938, 0.7301), frontShare: 0.497),
  'Core': (front: Offset(0.2009, 0.3575), back: Offset(0.6977, 0.3565), frontShare: 0.872),
  'Neck': (front: Offset(0.2210, 0.1435), back: Offset(0.7473, 0.1116), frontShare: 0.754),
};
