import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/widget_sync_service.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/connectivity_banner.dart';

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
        scaffoldBackgroundColor: AppColorsTheme.light.background,
        colorScheme: ColorScheme.light(
          primary: AppColorsTheme.light.accent,
          surface: AppColorsTheme.light.card,
        ),
        extensions: const [AppColorsTheme.light],
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColorsTheme.dark.background,
        colorScheme: ColorScheme.dark(
          primary: AppColorsTheme.dark.accent,
          surface: AppColorsTheme.dark.card,
        ),
        extensions: const [AppColorsTheme.dark],
      ),

      // Router
      routerConfig: router,
      builder: (context, child) => _LocaleSyncBoundary(
        child: ConnectivityBanner(child: child ?? const SizedBox.shrink()),
      ),
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
