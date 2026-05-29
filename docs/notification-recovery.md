# Active-session notification: force-kill recovery

## The gap

The persistent "MyGymBro Session" notification is owned by the Flutter
isolate that started it. When Android (or rarely iOS) **force-kills the
app** under memory pressure or because the user swipes it from Recents,
two things happen:

1. The isolate dies. `RestTimerService.activeInstance` is `null` and our
   `_handleAction` top-level function can't dispatch +15s/Skip/Complete.
2. The notification stays on the lock screen because it was marked
   `ongoing`, but its action buttons no longer do anything.

So the user sees a notification that *looks* alive but is actually a
ghost. Tapping the body still works (deep-link via `_kActionOpenSession`
re-opens the app, the active session is restored from Drift), but the
inline actions silently fail.

## What "real fixes" look like

There are three escalating options. We have not implemented any of them
yet — this doc is the spec for whoever picks it up.

### Option A — Cancel-on-kill (lazy, ~30 min)

When the app comes back to life, immediately cancel any stale active-
workout notification and re-issue a fresh one with the current state.

Implementation: in `active_session_notifier.dart`, on the first state
read after restoration (e.g. from `tryRestoreRestTimer` or from the
workout-screen `initState`), call:

```dart
await NotificationService.cancelActiveWorkout();
if (state.sessionId != null) {
  // Re-fire the right notification for current state.
  if (state.showRestTimer) {
    _updateRestTimerNotification(restTimerService.remaining);
  } else {
    _updateActiveSetNotification();
  }
}
```

Pros: no native code. Cons: between the kill and the next app open the
notification still looks alive but its buttons do nothing.

### Option B — Foreground service (Android-only, ~half day)

Promote the active-workout notification to an **Android Foreground
Service** so the OS can't kill the process while a workout is live.

Implementation:
- Add the `flutter_foreground_task` package.
- Wrap `startSession` / `finishSession` / `discardSession` in
  `FlutterForegroundTask.startService(...)` / `stopService(...)` calls.
- Move the rest-timer ticking *into* the foreground task callback so it
  survives the Flutter isolate dying.
- Update `AndroidManifest.xml` with the
  `android.permission.FOREGROUND_SERVICE` and
  `android.permission.FOREGROUND_SERVICE_HEALTH` permissions (the latter
  required on Android 14+).

Pros: notification stays alive and accurate forever. Buttons work even
after force-kill. Cons: native dependency, more battery scrutiny on
the Play Store listing, additional permission disclosure required.

### Option C — Backend-driven (iOS only, ~1 day + APNs setup)

For iOS, the Live Activity already does most of this work (its widget
extension lives in a separate process). The remaining gap is that
ActivityKit by default is *local-only* — when our app is killed it
can't push updates anymore.

The fix is **push-driven Live Activity updates**: register the activity
with a push token, store the token on Supabase, and when the Flutter
side is dead, a Supabase edge function (Cron job that fires every
~30 s during an active workout) sends silent push updates to ActivityKit
via APNs.

Pros: zero local battery cost. Cons: requires Apple Developer account,
APNs key, and a Cron/edge-function loop.

## Recommendation

- **Ship v1 with Option A** (lazy resync). It's cheap and covers the
  90% case where the user reopens the app within minutes.
- **Plan B for v1.1** (Android foreground service). Lifters often go
  the entire session without touching the phone — A is too leaky for
  the steady-state use case.
- **Defer Option C** until post-launch metrics show real iOS users
  hitting force-kill mid-session. Almost no one will. ActivityKit on
  device is already robust to backgrounding; force-kill is rare on iOS.
