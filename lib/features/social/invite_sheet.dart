import 'package:flutter/material.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Base of the invite deep link; the claimed @username is appended.
///
/// TODO(deploy): the universal-link domain (AASA / assetlinks) and the web
/// fallback page (App Store link for non-users) are not configured yet — see
/// SETUP-STATUS.md. The in-app `/bro/:username` route already handles the
/// link once the platform config lands.
const String kInviteLinkBase = 'https://mygymbro.app/bro/';

/// Invite a bro: QR code (scanned with the other phone's camera — no in-app
/// scanner needed) + share_plus for the link (PRD §5.6 — invite link/QR is
/// the primary discovery path).
void showInviteSheet(BuildContext context, {required String username}) {
  final colors = AppColors.of(context);
  final link = '$kInviteLinkBase$username';
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.panelBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.inviteSheetTitle,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '@$username',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16.h),
              // QR codes want a light background to stay scannable in dark
              // mode, so the tile is always white with black modules.
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: QrImageView(
                  data: link,
                  size: 200.w,
                  backgroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                l10n.inviteQrHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.todayPillText,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: l10n.inviteMessage(username, link),
                    ),
                  ),
                  icon: Icon(Icons.ios_share_rounded, size: 18.sp),
                  label: Text(
                    l10n.inviteShareAction,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
