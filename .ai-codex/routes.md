# Routes — my_gym_bro

**Router file:** `lib/core/router/app_router.dart`
**Provider:** `routerProvider` (GoRouter, initialLocation: `/splash`)

## AppRoutes Constants → Screen

### Onboarding flow (ordered)
| Constant | Path | Screen | File |
|---|---|---|---|
| `AppRoutes.splash` | `/splash` | `SplashScreen` | `features/onboarding/screens/splash_screen.dart` |
| `AppRoutes.onboardingWelcome` | `/onboarding/welcome` | `WelcomeScreen` | `features/onboarding/screens/welcome_screen.dart` |
| `AppRoutes.onboardingGender` | `/onboarding/gender` | `GenderScreen` | `features/onboarding/screens/gender_screen.dart` |
| `AppRoutes.onboardingGoal` | `/onboarding/goal` | `GoalScreen` | `features/onboarding/screens/goal_screen.dart` |
| `AppRoutes.onboardingExperience` | `/onboarding/experience` | `ExperienceScreen` | `features/onboarding/screens/experience_screen.dart` |
| `AppRoutes.onboardingBirthday` | `/onboarding/birthday` | `BirthdayScreen` | `features/onboarding/screens/birthday_screen.dart` |
| `AppRoutes.onboardingWeight` | `/onboarding/weight` | `WeightScreen` | `features/onboarding/screens/weight_screen.dart` |
| `AppRoutes.onboardingHeight` | `/onboarding/height` | `HeightScreen` | `features/onboarding/screens/height_screen.dart` |
| `AppRoutes.onboardingTargetZones` | `/onboarding/target-zones` | `TargetZonesScreen` | `features/onboarding/screens/target_zones_screen.dart` |
| `AppRoutes.onboardingLanguage` | `/onboarding/language` | `LanguageScreen` | `features/onboarding/screens/language_screen.dart` |
| `AppRoutes.onboardingSignup` | `/onboarding/signup` | `SignUpScreen` | `features/onboarding/screens/sign_up_screen.dart` |
| `AppRoutes.onboardingTrial` | `/onboarding/trial` | `TrialScreen` | `features/onboarding/screens/trial_screen.dart` |

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
| `AppRoutes.paywall` | `/paywall` | Inline scaffold (placeholder) | |

### Direct Messaging
| Constant | Path | Screen / Widget | Notes |
|---|---|---|---|
| `AppRoutes.dmInbox` | `/dm` | `DmInboxScreen` | |
| `AppRoutes.dmChat` | `/dm/:conversationId` | `DmChatScreen` | `extra: DmConversation` |

## Navigation pattern
```dart
context.go(AppRoutes.home);
context.push(AppRoutes.activeSession, extra: scheduleDayId);
context.push(AppRoutes.dmChat, extra: conversation);
```
