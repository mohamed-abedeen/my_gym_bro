import 'package:flutter/material.dart';
import 'package:my_gym_bro/features/workout/active_session/rest_timer_service.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

class RestTimerWidget extends StatefulWidget {

  const RestTimerWidget({
    required this.timerService,
    required this.visible,
    required this.onDismiss,
    super.key,
  });
  final RestTimerService timerService;
  final bool visible;
  final VoidCallback onDismiss;

  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: widget.visible ? 80.h : 0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _completed ? colors.accent : colors.card,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: widget.visible
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _completed
                  ? Center(
                      child: Text(
                        l10n.restComplete,
                        style: TextStyle(
                          color:
                              _completed ? AppColors.of(context).black : colors.textPrimary,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : StreamBuilder<int>(
                      stream: widget.timerService.stream,
                      initialData: widget.timerService.remaining,
                      builder: (context, snapshot) {
                        final remaining = snapshot.data ?? 0;
                        final progress = widget.timerService.progress;

                        Color countdownColor;
                        if (remaining <= 3) {
                          countdownColor = colors.danger;
                        } else if (remaining <= 10) {
                          countdownColor = colors.accent;
                        } else {
                          countdownColor = colors.textPrimary;
                        }

                        final minutes = remaining ~/ 60;
                        final seconds = remaining % 60;
                        final timeStr =
                            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

                        return Row(
                          children: [
                            // Countdown text
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                color: countdownColor,
                                fontSize: 36.sp,
                                fontWeight: FontWeight.w700,
                              ),
                              child: Text(timeStr),
                            ),
                            SizedBox(width: 12.w),
                            // Circular progress
                            SizedBox(
                              width: 40.w,
                              height: 40.w,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3.w,
                                backgroundColor:
                                    colors.textSecondary.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.accent),
                              ),
                            ),
                            const Spacer(),
                            // Control buttons
                            Row(
                              children: [
                                LiquidGlassButton(
                                  width: 52.w,
                                  height: 36.h,
                                  opacity: 0.15,
                                  radius: 12.r,
                                  onTap: () =>
                                      widget.timerService.addTime(-15),
                                  child: Text(
                                    l10n.subtractSeconds(15),
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                LiquidGlassButton(
                                  width: 52.w,
                                  height: 36.h,
                                  opacity: 0.15,
                                  radius: 12.r,
                                  onTap: () =>
                                      widget.timerService.addTime(30),
                                  child: Text(
                                    l10n.addSeconds(30),
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                LiquidGlassButton(
                                  width: 52.w,
                                  height: 36.h,
                                  opacity: 0.15,
                                  radius: 12.r,
                                  onTap: () {
                                    widget.timerService.cancel();
                                    widget.onDismiss();
                                  },
                                  child: Text(
                                    l10n.skipRest,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            )
          : const SizedBox.shrink(),
    );
  }

  void showCompleted() {
    setState(() => _completed = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _completed = false);
        widget.onDismiss();
      }
    });
  }
}
