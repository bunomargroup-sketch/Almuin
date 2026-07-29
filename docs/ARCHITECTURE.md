# Architecture

Almuin follows **Clean Architecture with a feature-first folder layout**,
Riverpod for state, SQLite as the offline source of truth, and Supabase as an
optional progressive layer.

## Layers

```
presentation (pages, widgets, providers)
      │  depends on ▼
domain (entities: Dhikr/Verse/DailyHadith, SmartScheduler, Recommender,
        repository contracts)  ← pure Dart, unit-tested, no Flutter imports
      ▲  implements
data   (DhikrRepositoryImpl → AppDatabase/SQLite, RemoteAiService → edge fn)

core/   cross-cutting: theme, router, settings, notifications, DB, sync, utils
```

## Key design decisions

### 1. Offline-first, always
- Content seeds (`assets/data/*.json`) are **bundled and reviewed**; they are
  imported into SQLite on first run (`AppDatabase.ensureSeeded`, versioned by
  `meta.seed_version`).
- The UI **never reads the network**. `SyncService` pulls deltas
  (`updated_at >= cursor`) from curated Supabase tables and upserts into
  SQLite. No credentials → the app simply never syncs and loses nothing.

### 2. The SmartScheduler is pure
`features/reminders/domain/smart_scheduler.dart` takes a `ScheduleContext`
value object (prayer times, Hijri booleans, travel/battery/quiet-hours,
global frequency) and returns a deterministic plan. This is what makes the
"intelligence" testable (`test/smart_scheduler_test.dart`) and lets the same
planner run both in-app and in the workmanager background isolate.

### 3. Headless-safe engine
`ReminderEngine.rescheduleComingDaysHeadless()` reads SharedPreferences +
SQLite directly (never Riverpod) so the exact same planning pass runs:
- after onboarding,
- when any reminder setting changes (debounced by the UI),
- every ~12 h in the background (workmanager `almuin.reschedule.v1`) to roll
  the two-day window forward and roll over the Hijri day.

Notifications themselves carry `payload: /dhikr/<id>` deep links; actions run
in the plugin's background isolate and update SQLite directly.

### 4. Streaks & statistics are *computed*
No duplicated counters: streaks walk `progress_daily`/`tasbeeh_daily`,
charts aggregate on read. Any isolate writing progress automatically moves
the streak.

### 5. State management (Riverpod, no codegen)
- `NotifierProvider` for mutable stores (settings, tasbeeh session, profiles).
- `FutureProvider/Provider` for computed/read models.
- `sharedPreferencesProvider` is overridden in `bootstrap()` so synchronous
  reads are safe everywhere after start-up.

### 6. Theming & RTL
Material 3 with a custom emerald/gold system (`core/theme/app_theme.dart`),
glassmorphism via `GlassCard` (BackdropFilter + gradient + hairline border).
Arabic-first: `localeResolutionCallback` falls back to Arabic; mushaf text
uses Amiri/Noto Naskh through google_fonts (cached; bundling notes in
`assets/fonts/README.md`).

## Data flow for a reminder

```
SharedPreferences(settings+profiles)
        │  ReminderEngine
        ▼
PrayerTimesService (adhan) ──► SmartScheduler.plan(ctx)      [pure]
        │                         │
        ▼                         ▼
AppDatabase.reminder_events   NotificationService.zonedSchedule
        │                         │
        ▼                         ▼
   progress/stats UI      OS notification ──► (done/snooze/listen)
                                                  │
                                        background isolate
                                                  ▼
                            complete/snooze in SQLite, snooze re-schedule,
                            deep link /dhikr/<id>?read=1 on taps
```

## Platform setup required

- `flutter create --platforms=android,ios .` once if platform folders are not
  on disk (they are environment-specific wrappers around the manifest files
  we ship).
- Android 13+ asks for POST_NOTIFICATIONS at runtime — requested at the end
  of onboarding, not at cold start.
- Exact alarms: declared in the manifest (`USE_EXACT_ALARM`); the code falls
  back to inexact scheduling if the permission is withheld.
- Battery optimization: we do **not** request exemption. Instead the engine
  self-throttles (`batterySaver` mode halves nudges, drops the Fajr
  duplicate) and a 12-hour workmanager pass repairs anything the OS killed.
