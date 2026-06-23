import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/bottom_nav_pill.dart';

/// iOS-only bottom tab bar backed by the real native UITabBar.
///
/// On iOS 26+ this renders Apple's actual Liquid Glass material (via
/// `cupertino_native_better`'s platform view); on iOS 13–25 the package falls
/// back to a native CupertinoTabBar. It is used ONLY on iOS — every other
/// platform keeps the custom frosted [BottomNavPill]. Tab state is driven by
/// the shared [navIndexProvider] so it stays in sync with the rest of the app.
///
/// Note: this is a native platform view, so it must be verified on a real Mac /
/// iOS 26 build — it can't be exercised from the Windows toolchain.
class IosNativeNav extends ConsumerWidget {
  const IosNativeNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(navIndexProvider);
    final colors = AppColors.of(context);

    return CNTabBar(
      currentIndex: idx,
      onTap: (i) => ref.read(navIndexProvider.notifier).state = i,
      // Colors the selected icon — keeps the app's lime accent on the bar.
      tint: colors.accent,
      // Icon-only (no labels) to match the app's existing nav design.
      items: const [
        CNTabBarItem(
          icon: CNSymbol('house'),
          activeIcon: CNSymbol('house.fill'),
        ),
        CNTabBarItem(
          icon: CNSymbol('dumbbell'),
          activeIcon: CNSymbol('dumbbell.fill'),
        ),
        CNTabBarItem(
          icon: CNSymbol('person.2'),
          activeIcon: CNSymbol('person.2.fill'),
        ),
      ],
    );
  }
}
