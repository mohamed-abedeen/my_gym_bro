import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/features/social/friend_providers.dart';
import 'package:my_gym_bro/features/social/friend_repository.dart';
import 'package:my_gym_bro/features/social/invite_sheet.dart';
import 'package:my_gym_bro/features/social/public_profile.dart';
import 'package:my_gym_bro/features/social/report_sheet.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/confirm_sheet.dart';

/// The Bros sheet — friends graph hub (Bros Phase B, PRD §5.6): claim your
/// @handle, invite via QR/link, add by exact @handle, requests inbox
/// (accept / decline), bros list, blocked list. Frosted styling matches the
/// house sheet pattern (panel background, rounded top).
void showBrosSheet(BuildContext context) {
  final colors = AppColors.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.panelBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (ctx) => const _BrosSheet(),
  );
}

class _BrosSheet extends ConsumerStatefulWidget {
  const _BrosSheet();

  @override
  ConsumerState<_BrosSheet> createState() => _BrosSheetState();
}

class _BrosSheetState extends ConsumerState<_BrosSheet> {
  final _searchCtrl = TextEditingController();
  UsernameLookupResult? _searchResult;
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    final result =
        await ref.read(friendRepositoryProvider).lookupByUsername(query);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(currentUserIdProvider);

    // Pull the latest graph once per sheet open (push queued ops first).
    ref.watch(friendGraphRefreshProvider);

    final incoming = ref.watch(incomingRequestsProvider);
    final outgoing = ref.watch(outgoingRequestsProvider);
    final friendIds = ref.watch(friendIdsProvider);
    final edges =
        ref.watch(friendshipEdgesProvider).valueOrNull ?? const <Friendship>[];
    final blocked = [
      for (final e in edges)
        if (e.status == 'blocked' && e.blockedBy == uid) e,
    ];

