import 'package:flutter/material.dart';

/// Last-resort error UI: replaces Flutter's red/grey crash screen
/// (`ErrorWidget.builder`) and serves as the GoRouter unknown-route page.
///
/// Deliberately self-contained — no l10n, no theme, no glass widgets — because
/// in the ErrorWidget case the crashed subtree may be exactly what those
/// depend on. English-only by design: the localization layer itself may be
/// what failed.
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({super.key, this.onGoHome});

  /// Shown as a "Go home" action when navigation is still possible (router
  /// error page). Null in the ErrorWidget case, where the tree is broken.
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF101014),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fitness_center, color: Colors.white38, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please restart the app.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
              if (onGoHome != null) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: onGoHome,
                  child: const Text('Go home'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
