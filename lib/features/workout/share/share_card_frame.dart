import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// Shared chrome every share-card template wraps its body in: a fixed 9:16
/// dark canvas with rounded corners and a branding footer (app name on the
/// left, the user's name + rank badge on the right).
///
/// Colours are committed to the dark palette (not `AppColors.of(context)`) so
/// the exported PNG looks identical regardless of the viewer's theme.
class ShareCardFrame extends ConsumerWidget {
  const ShareCardFrame({
    required this.child,
    this.padding,
    this.header,
    this.showFooter = true,
    super.key,
  });

  final Widget child;
  final EdgeInsets? padding;

  /// Optional in-card chrome rendered ABOVE [child] (e.g. an identity header).
  /// The Weekly Progress card uses this with [showFooter] `false`.
  final Widget? header;

  /// Whether to paint the branding footer below [child]. Off for cards that
  /// carry their own header instead.
  final bool showFooter;

  // Fixed dark-look constants (mirror AppColorsTheme.dark).
  static const _bgTop = Color(0xFF000000);
  static const _bgBottom = Color(0xFF0E0E10);
  static const _accent = Color(0xFFF0FF00);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF999999);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rank = ref.watch(myRankProvider);
    final name = ref.watch(userProfileProvider).valueOrNull?.displayName;
    final displayName =
        (name == null || name.trim().isEmpty) ? l10n.shareAnonymous : name;
    // Transparent ("sticker") mode drops the dark canvas so the exported PNG
    // has real alpha; the content (anatomy, text, logo) stays.
    final transparent = ref.watch(shareCardTransparentProvider);

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: transparent
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_bgTop, _bgBottom],
                  ),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[
                  header!,
                  const SizedBox(height: 16),
                ],
                Expanded(child: child),
                if (showFooter) ...[
                  const SizedBox(height: 16),
                  _Footer(
                    brand: l10n.appName,
                    displayName: displayName,
                    rank: rank,
                    l10n: l10n,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.brand,
    required this.displayName,
    required this.rank,
    required this.l10n,
  });

  final String brand;
  final String displayName;
  final Rank? rank;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.fitness_center_rounded,
          size: 20,
          color: ShareCardFrame._accent,
        ),
        const SizedBox(width: 6),
        Text(
          brand,
          style: const TextStyle(
            color: ShareCardFrame._textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: ShareCardFrame._textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (rank != null) ...[
          const SizedBox(width: 8),
          RankBadge(rank!, size: 34),
        ],
      ],
    );
  }
}
