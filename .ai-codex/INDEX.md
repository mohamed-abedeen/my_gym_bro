# my_gym_bro — AI Codex Index

> Paste the relevant section(s) into your AI prompt instead of sharing raw source files.
> Keeps context small and precise.

## Files in this codex

| File | What's inside | When to use |
|---|---|---|
| `routes.md` | All `AppRoutes` constants → screen mappings, GoRouter setup | Adding a new route, navigating somewhere, understanding flow |
| `pages.md` | Every screen: purpose, key providers consumed, bottom sheets | Adding features to a screen, understanding which providers a page uses |
| `lib.md` | Full `lib/` directory tree with one-line descriptions | Finding where a file lives, understanding architecture |
| `schema.md` | All Drift tables, columns, types, indexes, DAOs, migrations | DB queries, adding columns, writing DAOs |
| `providers.md` | All Riverpod providers with types + data models | Wiring state, watching providers, understanding models |
| `components.md` | Shared widgets API, `AppColors`/`AppRadius`/`AppSizes` tokens, packages | Building UI, using design tokens, checking what packages are available |

---

## Project at a glance

- **App:** Paid fitness tracker — local-first, Supabase sync, multi-language
- **Stack:** Flutter · Riverpod · Drift (SQLite) · Supabase · GoRouter · RevenueCat
- **Architecture:** Feature-folder + core layer; offline-first with sync queue
- **Theme:** Dark default (`AppColors.of(context)`), accent `#D2FF00`
- **Nav:** GoRouter with `AppRoutes` constants; bottom nav via `BottomNavPill`
- **DB:** 9 Drift tables, schemaVersion 3, 5 DAOs

## Architecture layers

```
features/          ← screens & local providers
core/              ← router, database, auth, services, global providers
shared/            ← design system, reusable widgets
```

## Conventions
- **Colors:** Always `AppColors.of(context).field`, never hardcoded hex in widgets
- **Routes:** Always `context.go(AppRoutes.constant)` or `context.push(...)`
- **DB companions:** Use `Value(x)` for set fields, omit unset optional fields
- **Providers:** Feature-scoped providers live in `*_providers.dart` next to the feature; global ones in `core/providers/providers.dart`
- **Code gen:** After changing Drift tables or Riverpod generators, run `dart run build_runner build --delete-conflicting-outputs`
