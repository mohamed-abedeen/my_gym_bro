import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

/// Navigation index provider — shared across bottom nav and scaffold.
final navIndexProvider = StateProvider<int>((ref) => 0);

// ─────────────────────────────────────────────────────────────────────────────
// Platform-adaptive Bottom Nav
//   • iOS  → CNTabBar (native iOS 26 Liquid Glass via cupertino_native)
//   • Other → OCLiquidGlass floating pill
// ─────────────────────────────────────────────────────────────────────────────

class BottomNavPill extends ConsumerStatefulWidget {
  const BottomNavPill({super.key});

  @override
  ConsumerState<BottomNavPill> createState() => _BottomNavPillState();
}

class _BottomNavPillState extends ConsumerState<BottomNavPill>
    with SingleTickerProviderStateMixin {
  // ── Android / non-iOS animation state ──
  late final AnimationController _slideCtrl;
  late Animation<double> _slideAnim;
  int _prevIndex = 0;

  /// Horizontal left-offset for each tab's active indicator.
  List<double> get _offsets => [1.0.w, 92.0.w, 181.0.w];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutQuart));

    _slideCtrl
      ..reset()
      ..forward();

    _prevIndex = newIndex;
  }

  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(navIndexProvider);

    // ── OCLiquidGlass floating pill ──
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final colors = AppColors.of(context);

    if (idx != _prevIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateTo(idx));
    }

    final pillW = AppSizes.navPillWidth.w;
    final pillH = AppSizes.navPillHeight.h;
    final pillR = AppRadius.navPill.r;
    final indicatorW = AppSizes.navActiveW.w;
    final indicatorH = AppSizes.navActiveH.h;
    final indicatorTop = (pillH - indicatorH) / 2;

    final glassSettings = OCLiquidGlassSettings(
      blendPx: 3,
      refractStrength: isDark ? 0.01 : 0.1,
      distortFalloffPx: 13,
      blurRadiusPx: isDark ? 4 : 5.5,
      specAngle: 0.1,
      specStrength: isDark ? -1 : -1.0,
      specPower: 1,
      specWidth: 1.7,
      lightbandOffsetPx: 3,
      lightbandWidthPx: 3.5,
      lightbandStrength: isDark ? 0.6 : 0.4,
      lightbandColor:
          isDark ? const Color.fromARGB(255, 255, 255, 255) : AppColors.of(context).white,
    );

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 7.h,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: pillW,
          height: pillH,
          child: OCLiquidGlassGroup(
            settings: glassSettings,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Glass pill shell ──
                OCLiquidGlass(
                  width: pillW,
                  height: pillH,
                  borderRadius: pillR,
                  color:
                      isDark
                          ? AppColors.of(context).white.withValues(alpha: 0.06)
                          : AppColors.of(context).black.withValues(alpha: 0.04),
                  shadow: BoxShadow(
                    color: AppColors.of(context).black.withValues(alpha: isDark ? 0.30 : 0.15),
                    blurRadius: 28.w,
                    offset: Offset(0, 10.h),
                  ),
                  child: const SizedBox.expand(),
                ),

                // ── Liquid active indicator ──
                AnimatedBuilder(
                  animation: _slideCtrl,
                  builder: (_, __) {
                    return Positioned(
                      left: _slideAnim.value,
                      top: indicatorTop,
                      child: OCLiquidGlass(
                        width: indicatorW,
                        height: indicatorH,
                        borderRadius: indicatorH / 2,
                        color: colors.accent.withValues(
                          alpha: isDark ? 0.10 : 0.08,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),

                // ── Tab icons ──
                Positioned.fill(
                  child: Row(
                    children: [
                      _NavTab(index: 0, icon: Icons.home_rounded, size: 34.sp),
                      _NavTab(
                        index: 1,
                        icon: Icons.fitness_center_rounded,
                        size: 34.sp,
                      ),
                      _NavTab(
                        index: 2,
                        icon: Icons.people_rounded,
                        size: 38.sp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  const _NavTab({required this.index, required this.icon, required this.size});

  final int index;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isActive = ref.watch(navIndexProvider) == index;

    return Expanded(
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
                color: isActive ? colors.accent : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
