import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_service.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Share a program (or, with [scheduleDayId], a single day) as a link:
/// QR code + copy + share_plus — same visual language as the Bros invite
/// sheet. The sheet owns the async create flow: it opens instantly with a
/// spinner, then swaps to the link or an inline error with Retry. Nothing
/// blocks the underlying screen.
void showRoutineShareSheet(
  BuildContext context, {
  required int scheduleId,
  required String title,
  int? scheduleDayId,
}) {
  final colors = AppColors.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.panelBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (ctx) => _RoutineShareSheet(
      scheduleId: scheduleId,
      scheduleDayId: scheduleDayId,
      title: title,
    ),
  );
}

class _RoutineShareSheet extends ConsumerStatefulWidget {
  const _RoutineShareSheet({
    required this.scheduleId,
    required this.title,
    this.scheduleDayId,
  });

  final int scheduleId;
  final int? scheduleDayId;
  final String title;

  @override
  ConsumerState<_RoutineShareSheet> createState() => _RoutineShareSheetState();
}

class _RoutineShareSheetState extends ConsumerState<_RoutineShareSheet> {
  ShareCreateResult? _result; // null while the link is being created

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    setState(() => _result = null);
    final service = ref.read(routineShareServiceProvider);
    final dayId = widget.scheduleDayId;
    final result = dayId != null
        ? await service.shareDay(dayId, fallbackTitle: widget.title)
        : await service.shareSchedule(
            widget.scheduleId,
            fallbackTitle: widget.title,
          );
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.shareRoutineSheetTitle,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),
            ...switch (_result) {
              null => _creating(colors, l10n),
              ShareCreated(:final link) => _created(colors, l10n, link),
              ShareEmpty() => _error(colors, l10n, l10n.shareRoutineEmpty,
                  retry: false),
              ShareSignedOut() => _error(
                  colors, l10n, l10n.shareRoutineSignedOut, retry: false),
              ShareUnavailable() =>
                _error(colors, l10n, l10n.shareRoutineOffline, retry: true),
              ShareFailed() =>
                _error(colors, l10n, l10n.shareRoutineFailed, retry: true),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _creating(AppColorsTheme colors, AppLocalizations l10n) => [
        SizedBox(
          height: 120.h,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28.w,
                  height: 28.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: colors.accent,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  l10n.shareRoutineCreating,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];

  List<Widget> _created(
    AppColorsTheme colors,
    AppLocalizations l10n,
    String link,
  ) =>
      [
        // QR codes want a light background to stay scannable in dark mode,
        // so the tile is always white with black modules.
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
          l10n.shareRoutineQrHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              side: BorderSide(color: colors.textSecondary.withValues(alpha: .4)),
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.shareRoutineCopied)),
              );
            },
            icon: Icon(Icons.link_rounded, size: 18.sp),
            label: Text(
              l10n.shareRoutineCopy,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SizedBox(height: 8.h),
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
            onPressed: () {
              // iPad needs a popover anchor (share_plus requirement).
              final box = context.findRenderObject() as RenderBox?;
              SharePlus.instance.share(
                ShareParams(
                  text: l10n.shareRoutineMessage(widget.title, link),
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                ),
              );
            },
            icon: Icon(Icons.ios_share_rounded, size: 18.sp),
            label: Text(
              l10n.shareRoutineAction,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ];

  List<Widget> _error(
    AppColorsTheme colors,
    AppLocalizations l10n,
    String message, {
    required bool retry,
  }) =>
      [
        SizedBox(height: 8.h),
        Icon(
          Icons.cloud_off_rounded,
          size: 32.sp,
          color: colors.textSecondary,
        ),
        SizedBox(height: 12.h),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
        ),
        if (retry) ...[
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.todayPillText,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              onPressed: _create,
              child: Text(
                l10n.shareRoutineRetry,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ] else
          SizedBox(height: 8.h),
      ];
}
