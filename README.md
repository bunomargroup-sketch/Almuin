<div dir="rtl">

# المُعين · Almuin

**مساعدك الإيماني الذكي** — تطبيق أذكار وتذكيرات إسلامية حديث بالعربية (مع دعم الإنجليزية).

ليست مجرد تنبيهات ثابتة: المُعين **يربط أذكارك بمواقيت الصلاة، ويوم الجمعة، ورمضان، والعيدين، ووضع السفر، وساعات الهدوء** — ويحتوي **مساعدًا ذكيًا آمنًا** يقترح الأذكار والآيات **المُوثَّقة بالمراجع** بحسب حالك، دون أن يختلق أي محتوى شرعي.

</div>

**Almuin** — an intelligent personal Islamic dhikr assistant in Arabic (optional English). Prayer-anchored smart reminders, a verified adhkar library, digital tasbeeh, streaks & achievements, and a **safety-first AI** that only recommends referenced Quran/hadith/adhkar.

---

## Highlights

| Area | What it does |
|---|---|
| 🧠 Smart reminders | Morning = Fajr + 20 min, evening = Maghrib − 20 min, after each prayer, sleep & wake anchors, Friday Salawat boost, Ramadan Quran boost, Eid takbir, travel mode, battery saver, quiet hours |
| 🤖 AI assistant | On-device intent classifier (Arabic + English) → deterministic retrieval over a **verified** content DB. Optional Supabase edge function re-ranks candidates (strict subset validation — it can *never* inject Islamic text) |
| 📿 Dhikr library | 74 curated adhkar with Arabic, transliteration, translation, meaning, reward, references, authenticity grade, repeat counter, TTS, share, favorites |
| 📅 Home dashboard | Prayer countdown, current prayer, Hijri date, verse & hadith of the day, recommended dhikr, streak, progress, quick tasbeeh |
| 🔢 Tasbeeh | Digital counter with goals, haptics, daily/lifetime stats, achievements |
| 🏆 Gamification | Badges, streaks, encouraging messages |
| 📴 Offline-first | Everything runs from bundled, reviewed seeds + SQLite after first launch |
| 🎨 Design | Material 3, glassmorphism, Amiri/Noto Naskh mushaf typography, dark mode, Arabic-first RTL |

## Safety promise (وعد السلامة)

Every item carries **collection + number + grade**. Weak (ضعيف) content is
never seeded by default and, if ever enabled, is clearly badged. The AI
**cannot fabricate** hadith or adhkar — when nothing authentic matches, it
says so honestly. See [`docs/AI_SAFETY.md`](docs/AI_SAFETY.md).

## Getting started

```bash
flutter pub get
# (Optional, regenerates Android/iOS platform folders if you cloned sources only)
flutter create --platforms=android,ios .

# Run fully offline (no backend needed):
flutter run

# Optional cloud sync + AI re-ranking:
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

flutter test
```

Then walk through the setup wizard: pick your adhkar categories, allow
location (for prayer times) and notifications — reminders schedule
themselves around your Fajr/Maghrib automatically.

Optional premium add-ons: bundle `assets/fonts/*.ttf` and `assets/sounds/soft_chime.mp3` (see the README files inside those folders).

## Architecture

Clean Architecture + feature-first layering:

```
lib/
├─ main.dart · app.dart · bootstrap.dart
├─ core/            # config, theme (M3 + glass), router, services
│  ├─ services/     # SQLite, notifications(+background isolate), TTS,
│  │                # workmanager, settings, Supabase sync
│  └─ utils/        # Hijri seasons, quiet-hours windows, day keys
├─ features/
│  ├─ onboarding/   # 4-step setup wizard
│  ├─ adhkar/       # domain model + repository + library/detail UI
│  ├─ prayer/       # adhan wrapper (times), countdown ticker
│  ├─ reminders/    # ★ SmartScheduler (pure, tested) + ReminderEngine
│  ├─ home/         # dashboard & daily rotation
│  ├─ tasbeeh/      # controller + page
│  ├─ ai_assistant/ # classifier → recommender → (validated) remote rank
│  ├─ statistics/ · gamification/ · settings/ · shell/
└─ l10n/            # app_ar.arb (template) · app_en.arb
assets/data/        # bundled, reviewed content seeds (offline source of truth)
supabase/           # schema.sql · seed.sql · edge functions (ai-assistant, daily-content)
docs/               # architecture, AI safety, notifications, data sources
```

Details: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) ·
[`docs/NOTIFICATIONS.md`](docs/NOTIFICATIONS.md) ·
[`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md) ·
[`docs/SUPABASE_SETUP.md`](docs/SUPABASE_SETUP.md)

## Testing

```bash
flutter test   # scheduler rules, quiet hours, Friday/Ramadan boosts,
               # AI classifier (AR/EN), recommender safety invariants
```

---

بارك الله فيكم — صدقة جارية لكل من يذكّر مسلمًا بذكر الله.
