import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/security/safe_logger.dart';

/// Routes incoming `https://mygymbro.app/...` links into the app.
///
/// This service is the ONLY consumer of universal links: Flutter's built-in
/// deep linking is explicitly disabled on both platforms (it now defaults to
/// ON when the flag is absent, which would double-handle links and shove the
/// `io.supabase.mygymbro://login-callback` OAuth URI into GoRouter). The
/// OAuth callback keeps flowing through supabase_flutter's own app_links
/// listener — everything that isn't our https host is ignored here.
///
/// Share links land on `/s/<code>` immediately when the main app is on
/// screen; otherwise the code is stashed and replayed by
/// `MyGymBroScaffold` once the user reaches the main app (fresh install →
/// onboarding → import, or signed-out → sign-in → import).
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  static final _shareCodeRx = RegExp(r'^[a-z0-9]{4,16}$');

  // App-lifetime singleton — the subscription lives until process death.
  // ignore: cancel_subscriptions
  StreamSubscription<Uri>? _sub;
  String? _pendingShareCode;

  /// Idempotent. Fire-and-forget from bootstrap — never blocks startup.
  Future<void> initialise() async {
    if (_sub != null) return;
    try {
      // uriLinkStream also replays the cold-start link on first listen.
      _sub = AppLinks().uriLinkStream.listen(
            handleUri,
            onError: (Object _) {},
          );
    } on Object catch (e) {
      SafeLogger.log(
        'deep link init failed: ${e.runtimeType}',
        tag: 'deeplink',
      );
    }
  }

  /// Public for tests.
  void handleUri(Uri uri) {
    if (uri.scheme != 'https' || uri.host != 'mygymbro.app') return;
    final segments = uri.pathSegments;
    if (segments.length < 2) return;
    switch (segments[0]) {
      case 's':
        final code = segments[1].toLowerCase();
        if (_shareCodeRx.hasMatch(code)) _openShare(code);
      case 'bro':
        // Same link family as the Bros invite QR — forward to its route.
        if (segments[1].isNotEmpty) globalRouter?.push('/bro/${segments[1]}');
    }
  }

  void _openShare(String code) {
    final router = globalRouter;
    if (router == null) {
      _pendingShareCode = code;
      return;
    }
    // During splash/onboarding/auth a push would be wiped by the flow's own
    // `context.go(...)` — stash instead; the scaffold replays it.
    final loc = router.routerDelegate.currentConfiguration.uri.path;
    final preMainApp = loc == '/splash' ||
        loc.startsWith('/onboarding') ||
        loc.startsWith('/auth');
    if (preMainApp) {
      _pendingShareCode = code;
    } else {
      router.push('/s/$code');
    }
  }

  /// One-shot: returns the stashed code and clears it.
  String? consumePendingShareCode() {
    final code = _pendingShareCode;
    _pendingShareCode = null;
    return code;
  }

  /// For flows that must defer an import (e.g. the import screen sending a
  /// signed-out user to sign-in first).
  static void stashCode(String code) => instance._pendingShareCode = code;
}
