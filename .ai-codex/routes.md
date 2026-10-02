# Routes — my_gym_bro

**Router file:** `lib/core/router/app_router.dart`
**Provider:** `routerProvider` (GoRouter, initialLocation: `/splash`)

## AppRoutes Constants → Screen

### Onboarding flow (ordered)
| Constant | Path | Screen | File |
|---|---|---|---|
| `AppRoutes.splash` | `/splash` | `SplashScreen` | `features/onboarding/screens/splash_screen.dart` |
| `AppRoutes.onboarding` | `/onboarding` | `OnboardingFlowScreen` — welcome, all questionnaire steps, timelines and the paywall in one screen (steps in `features/onboarding/steps/`) | `features/onboarding/onboarding_flow_screen.dart` |
| `AppRoutes.onboardingSignup` | `/onboarding/signup` | `SignUpScreen` (after the paywall) | `features/onboarding/screens/sign_up_screen.dart` |

### Auth
| Constant | Path | Screen | File |
|---|---|---|---|
| `AppRoutes.signIn` | `/auth/signin` | `SignInScreen` | `features/auth/sign_in_screen.dart` |

### Main app
| Constant | Path | Screen / Widget | Notes |
|---|---|---|---|
| `AppRoutes.home` | `/` | `MyGymBroScaffold` | Shell with bottom nav |
| `AppRoutes.settings` | `/settings` | `SettingsScreen` | |
| `AppRoutes.exerciseBrowser` | `/exercises` | `ExerciseBrowserScreen` | |
| `AppRoutes.activeSession` | `/session` | `ActiveSessionScreen` | `extra: int? scheduleDayId` |
| `AppRoutes.scheduleBuilder` | `/schedule/build` | `ScheduleBuilderScreen` | `extra: int? scheduleId` |
| `AppRoutes.paywall` | `/paywall` | `PaywallScreen` (wraps `PaywallView`, shared with the onboarding flow) | Trial-expiry gate + voluntary open |

## Navigation pattern
```dart
context.go(AppRoutes.home);
context.push(AppRoutes.activeSession, extra: scheduleDayId);
```
