# lib/ Directory Map — my_gym_bro

```
lib/
├── main.dart                         # App entry: init DB, Supabase, Firebase, seed exercises, ProviderScope
├── app.dart                          # MaterialApp.router wired to routerProvider + theme
│
├── core/
│   ├── auth/
│   │   └── auth_notifier.dart        # AuthNotifier, AppAuthState, AuthStatus enum
│   ├── database/
│   │   ├── app_database.dart         # Drift DB definition (all Tables), AppDatabase class, schemaVersion=4
│   │   ├── app_database.g.dart       # Generated Drift code (don't edit)
│   │   └── daos/ ...                 # Data Access Objects (Exercise, Schedule, Session, Sync, User, DM)
│   ├── providers/
│   │   └── providers.dart            # Global providers: database, locale, themeMode, supabase, auth, etc.
│   ├── router/
│   │   └── app_router.dart          # GoRouter config with native slide animations
│   ├── security/ ...                 # InputSanitiser, SafeLogger, SecureStorage
│   └── services/ ...                 # ExerciseLocalService (remaps), SyncService, NotificationService
│
├── features/
│   ├── auth/ ...                     # SignIn / Auth flow
│   ├── community/
│   │   ├── community_screen.dart     # Main feed with glass composer
│   │   └── dm/                       # Direct Messaging Feature
│   │       ├── dm_chat_screen.dart   # Real-time chat (text/image/schedule)
│   │       ├── dm_inbox_screen.dart  # Inbox with conversations
│   │       ├── dm_repository.dart    # Supabase Realtime + Drift sync
│   │       └── widgets/ ...          # DmBubble, ScheduleShareSheet, DmConversationTile
│   ├── exercises/ ...                # Exercise Browser & Detail
│   ├── home/ ...                     # Home dashboard
│   ├── onboarding/ ...               # 12-screen welcome flow
│   ├── scaffold/
│   │   └── my_gym_bro_scaffold.dart  # Shell with floating BottomNavPill
│   ├── schedule/ ...                 # Schedule Builder logic
│   ├── settings/
│   │   └── settings_screen.dart      # Account, Theme, Gender toggles, Units
│   └── workout/ ...                  # Muscle map, Session tracking, Recovery Service
│
├── shared/
│   ├── constants.dart               # AppColors (Adaptive), AppRadius, AppSizes
│   ├── responsive.dart              # Adaptive Layout helpers
│   └── widgets/                     # Core UI elements
│       ├── anatomy_body.dart        # Core muscle map renderer
│       ├── bottom_nav_pill.dart     # oc_liquid_glass based navigation
│       ├── liquid_glass_button.dart # Glass icon buttons
│       └── glass_card.dart          # Frosted glass containers
└── l10n/                            # Multi-language ARB (en, de, es, fr, ar)
```
