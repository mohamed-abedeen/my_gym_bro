/// Gym-prevalence ranking for equipment filter chips.
///
/// Lower index = more common in a real gym.
/// Any value not listed here falls to the end, sorted alphabetically.
/// Update this list when new equipment types are added from an external API.
const _equipmentRank = <String>[
  'body weight',
  'dumbbell',
  'barbell',
  'cable',
  'leverage machine',
  'smith machine',
  'ez barbell',
  'olympic barbell',
  'resistance band',
  'band',
  'kettlebell',
  'weighted',
  'trap bar',
  'rope',
  'medicine ball',
  'stability ball',
  'stationary bike',
  'elliptical machine',
  'assisted',
  'hammer',
  'skierg machine',
  'sled machine',
  'stepmill machine',
  'bosu ball',
  'roller',
  'wheel roller',
  'upper body ergometer',
  'tire',
];

/// Sorts [equipment] by gym prevalence (most common first).
/// Items not in the ranking list are appended alphabetically at the end.
List<String> sortEquipment(List<String> equipment) {
  final ranked = <String>[];
  final unranked = <String>[];

  for (final item in equipment) {
    if (_equipmentRank.contains(item.toLowerCase())) {
      ranked.add(item);
    } else {
      unranked.add(item);
    }
  }

  ranked.sort((a, b) =>
      _equipmentRank.indexOf(a.toLowerCase())
          .compareTo(_equipmentRank.indexOf(b.toLowerCase())));
  unranked.sort();

  return [...ranked, ...unranked];
}
