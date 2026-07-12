import 'dart:async';

import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';

/// Drops a "NEW PR!" banner over the current screen: frosted glass, trophy,
/// slides in from the top, auto-dismisses. Fire-and-forget.
void showPrBanner(
  BuildContext context, {
  required String title,
  required String body,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) =>
        _PrBanner(title: title, body: body, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _PrBanner extends StatefulWidget {
  const _PrBanner({
    required this.title,
    required this.body,
    required this.onDone,
  });

  final String title;
  final String body;
  final VoidCallback onDone;

  @override
  State<_PrBanner> createState() => _PrBannerState();
}

class _PrBannerState extends State<_PrBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 250),
  );
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _hold = Timer(const Duration(milliseconds: 3000), _dismiss);
  }

  Future<void> _dismiss() async {
    _hold?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final slide = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8.h,
      left: 16.w,
      right: 16.w,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.4),
          end: Offset.zero,
        ).animate(slide),
        child: FadeTransition(
          opacity: _controller,
          // Overlay entries have no Material ancestor — without one, Text
          // renders in the yellow-underline fallback style.
          child: Material(
            type: MaterialType.transparency,
            child: GestureDetector(
              onTap: _dismiss,
              child: GlassSurface(
                radius: 22.r,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                shadow: BoxShadow(
                  color: colors.accent.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: colors.accent,
                      size: 34.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            widget.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
