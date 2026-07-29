# Supabase Setup

Almuin is fully functional without a backend. Supabase adds: content refresh,
optional cloud AI re-ranking, fleet-wide daily content, and (with auth)
cross-device sync of favorites/progress.

## 1. Create the project

```bash
supabase init        # in the repo root (uses supabase/config.toml)
supabase link --project-ref <your-ref>
supabase db push      # applies supabase/schema.sql (tables, RLS, triggers)
# seed the excerpt content (server-side, curated):
psql "$SUPABASE_DB_URL" -f supabase/seed.sql
```

## 2. Edge functions

```bash
supabase functions deploy ai-assistant
supabase functions deploy daily-content

# Optional LLM re-ranking (strictly subset-validated — see docs/AI_SAFETY.md)
supabase secrets set OPENAI_API_KEY=sk-... OPENAI_MODEL=gpt-4o-mini
```

Without `OPENAI_API_KEY`, `ai-assistant` falls back to a deterministic
keyword ranker — the client behaves identically either way.

## 3. Daily content rotation (cron, optional)

```sql
select cron.schedule(
  'almuin-daily-content',
  '15 0 * * *',
  $$select net.http_post(
      url := 'https://<ref>.functions.supabase.co/daily-content',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || '<service-role-key>'))$$
);
```

The app also rotates locally (deterministic day-index), so this is cosmetic
consistency across devices.

## 4. Run the app with sync + AI

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## 5. What the client uses today

| Feature | Table / function | Auth needed |
|---|---|---|
| Incremental content pull | `adhkar`, `verses`, `hadiths` (`updated_at` cursor in `meta`) | none (public SELECT) |
| AI re-rank | `ai-assistant` edge fn | none (carry-only payload) |
| Fleet daily content | `daily_content` | none (read) |
| Favorites/progress sync | `user_favorites`, `user_progress`, `tasbeeh_sessions`, `reminder_events` | anonymous or email auth (RLS owner rows) |
| Push tokens (future) | `device_tokens` | auth |

To enable per-user sync, turn on **Anonymous sign-ins** (already enabled in
`config.toml`), sign the user in transparently at bootstrap, and extend
`SyncService` with the push paths marked in `docs/ARCHITECTURE.md`.

## Security notes

- Content tables: `SELECT` public, writes service-role only.
- Moderation trail: log every change into `content_moderation_log` from your
  editorial tooling.
- Anon key is safe to ship (RLS does the guarding); **never** ship the
  service-role key in the app — it's only for cron/edge invocations.
