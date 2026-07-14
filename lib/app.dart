import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/widget_sync_service.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/connectivity_banner.dart';

/// Screen-to-screen motion, per platform. Routes use plain [MaterialPage] /
/// [MaterialPageRoute] so this theme is the single source of truth:
/// - iOS/macOS: native Cupertino slide + interactive swipe-back.
/// - Android: predictive-back (Android 14+ shared-element gesture); regular
///   pushes fall back to the M3 FadeForwards transition (~350ms fade-slide).
/// - Windows/Linux (dev): same FadeForwards look, no gesture.
const _pageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
  },
);

/// Root app widget.
class MyGymBroApp extends ConsumerWidget {
  const MyGymBroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'My Gym Bro',
      debugShowCheckedModeBanner: false,

      // Localisation
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,

      // Theme
      themeMode: themeMode,
      theme: ThemeData.light().copyWith(
        pageTransitionsTheme: _pageTransitionsTheme,
        scaffoldBackgroundColor: AppColorsTheme.light.background,
        colorScheme: ColorScheme.light(
          primary: AppColorsTheme.light.accent,
          surface: AppColorsTheme.light.card,
        ),
        extensions: const [AppColorsTheme.light],
      ),
      darkTheme: ThemeData.dark().copyWith(
        pageTransitionsTheme: _pageTransitionsTheme,
        scaffoldBackgroundColor: AppColorsTheme.dark.background,
        colorScheme: ColorScheme.dark(
          primary: AppColorsTheme.dark.accent,
          surface: AppColorsTheme.dark.card,
        ),
        extensions: const [AppColorsTheme.dark],
      ),

      // Router
      routerConfig: router,
      builder: (context, child) {
        // Clamp system text scaling to 0.8–1.3 app-wide: the fixed-size glass
        // chrome (54.h stats capsule, 46.h set rows, the nav pill's hardcoded
        // tab offsets) overflows past ~1.3, and scales below 0.8 make labels
        // unreadably small. Within the clamp everything still scales.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.3,
            ),
          ),
          child: _LocaleSyncBoundary(
            child: ConnectivityBanner(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

/// Re-pushes localized strings into pure-Dart services (no BuildContext)
/// whenever the active locale changes. didChangeDependencies fires on
/// locale change because AppLocalizations is an InheritedWidget.
class _LocaleSyncBoundary extends StatefulWidget {
  const _LocaleSyncBoundary({required this.child});
  final Widget child;

  @override
  State<_LocaleSyncBoundary> createState() => _LocaleSyncBoundaryState();
}

class _LocaleSyncBoundaryState extends State<_LocaleSyncBoundary> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    WidgetSyncService.setStreakLabels(
      start: l10n.widgetStreakStart,
      oneDay: l10n.widgetStreakOneDay,
      manyBuilder: l10n.widgetStreakDays,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
