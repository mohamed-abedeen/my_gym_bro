# Web Preview Bootstrap Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the Flutter web app complete bootstrap while preserving the existing RevenueCat key selection on native platforms.

**Architecture:** Extract RevenueCat key selection into a pure helper that receives `isWeb`, `TargetPlatform`, and both configured keys. `main.dart` supplies Flutter's web/platform constants and skips RevenueCat when the helper returns an empty key.

**Tech Stack:** Dart, Flutter foundation APIs, `flutter_test`, RevenueCat Flutter SDK

---

## File structure

- Create `lib/core/services/revenuecat_platform_key.dart`: pure platform-to-key selection with no `dart:io` dependency.
- Create `test/revenuecat_platform_key_test.dart`: focused regression tests for web, iOS, and Android selection.
- Modify `lib/main.dart`: replace the direct `Platform.isIOS` access with the tested helper.

### Task 1: RevenueCat platform key selection

**Files:**
- Create: `test/revenuecat_platform_key_test.dart`
- Create: `lib/core/services/revenuecat_platform_key.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/services/revenuecat_platform_key.dart';

void main() {
  group('selectRevenueCatKey', () {
    test('returns no native key on web', () {
      expect(
        selectRevenueCatKey(
          isWeb: true,
          platform: TargetPlatform.iOS,
          iosKey: 'apple-key',
          androidKey: 'google-key',
        ),
        isEmpty,
      );
    });

    test('returns the Apple key on native iOS', () {
      expect(
        selectRevenueCatKey(
          isWeb: false,
          platform: TargetPlatform.iOS,
          iosKey: 'apple-key',
          androidKey: 'google-key',
        ),
        'apple-key',
      );
    });

    test('returns the Google key on native Android', () {
      expect(
        selectRevenueCatKey(
          isWeb: false,
          platform: TargetPlatform.android,
          iosKey: 'apple-key',
          androidKey: 'google-key',
        ),
        'google-key',
      );
    });
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run: `puro -e stable2 flutter test test/revenuecat_platform_key_test.dart`

Expected: compilation fails because `revenuecat_platform_key.dart` and `selectRevenueCatKey` do not exist.

- [ ] **Step 3: Add the minimal pure helper**

```dart
import 'package:flutter/foundation.dart';

String selectRevenueCatKey({
  required bool isWeb,
  required TargetPlatform platform,
  required String iosKey,
  required String androidKey,
}) {
  if (isWeb) return '';
  return platform == TargetPlatform.iOS ? iosKey : androidKey;
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `puro -e stable2 flutter test test/revenuecat_platform_key_test.dart`

Expected: all 3 tests pass.

- [ ] **Step 5: Commit the helper and regression test**

```powershell
git add -- lib/core/services/revenuecat_platform_key.dart test/revenuecat_platform_key_test.dart
git commit -m "test: cover RevenueCat platform key selection"
```

### Task 2: Use web-safe key selection during bootstrap

**Files:**
- Modify: `lib/main.dart:1-25`
- Modify: `lib/main.dart:114-127`

- [ ] **Step 1: Replace the native platform read**

Remove `import 'dart:io';`, import the helper, and replace the RevenueCat key block with:

```dart
final rcKey = selectRevenueCatKey(
  isWeb: kIsWeb,
  platform: defaultTargetPlatform,
  iosKey: const String.fromEnvironment('REVENUECAT_IOS_KEY'),
  androidKey: const String.fromEnvironment('REVENUECAT_ANDROID_KEY'),
);
```

Keep the existing `rcKey.isNotEmpty`, placeholder-key guard, `Purchases.configure`, logging, and exception handling unchanged.

- [ ] **Step 2: Format and run focused tests**

Run: `puro -e stable2 dart format lib/main.dart lib/core/services/revenuecat_platform_key.dart test/revenuecat_platform_key_test.dart`

Run: `puro -e stable2 flutter test test/revenuecat_platform_key_test.dart`

Expected: formatting succeeds and all 3 focused tests pass.

- [ ] **Step 3: Run regression verification**

Run: `puro -e stable2 flutter test`

Expected: the full suite passes with only the repository's intentional skipped test.

Run: `puro -e stable2 flutter analyze --no-fatal-infos`

Expected: exit code 0; existing deprecation info messages may remain.

- [ ] **Step 4: Build and verify the browser flow**

Run: `puro -e stable2 flutter build web --debug --no-pub`

Expected: web build succeeds.

Serve `build/web`, reload `http://127.0.0.1:52346/`, and inspect browser logs.

Expected: bootstrap proceeds beyond Firebase initialization without `Platform._operatingSystem`, and the UI navigates beyond the static splash screen.

- [ ] **Step 5: Commit the bootstrap integration**

```powershell
git add -- lib/main.dart
git commit -m "fix: skip native RevenueCat bootstrap on web"
```

- [ ] **Step 6: Push the updated feature branch**

Run: `git push origin codex/current-split-overview`

Expected: pull request #17 includes both web-preview commits.
