import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
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
      builder: (context, child) =>
          ConnectivityBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