    return SafeArea(
      child: uid == null
          ? Padding(
              padding: EdgeInsets.all(32.w),
              child: Text(
                l10n.signInToAddBros,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              children: [
                // ── Header: title + invite ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.addBros,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _invite(context),
                      icon: Icon(Icons.qr_code_rounded,
                          size: 18.sp, color: colors.accent),
                      label: Text(
                        l10n.inviteAction,
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),

                // ── My handle: claimed → display; unclaimed → claim flow ──
                const _UsernameSection(),
                SizedBox(height: 16.h),

                // ── Add by @handle (exact match — the only search, §5.6) ──
                _SectionTitle(l10n.searchByUsername),
                SizedBox(height: 8.h),
                TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _search(),
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  style:
                      TextStyle(color: colors.textPrimary, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: l10n.searchByUsernameHint,
                    hintStyle: TextStyle(
                        color: colors.textSecondary, fontSize: 14.sp),
                    filled: true,
                    fillColor: colors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searching
                        ? Padding(
                            padding: EdgeInsets.all(12.w),
                            child: SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: colors.accent),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.search_rounded,
                                color: colors.textSecondary),
                            onPressed: _search,
                          ),
                  ),
                ),
                if (_searchResult != null) ...[
                  SizedBox(height: 8.h),
                  _SearchResultRow(result: _searchResult!),
                ],

                // ── Requests inbox ──
                if (incoming.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  _SectionTitle(l10n.requestsTitle),
                  for (final edge in incoming)
                    _UserRow(
                      userId: edge.requesterId,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SmallAction(
                            label: l10n.acceptAction,
                            color: colors.accent,
                            onTap: () =>
                                ref.read(friendRepositoryProvider).accept(edge),
                          ),
                          SizedBox(width: 8.w),
                          _SmallAction(
                            label: l10n.declineAction,
                            color: colors.textSecondary,
                            onTap: () => ref
                                .read(friendRepositoryProvider)
                                .removeEdge(edge),
                          ),
                        ],
                      ),
                      onLongPress: () =>
                          _strangerMenu(context, edge.requesterId),
                    ),
                ],

                // ── Sent requests ──
                if (outgoing.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  _SectionTitle(l10n.sentRequestsTitle),
                  for (final edge in outgoing)
                    _UserRow(
                      userId: edge.addresseeId,
                      trailing: _SmallAction(
                        label: l10n.cancelRequestAction,
                        color: colors.textSecondary,
                        onTap: () =>
                            ref.read(friendRepositoryProvider).removeEdge(edge),
                      ),
                    ),
                ],

                // ── My bros ──
                SizedBox(height: 20.h),
                _SectionTitle(l10n.myBrosTitle),
                if (friendIds.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      l10n.noBrosYet,
                      style: TextStyle(
                          color: colors.textSecondary, fontSize: 13.sp),
                    ),
                  )
                else
                  for (final id in friendIds)
                    _UserRow(
                      userId: id,
                      trailing: IconButton(
                        icon: Icon(Icons.more_horiz_rounded,
                            color: colors.textSecondary, size: 20.sp),
                        onPressed: () => _broMenu(context, id),
                      ),
                    ),

                // ── Blocked (only pairs I blocked; theirs stay invisible) ──
                if (blocked.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  _SectionTitle(l10n.blockedTitle),
                  for (final edge in blocked)
                    _UserRow(
                      userId: edge.requesterId == uid
                          ? edge.addresseeId
                          : edge.requesterId,
                      trailing: _SmallAction(
                        label: l10n.unblockAction,
                        color: colors.textSecondary,
                        onTap: () =>
                            ref.read(friendRepositoryProvider).removeEdge(edge),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  void _invite(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final username = ref.read(userProfileProvider).valueOrNull?.username;
    if (username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.inviteNeedsUsername)),
      );
      return;
    }
    showInviteSheet(context, username: username);
  }

  /// Long-press menu for a requester the user doesn't know: block / report.
  Future<void> _strangerMenu(BuildContext context, String userId) async {
    final l10n = AppLocalizations.of(context);
    final action = await _pickAction(
      context,
      [(_MenuAction.block, l10n.blockAction), (_MenuAction.report, l10n.reportAction)],
    );
    if (!context.mounted) return;
    await _runAction(context, action, userId);
  }

  /// Trailing menu for an accepted bro: remove / block / report.
  Future<void> _broMenu(BuildContext context, String userId) async {
    final l10n = AppLocalizations.of(context);
    final action = await _pickAction(
      context,
      [
        (_MenuAction.remove, l10n.removeBroAction),
        (_MenuAction.block, l10n.blockAction),
        (_MenuAction.report, l10n.reportAction),
      ],
    );
    if (!context.mounted) return;
    await _runAction(context, action, userId);
  }

  Future<_MenuAction?> _pickAction(
    BuildContext context,
    List<(_MenuAction, String)> actions,
  ) {
    final colors = AppColors.of(context);
    return showModalBottomSheet<_MenuAction>(
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
            for (final (action, label) in actions)
              ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    color: action == _MenuAction.report ||
                            action == _MenuAction.block
                        ? colors.danger
                        : colors.textPrimary,
                    fontSize: 14.sp,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(action),
              ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    _MenuAction? action,
    String userId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(friendRepositoryProvider);
    switch (action) {
      case null:
        return;
      case _MenuAction.remove:
        final ok = await showConfirmSheet(
          context,
          tier: ConfirmTier.destructive,
          title: l10n.removeBroConfirmTitle,
          body: l10n.removeBroConfirmBody,
          confirmLabel: l10n.removeBroAction,
        );
        if (!ok) return;
        final uid = repo.currentUserId;
        if (uid == null) return;
        final edge = await ref.read(friendshipDaoProvider).findPair(uid, userId);
        if (edge != null) await repo.removeEdge(edge);
      case _MenuAction.block:
        final ok = await showConfirmSheet(
          context,
          tier: ConfirmTier.destructive,
          title: l10n.blockConfirmTitle,
          body: l10n.blockConfirmBody,
          confirmLabel: l10n.blockAction,
        );
        if (!ok) return;
        await repo.block(userId);
      case _MenuAction.report:
        if (!context.mounted) return;
        await showReportSheet(context, ref, reportedUserId: userId);
    }
  }
}

enum _MenuAction { remove, block, report }

// ─────────────────────────────────────────────
// U S E R N A M E   S E C T I O N
// ─────────────────────────────────────────────

class _UsernameSection extends ConsumerStatefulWidget {
  const _UsernameSection();

  @override
  ConsumerState<_UsernameSection> createState() => _UsernameSectionState();
}

