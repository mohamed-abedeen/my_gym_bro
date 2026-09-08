import 'package:my_gym_bro/core/services/units.dart';

// Pure, widget-free helpers behind the exercise detail screen — kept out of
// the widget file so they can be unit tested without a Flutter binding.

/// `barbell bench press` → `Barbell Bench Press`. Catalogue names are stored
/// lowercase; the display title capitalises each word.
String titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Drops the `Step:N ` prefix the catalogue leaves on every instruction.
String stripStepPrefix(String instruction) =>
    instruction.replaceFirst(RegExp(r'^Step:\s*\d+\s*'), '');

/// Which bars the volume chart draws in full accent: every session that beat
/// all earlier sessions in the window (a running PR), plus the latest one.
/// Everything else is drawn muted.
List<bool> highlightedBars(List<double> volumes) {
  final out = List<bool>.filled(volumes.length, false);
  var best = double.negativeInfinity;
  for (var i = 0; i < volumes.length; i++) {
    if (volumes[i] > best) {
      out[i] = true;
      best = volumes[i];
    }
  }
  if (out.isNotEmpty) out[out.length - 1] = true;
  return out;
}

/// Index of the bar that carries the `PR` tag — the window's highest volume
/// (the first one on ties), or -1 when there is nothing to tag.
int prBarIndex(List<double> volumes) {
  var index = -1;
  var best = double.negativeInfinity;
  for (var i = 0; i < volumes.length; i++) {
    if (volumes[i] > best) {
      best = volumes[i];
      index = i;
    }
  }
  return index;
}

/// The best-session tile's headline number: tonnes with one decimal once the
/// volume reaches 1000 kg (`4.2` + `t`), plain kg below that. In lbs the same
/// threshold switches to thousands (`9.3` + `k lbs`).
({String value, String unit}) compactVolume(double kg, WeightUnit unit) {
  final v = convertFromKg(kg, unit);
  if (v < 1000) {
    return (
      value: formatWeight(kg, unit, decimals: 0),
      unit: weightUnitLabel(unit),
    );
  }
  return (
    value: (v / 1000).toStringAsFixed(1),
    unit: unit == WeightUnit.kg ? 't' : 'k ${weightUnitLabel(unit)}',
  );
}

/// Y-axis tick label in display units: `4.2k`, `2k`, `800`, `0`.
String axisLabel(double kg, WeightUnit unit) {
  final v = convertFromKg(kg, unit);
  if (v < 1000) return v.round().toString();
  final s = (v / 1000).toStringAsFixed(1);
  return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}k';
}

/// The months spanned by [dates] (oldest → newest, one entry per distinct
/// month), thinned to at most [maxTicks] evenly spaced entries — always
/// keeping the first and last — so the x-axis never crowds.
List<DateTime> monthTicks(List<DateTime> dates, {int maxTicks = 6}) {
  final months = <DateTime>[];
  for (final d in dates) {
    final m = DateTime(d.year, d.month);
    if (months.isEmpty || months.last != m) months.add(m);
  }
  if (months.length <= maxTicks) return months;
  if (maxTicks <= 1) return [months.first];
  return [
    for (var i = 0; i < maxTicks; i++)
      months[(i * (months.length - 1) / (maxTicks - 1)).round()],
  ];
}
