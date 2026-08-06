# Web Preview Bootstrap Fix

## Goal

Allow the existing Flutter web build to reach the application UI instead of stopping on the native platform check during bootstrap. Native iOS and Android behavior must remain unchanged.

## Cause

`main.dart` reads `Platform.isIOS` before `runApp()`. `dart:io` exposes that API to the web compiler, but evaluating it in a browser throws `Unsupported operation: Platform._operatingSystem`. The top-level guarded zone catches the error, so the browser remains on the static splash screen.

## Design

Introduce a small, pure platform-selection helper used by RevenueCat bootstrap configuration. The helper receives whether the runtime is web and the target platform, and returns no native RevenueCat key for web. For native targets it preserves the current mapping: Apple key for iOS and Google key for all other currently supported native targets.

`main.dart` will call the helper with `kIsWeb` and `defaultTargetPlatform`. RevenueCat configuration will run only when the returned key is non-empty. No routing, authentication, database, or current-split feature logic changes.

## Error handling

Web startup treats RevenueCat as unavailable, matching the existing behavior when an API key is empty. Existing best-effort subscription synchronization remains a no-op without RevenueCat configuration.

## Tests

A unit test will first reproduce the missing behavior by requiring the helper to:

- return no key for a web runtime;
- preserve the Apple key selection for iOS;
- preserve the Google key selection for Android.

After the unit test passes, the complete Flutter test suite and static analysis will run. A fresh web build will then be served locally and verified past the splash screen in the browser.

## Out of scope

- Repairing Puro's Flutter debug-server SDK path resolution.
- Adding browser support to native-only screens beyond the startup path.
- Changing subscription behavior on iOS or Android.