class _UsernameSectionState extends ConsumerState<_UsernameSection> {
  final _ctrl = TextEditingController();
  ClaimUsernameResult? _lastResult;
  bool _claiming = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    setState(() {
      _claiming = true;
      _lastResult = null;
    });
    final result =
        await ref.read(friendRepositoryProvider).claimUsername(_ctrl.text);
    if (!mounted) return;
    setState(() {
      _claiming = false;
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final username = ref.watch(userProfileProvider).valueOrNull?.username;

    if (username != null) {
      return Row(
        children: [
          Icon(Icons.alternate_email_rounded,
              size: 16.sp, color: colors.accent),
          SizedBox(width: 6.w),
          Text(
            username,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final error = switch (_lastResult) {
      ClaimUsernameResult.taken => l10n.usernameTaken,
      ClaimUsernameResult.invalid => l10n.usernameInvalid,
      ClaimUsernameResult.offline => l10n.usernameNeedsOnline,
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.claimUsernameTitle),
        SizedBox(height: 4.h),
        Text(
          l10n.claimUsernameExplainer,
          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                autocorrect: false,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
                decoration: InputDecoration(
                  prefixText: '@',
                  prefixStyle:
                      TextStyle(color: colors.accent, fontSize: 14.sp),
                  hintText: l10n.claimUsernameHint,
                  hintStyle: TextStyle(
                      color: colors.textSecondary, fontSize: 14.sp),
                  filled: true,
                  fillColor: colors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                  errorText: error,
                  errorStyle:
                      TextStyle(color: colors.danger, fontSize: 11.sp),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            _SmallAction(
              label: l10n.claimAction,
              color: colors.accent,
              busy: _claiming,
              onTap: _claim,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// S H A R E D   R O W S
// ─────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.of(context).textSecondary,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// One row of the graph lists: avatar + display name + @handle, resolved from
/// the server-side public profile (offline → a neutral placeholder).
class _UserRow extends ConsumerWidget {
  const _UserRow({
    required this.userId,
    required this.trailing,
    this.onLongPress,
  });

  final String userId;
  final Widget trailing;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final profile = ref.watch(publicProfileProvider(userId)).valueOrNull;
    final name = profile?.displayName ?? profile?.username ?? '…';

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: colors.avatarPlaceholder,
              backgroundImage: (profile?.avatarUrl != null)
                  ? NetworkImage(profile!.avatarUrl!)
                  : null,
              child: profile?.avatarUrl == null
                  ? Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (profile?.username != null)
                    Text(
                      '@${profile!.username!}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Search hit row — relationship-aware action button + block/report on
/// long-press (store rule: reachable from every surface a stranger can reach).
class _SearchResultRow extends ConsumerWidget {
  const _SearchResultRow({required this.result});

  final UsernameLookupResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    switch (result) {
      case UsernameLookupOffline():
        return Text(
          l10n.searchNeedsOnline,
          style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
        );
      case UsernameNotFound():
        return Text(
          l10n.searchNoMatch,
          style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
        );
      case UsernameFound(:final profile):
        final state = ref.watch(relationshipProvider(profile.userId));
        final sheetState =
            context.findAncestorStateOfType<_BrosSheetState>()!;
        final trailing = switch (state) {
          Relationship.self => const SizedBox.shrink(),
          Relationship.friends => Text(
              l10n.statBros,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          Relationship.pendingOut => Text(
              l10n.pendingLabel,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          _ => _SmallAction(
              label: state == Relationship.pendingIn
                  ? l10n.acceptAction
                  : l10n.addBroAction,
              color: colors.accent,
              onTap: () async {
                final repo = ref.read(friendRepositoryProvider);
                final outcome = await repo.sendRequest(profile.userId);
                if (!context.mounted) return;
                final message = switch (outcome) {
                  SendRequestResult.sent => l10n.requestSentToast,
                  SendRequestResult.accepted => l10n.nowBrosToast,
                  _ => l10n.requestFailedToast,
                };
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              },
            ),
        };
        return _UserRow(
          userId: profile.userId,
          trailing: trailing,
          onLongPress: () => sheetState._strangerMenu(context, profile.userId),
        );
    }
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: busy
            ? SizedBox(
                width: 14.w,
                height: 14.w,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
