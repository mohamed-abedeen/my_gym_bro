import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/share_helpers.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart'
    show userProfileProvider;
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';

/// Progress template: an in-card identity header (avatar + name on the left,
/// the MGB logo on the right), a large worked-muscle anatomy hero, the workout
/// name centred below it, and a 2×2 grid of THIS SESSION's stats —
/// Duration | Volume over Avg Strength | Sets. Every value is for the workout
/// just finished (not weekly/lifetime aggregates).
class WeeklyProgressCard extends ConsumerWidget {
  const WeeklyProgressCard({required this.data, super.key});

  final ShareCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final name = profile?.displayName;
    final displayName =
        (name == null || name.trim().isEmpty) ? l10n.shareAnonymous : name;

    return ShareCardFrame(
      showFooter: false,
      header: Row(
        children: [
          UserAvatar(
            size: 40,
            url: profile?.avatarUrl,
            // Fixed dark placeholder so the captured PNG never depends on the
            // viewer's theme (UserAvatar's defaults read AppColors.of).
            placeholderColor: const Color(0xFF1C1C1E),
            iconColor: kShareTextSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kShareTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const _BrandChip(),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Center(
                child: ShareAnatomyHero(
                  groups: data.workedMuscleGroups,
                  height: c.maxHeight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ShareCardTitle(
            data.workoutName,
            size: 28,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          // 2×2 grid of THIS session's stats.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ShareStatTile(
                  value: formatShareDuration(data.durationSeconds),
                  label: l10n.totalDuration,
                  valueSize: 26,
                ),
              ),
              Expanded(
                child: ShareStatTile(
                  value: formatShareVolume(data.totalVolumeKg, unit),
                  label: l10n.volume,
                  valueColor: kShareAccent,
                  valueSize: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ShareStatTile(
                  value: '${data.avgStrength.round()}',
                  label: l10n.avgStrength,
                  valueSize: 26,
                ),
              ),
              Expanded(
                child: ShareStatTile(
                  value: '${data.totalSets}',
                  label: l10n.sets,
                  valueSize: 26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The MGB brand mark on the right of the header — the real logo icon, with a
/// text pill fallback if the asset isn't bundled.
class _BrandChip extends StatelessWidget {
  const _BrandChip();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/mgb_icon.png',
      height: 40,
      errorBuilder: (_, __, ___) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: kShareAccent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'MGB',
          style: TextStyle(
            color: Color(0xFF000000),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
