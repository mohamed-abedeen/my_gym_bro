import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/features/community/dm/dm_models.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

class DmBubble extends StatelessWidget {

  const DmBubble({required this.message, super.key, this.onSaveSchedule});
  final DmMessage message;
  final VoidCallback? onSaveSchedule;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isMine = message.isMine;

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 60.w : 12.w,
        right: isMine ? 12.w : 60.w,
        top: 2.h,
        bottom: 2.h,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: isMine ? colors.accent : colors.cardElevated,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                  bottomLeft: Radius.circular(isMine ? 20.r : 6.r),
                  bottomRight: Radius.circular(isMine ? 6.r : 20.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.of(context).black.withValues(alpha: 0.06),
                    blurRadius: 8.w,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                  bottomLeft: Radius.circular(isMine ? 20.r : 6.r),
                  bottomRight: Radius.circular(isMine ? 6.r : 20.r),
                ),
                child: _BubbleContent(
                  message: message,
                  onSaveSchedule: onSaveSchedule,
                ),
              ),
            ),
          ),

          // Optimistic indicator (pending → shows clock)
          if (isMine && message.isOptimistic) ...[
            SizedBox(width: 4.w),
            Icon(
              Icons.schedule_rounded,
              color: colors.textSecondary.withValues(alpha: 0.5),
              size: 12.sp,
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BUBBLE CONTENT — switches on message type
// ═══════════════════════════════════════════════════════════════════════════

class _BubbleContent extends StatelessWidget {

  const _BubbleContent({required this.message, this.onSaveSchedule});
  final DmMessage message;
  final VoidCallback? onSaveSchedule;

  @override
  Widget build(BuildContext context) {
    switch (message.messageType) {
      case DmMessageType.text:
        return _TextContent(message: message);
      case DmMessageType.image:
        return _ImageContent(message: message);
      case DmMessageType.schedule:
        return _ScheduleContent(
          message: message,
          onSave: onSaveSchedule,
        );
    }
  }
}

// ── Text ────────────────────────────────────────────────────────────────

class _TextContent extends StatelessWidget {
  const _TextContent({required this.message});
  final DmMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isMine = message.isMine;
    final textColor = isMine ? AppColors.of(context).black : colors.textPrimary;
    final timeColor = isMine
        ? AppColors.of(context).black.withValues(alpha: 0.5)
        : colors.textSecondary;

    final h = message.createdAt.hour.toString().padLeft(2, '0');
    final m = message.createdAt.minute.toString().padLeft(2, '0');

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.body ?? '',
            style: TextStyle(
              color: textColor,
              fontSize: 15.sp,
              height: 1.35,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '$h:$m',
            style: TextStyle(
              color: timeColor,
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image ───────────────────────────────────────────────────────────────

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.message});
  final DmMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (message.imageUrl == null) {
      // Optimistic placeholder — uploading
      return Container(
        width: 200.w,
        height: 150.h,
        color: colors.panelBackground,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24.w,
                height: 24.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  color: colors.accent,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                AppLocalizations.of(context).dmUploading,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: message.imageUrl!,
      width: 220.w,
      fit: BoxFit.cover,
      memCacheWidth: (220.w * dpr).toInt(),
      placeholder: (_, __) => Container(
        width: 220.w,
        height: 150.h,
        color: colors.panelBackground,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.w,
            color: colors.accent,
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        width: 220.w,
        height: 100.h,
        color: colors.panelBackground,
        child: Icon(
          Icons.broken_image_rounded,
          color: colors.textSecondary,
          size: 32.sp,
        ),
      ),
    );
  }
}

// ── Schedule Card ───────────────────────────────────────────────────────

class _ScheduleContent extends StatelessWidget {

  const _ScheduleContent({required this.message, this.onSave});
  final DmMessage message;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isMine = message.isMine;
    final shared = message.sharedSchedule;

    if (shared == null) {
      return Padding(
        padding: EdgeInsets.all(12.w),
        child: Text(
          AppLocalizations.of(context).dmInvalidSchedule,
          style: TextStyle(
            color: isMine ? AppColors.of(context).black.withValues(alpha: 0.54) : colors.textSecondary,
            fontSize: 13.sp,
          ),
        ),
      );
    }

    final primaryColor = isMine ? AppColors.of(context).black : colors.textPrimary;
    final secondaryColor =
        isMine ? AppColors.of(context).black.withValues(alpha: 0.6) : colors.textSecondary;
    final iconColor = isMine ? AppColors.of(context).black : colors.accent;

    return Padding(
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: iconColor,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).dmSharedSchedule,
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      shared.name,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          // Divider
          Container(
            height: 1,
            color: isMine
                ? AppColors.of(context).black.withValues(alpha: 0.1)
                : colors.separator.withValues(alpha: 0.5),
          ),

          SizedBox(height: 10.h),

          // Days
          ...shared.days.map((day) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Row(
                  children: [
                    Container(
                      width: 22.w,
                      height: 22.w,
                      decoration: BoxDecoration(
                        color: day.isRestDay
                            ? secondaryColor.withValues(alpha: 0.15)
                            : iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Center(
                        child: Text(
                          '${day.dayIndex + 1}',
                          style: TextStyle(
                            color: day.isRestDay ? secondaryColor : iconColor,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        day.isRestDay ? AppLocalizations.of(context).restDay : (day.label ?? AppLocalizations.of(context).dmWorkout),
                        style: TextStyle(
                          color: day.isRestDay ? secondaryColor : primaryColor,
                          fontSize: 13.sp,
                          fontWeight:
                              day.isRestDay ? FontWeight.w400 : FontWeight.w500,
                          fontStyle: day.isRestDay
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          // Save button (only for received schedules)
          if (!isMine && onSave != null) ...[
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              height: 38.h,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: AppColors.of(context).black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: Icon(Icons.download_rounded, size: 18.sp),
                label: Text(
                  AppLocalizations.of(context).dmSaveToMySchedules,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                  ),
                ),
                onPressed: onSave,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
