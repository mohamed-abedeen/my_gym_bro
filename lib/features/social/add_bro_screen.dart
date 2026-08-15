import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/social/friend_providers.dart';
import 'package:my_gym_bro/features/social/friend_repository.dart';
import 'package:my_gym_bro/features/social/public_profile.dart';
import 'package:my_gym_bro/features/social/report_sheet.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/confirm_sheet.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Landing screen for an invite deep link (`/bro/:username`) and the QR code.
/// Looks up the exact @handle and offers the relationship-aware action —
/// add / accept / pending / bros — plus block & report (store rule: available
/// from every surface a stranger can reach).
class AddBroScreen extends ConsumerStatefulWidget {
  const AddBroScreen({required this.username, super.key});

  final String username;

  @override
  ConsumerState<AddBroScreen> createState() => _AddBroScreenState();
}

class _AddBroScreenState extends ConsumerState<AddBroScreen> {
  late Future<UsernameLookupResult> _lookup;

  @override
  void initState() {
    super.initState();
    _lookup =
        ref.read(friendRepositoryProvider).lookupByUsername(widget.username);
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: FutureBuilder<UsernameLookupResult>(
                  future: _lookup,
                  builder: (context, snap) {
                    final result = snap.data;
                    if (result == null) {
                      return CircularProgressIndicator(color: colors.accent);
                    }
                    return switch (result) {
                      UsernameLookupOffline() => _Message(
                          l10n.searchNeedsOnline),
                      UsernameNotFound() => _Message(l10n.searchNoMatch),
                      UsernameFound(:final profile) =>
                        _ProfileCard(profile: profile),
                    };
                  },
                ),
              ),
            ),
          ),

          // ── Back button (48pt header spec) ──
          Positioned(
            left: 12.w,
            top: MediaQuery.of(context).padding.top + 8.h,
            child: LiquidGlassButton(
              width: AppSizes.headerActionBtn.w,
              height: AppSizes.headerActionBtn.w,
              opacity: 0.15,
              radius: (AppSizes.headerActionBtn / 2).r,
              onTap: () => Navigator.of(context).pop(),
              child: Icon(
                Icons.chevron_left_rounded,
                color: colors.textPrimary,
                size: AppSizes.headerActionIcon.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.of(context).textSecondary,
        fontSize: 14.sp,
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(relationshipProvider(profile.userId));
    final name = profile.displayName ?? profile.username ?? '';

    return GlassSurface(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36.r,
            backgroundColor: colors.avatarPlaceholder,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          SizedBox(height: 12.h),
          Text(
            name,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (profile.username != null)
            Text(
              '@${profile.username!}',
              style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
            ),
          SizedBox(height: 6.h),
          Text(
            '${profile.friendCount} ${l10n.statBros}',
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
          ),
          SizedBox(height: 20.h),
          _ActionButton(profile: profile, state: state),
          if (state != Relationship.self) ...[
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () => _safetyMenu(context, ref),
              child: Text(
                '${l10n.blockAction} · ${l10n.reportAction}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _safetyMenu(BuildContext context, WidgetRef ref) async {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            ListTile(
              title: Text(l10n.blockAction,
                  style: TextStyle(color: colors.danger, fontSize: 14.sp)),
              onTap: () => Navigator.of(ctx).pop('block'),
            ),
            ListTile(
              title: Text(l10n.reportAction,
                  style: TextStyle(color: colors.danger, fontSize: 14.sp)),
              onTap: () => Navigator.of(ctx).pop('report'),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'block') {
      final ok = await showConfirmSheet(
        context,
        tier: ConfirmTier.destructive,
        title: l10n.blockConfirmTitle,
        body: l10n.blockConfirmBody,
        confirmLabel: l10n.blockAction,
      );
      if (ok) await ref.read(friendRepositoryProvider).block(profile.userId);
    } else if (action == 'report') {
      await showReportSheet(context, ref, reportedUserId: profile.userId);
    }
  }
}

class _ActionButton extends ConsumerWidget {
  const _ActionButton({required this.profile, required this.state});

  final PublicProfile profile;
  final Relationship state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    final (label, enabled) = switch (state) {
      Relationship.self => ('', false),
      Relationship.friends => (l10n.statBros, false),
      Relationship.pendingOut => (l10n.pendingLabel, false),
      Relationship.pendingIn => (l10n.acceptAction, true),
      Relationship.blocked => (l10n.blockedTitle, false),
      Relationship.none => (l10n.addBroAction, true),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor:
              enabled ? colors.accent : colors.accent.withValues(alpha: 0.25),
          foregroundColor: colors.todayPillText,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        onPressed: !enabled
            ? null
            : () async {
                final outcome = await ref
                    .read(friendRepositoryProvider)
                    .sendRequest(profile.userId);
                if (!context.mounted) return;
                final message = switch (outcome) {
                  SendRequestResult.sent => l10n.requestSentToast,
                  SendRequestResult.accepted => l10n.nowBrosToast,
                  SendRequestResult.notSignedIn => l10n.signInToAddBros,
                  SendRequestResult.unavailable => l10n.requestFailedToast,
                };
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              },
        child: Text(
          label,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
