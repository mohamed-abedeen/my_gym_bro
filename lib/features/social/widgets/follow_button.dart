import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/social/follow_providers.dart';
import 'package:my_gym_bro/features/social/public_profile.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Follow / Following / Friends toggle for a given user.
///
/// Watches the viewer's [Relationship] to [userId] and toggles follow state
/// optimistically (the repository writes locally and queues the sync). Renders
/// nothing for the viewer's own profile.
class FollowButton extends ConsumerWidget {
  const FollowButton({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final rel = ref.watch(relationshipProvider(userId)).valueOrNull;

    if (rel == null || rel == Relationship.self) {
      return const SizedBox.shrink();
    }

    final isFollowing =
        rel == Relationship.following || rel == Relationship.friends;
    final label = switch (rel) {
      Relationship.friends => l10n.friends,
      Relationship.following => l10n.following,
      _ => l10n.follow,
    };

    Future<void> toggle() async {
      final repo = ref.read(followRepositoryProvider);
      if (isFollowing) {
        await repo.unfollow(userId);
      } else {
        await repo.follow(userId);
      }
      ref.invalidate(relationshipProvider(userId));
    }

    return GestureDetector(
      onTap: toggle,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : colors.accent,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
            color: isFollowing ? colors.separator : colors.accent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: isFollowing ? colors.textPrimary : colors.black,
          ),
        ),
      ),
    );
  }
}
