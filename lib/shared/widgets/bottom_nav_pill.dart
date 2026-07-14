import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';

/// Navigation index provider — shared across bottom nav and scaffold.
final navIndexProvider = StateProvider<int>((ref) => 0);

// ─────────────────────────────────────────────────────────────────────────────
// Platform-adaptive Bottom Nav
//   • iOS  → CNTabBar (native iOS 26 Liquid Glass)  — see IosNativeNav
//   • Other → frosted pill matching the Figma spec:
//       pill      = #000000 @60% + background blur + #383838 hairline (0.5)
//       highlight = #4E4E4E @25% + #C1C1C1 hairline (0.5), slides between tabs
//       icons     = #C1C1C1, white when active   (light mode: dark icons)
// ─────────────────────────────────────────────────────────────────────────────

class BottomNavPill extends ConsumerStatefulWidget {
  const BottomNavPill({super.key});

  @override
  ConsumerState<BottomNavPill> createState() => _BottomNavPillState();
}

class _BottomNavPillState extends ConsumerState<BottomNavPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late Animation<double> _slideAnim;
  int _prevIndex = 0;

  /// Horizontal left-offset for each tab's active highlight.
  List<double> get _offsets => [1.0.w, 92.0.w, 181.0.w];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = AlwaysStoppedAnimation(_offsets[0]);
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _animateTo(int newIndex) {
    if (newIndex == _prevIndex) return;
    _slideAnim = Tween<double>(
      begin: _offsets[_prevIndex],
      end: _offsets[newIndex],
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl
      ..reset()
      ..forward();
    _prevIndex = newIndex;
  }

  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(navIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    if (idx != _prevIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateTo(idx));
    }

    final pillW = AppSizes.navPillWidth.w;
    final pillH = AppSizes.navPillHeight.h;
    final indicatorW = AppSizes.navActiveW.w;
    final indicatorH = AppSizes.navActiveH.h;
    final indicatorTop = (pillH - indicatorH) / 2;

    // ── Figma colours (dark) + light-mode analogues ──
    final pillFill = isDark
        ? Colors.black.withValues(alpha: 0.50) // #000000 @ 50%
        : Colors.white.withValues(alpha: 0.50); // #FFFFFF @ 50%
    final pillStroke = isDark
        ? const Color(0xFF555555) // #555555
        : const Color(0xFFC1C1C1); // #C1C1C1
    final highlightFill = isDark
        ? const Color(0xFFC1C1C1).withValues(alpha: 0.15) // #C1C1C1 @ 15%
        : Colors.black.withValues(alpha: 0.15); // #000000 @ 15%

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 7.h,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: pillW,
          height: pillH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Frosted pill shell (Figma: #000000 60% + background blur) ──
              GlassSurface(
                width: pillW,
                height: pillH,
                radius: pillH / 2, // fully rounded (Figma corner radius 33.5)
                blurSigma:
                    2.5, // ≈ Figma background blur 5 (Flutter sigma runs heavier)
                tint: pillFill,
                borderColor: pillStroke,
                borderWidth: 0.5,
                child: const SizedBox.expand(),
              ),

              // ── Active highlight — neutral #4E4E4E @25%, slides between tabs ──
              AnimatedBuilder(
                animation: _slideCtrl,
                builder: (_, __) {
                  return Positioned(
                    left: _slideAnim.value,
                    top: indicatorTop,
                    child: Container(
                      width: indicatorW,
                      height: indicatorH,
                      decoration: BoxDecoration(
                        color: highlightFill,
                        borderRadius: BorderRadius.circular(indicatorH / 2),
                        // No stroke on the selected-tab drop (per spec).
                      ),
                    ),
                  );
                },
              ),

              // ── Tab icons ──
              Positioned.fill(
                child: Row(
                  children: [
                    _NavTab(
                      index: 0,
                      icon: Icons.home_rounded,
                      size: 34.sp,
                      label: l10n.tabHome,
                    ),
                    _NavTab(
                      index: 1,
                      icon: Icons.fitness_center_rounded,
                      size: 34.sp,
                      label: l10n.tabWorkout,
                    ),
                    _NavTab(
                      index: 2,
                      icon: Icons.people_rounded,
                      size: 38.sp,
                      label: l10n.tabCommunity,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Tab Item  (Android / non-iOS only)
// ─────────────────────────────────────────────────────────────────────────────

class _NavTab extends ConsumerWidget {
  const _NavTab({
    required this.index,
    required this.icon,
    required this.size,
    required this.label,
  });

  final int index;
  final IconData icon;
  final double size;

  /// Screen-reader label for this tab (the icon is otherwise unlabeled).
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = ref.watch(navIndexProvider) == index;

    // Neutral per the Figma: grey icons, white (dark) / near-black (light) when
    // active. No accent colour in the nav.
    final Color color;
    if (isDark) {
      color = isActive
          ? Colors.white.withValues(alpha: 0.90) // #FFFFFF @ 90%
          : const Color(0xFFC1C1C1).withValues(alpha: 0.90); // #C1C1C1 @ 90%
    } else {
      color = isActive
          ? Colors.black.withValues(alpha: 0.90) // #000000 @ 90%
          : const Color(0xFF666666).withValues(alpha: 0.90); // #666666 @ 90%
    }

    return Expanded(
      // Icon-only tab: give screen readers a name + tab semantics. The icon
      // itself carries no semantics, so there's no double announcement.
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(navIndexProvider.notifier).state = index,
          child: SizedBox(
            height: AppSizes.navPillHeight.h,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey('$index-$isActive'),
                  size: size,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
