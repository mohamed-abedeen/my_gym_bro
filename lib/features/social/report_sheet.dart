import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/social/friend_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Report a user (store safety requirement — reachable from every surface a
/// stranger can reach). Picks one of four canned reasons; the wire value is
/// the stable English key, not the localized label, so review stays readable.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String reportedUserId,
}) async {
  final colors = AppColors.of(context);
  final l10n = AppLocalizations.of(context);
  final reasons = <(String, String)>[
    ('spam', l10n.reportReasonSpam),
    ('harassment', l10n.reportReasonHarassment),
    ('impersonation', l10n.reportReasonImpersonation),
    ('other', l10n.reportReasonOther),
  ];

  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: colors.panelBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
            child: Text(
              l10n.reportSheetTitle,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final (key, label) in reasons)
            ListTile(
              title: Text(
                label,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
              ),
              onTap: () => Navigator.of(ctx).pop(key),
            ),
          SizedBox(height: 8.h),
        ],
      ),
    ),
  );
  if (reason == null) return;

  await ref
      .read(friendRepositoryProvider)
      .report(reportedUserId: reportedUserId, reason: reason);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.reportSentToast)));
  }
}
