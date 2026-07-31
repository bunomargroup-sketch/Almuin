-- ============================================================================
-- Almuin (المُعين) — Supabase schema
-- ----------------------------------------------------------------------------
-- Design principles:
--  1. CONTENT tables (adhkar, verses, hadiths) are read-only for clients and
--     curated/moderated server-side. The app NEVER ingests scraped or
--     user-generated Islamic content.
--  2. USER tables are private (RLS owner-only) — favorites, progress,
--     tasbeeh, device tokens for push.
--  3. The app works fully offline; this backend is a progressive layer.
-- ============================================================================

create extension if not exists "uuid-ossp";

-- ----------------------------------------------------------------------------
-- CONTENT (public read, service-role write)
-- ----------------------------------------------------------------------------

create table if not exists public.adhkar (
  id               text primary key,
  category         text not null check (category in (
                     'morning','evening','afterPrayer','sleep','wakeUp',
                     'enterHome','leaveHome','enterMosque','leaveMosque',
                     'travel','rain','distress','gratitude','istighfar',
                     'tasbeeh','salawat','quran','hadith', 'dua','custom')),
  time_pref        text not null default 'anytime',
  arabic           text not null,
  transliteration  text not null default '',
  translation_en   text not null default '',
  meaning_ar       text not null default '',
  reward_ar        text not null default '',
  repeat           integer not null default 1,
  grade            text not null check (grade in ('quran','sahih','hasan','daif','custom')),
  refs_json        jsonb not null default '[]',
  tags_json        jsonb not null default '[]',
  reviewed_by      text,                -- content moderator / reviewer id
  updated_at       timestamptz not null default now()
);

create table if not exists public.verses (
  id               text primary key,
  surah_name_ar    text not null,
  surah_number     integer not null,
  ayah_number      integer not null,
  arabic           text not null,
  translation_en   text not null default '',
  tafsir_brief_ar  text not null default '',
  tags_json        jsonb not null default '[]',
  updated_at       timestamptz not null default now()
);

create table if not exists public.hadiths (
  id               text primary key,
  arabic           text not null,
  translation_en   text not null default '',
  benefit_ar       text not null default '',
  collection       text not null,       -- e.g. 'صحيح البخاري'
  number           text not null,
  grade            text not null check (grade in ('quran','sahih','hasan','daif','custom')),
  tags_json        jsonb not null default '[]',
  updated_at       timestamptz not null default now()
);

-- Moderation audit trail: every content change is logged.
create table if not exists public.content_moderation_log (
  id           bigint generated always as identity primary key,
  table_name   text not null,
  row_id       text not null,
  action       text not null check (action in ('insert','update','delete')),
  actor        text,
  reason       text,
  created_at   timestamptz not null default now()
);

-- Daily featured content (rotated by the daily-content edge function so all
-- devices optionally agree on the same verse/hadith).
create table if not exists public.daily_content (
  day          date primary key,
  verse_id     text references public.verses(id),
  hadith_id    text references public.hadiths(id),
  dhikr_id     text references public.adhkar(id)
);

-- ----------------------------------------------------------------------------
-- USER DATA (RLS owner-only)
-- ----------------------------------------------------------------------------

create table if not exists public.profiles (
  id               uuid primary key references auth.users on delete cascade,
  display_name     text,
  locale           text not null default 'ar',
  theme            text not null default 'system',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table if not exists public.user_favorites (
  user_id      uuid not null references auth.users on delete cascade,
  -- Opaque content key (review M9): the device bundles 74 adhkar while the
  -- server corpus may seed fewer — an FK here would reject favorites for
  -- bundled-only items with 23503.
  dhikr_id     text not null,
  created_at   timestamptz not null default now(),
  primary key (user_id, dhikr_id)
);

create table if not exists public.user_progress (
  user_id        uuid not null references auth.users on delete cascade,
  day            date not null,
  completed      integer not null default 0,
  snoozed        integer not null default 0,
  adhkar_read    integer not null default 0,
  tasbeeh_count  integer not null default 0,
  primary key (user_id, day)
);

create table if not exists public.tasbeeh_sessions (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references auth.users on delete cascade,
  dhikr_id     text,
  dhikr_text   text not null,
  target       integer not null,
  count        integer not null,
  started_at   timestamptz not null,
  completed_at timestamptz
);

create table if not exists public.reminder_events (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references auth.users on delete cascade,
  dhikr_id      text,
  category      text,
  scheduled_at  timestamptz not null,
  status        text not null default 'scheduled'
                 check (status in ('scheduled','delivered','completed','snoozed','cancelled')),
  completed_at  timestamptz
);

-- Push tokens (used by notification edge functions / Expo-style push later).
create table if not exists public.device_tokens (
  user_id      uuid not null references auth.users on delete cascade,
  token        text not null,
  platform     text not null check (platform in ('android','ios')),
  updated_at   timestamptz not null default now(),
  primary key (user_id, token)
);

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------

alter table public.adhkar             enable row level security;
alter table public.verses             enable row level security;
alter table public.hadiths            enable row level security;
alter table public.daily_content      enable row level security;
alter table public.profiles           enable row level security;
alter table public.user_favorites     enable row level security;
alter table public.user_progress      enable row level security;
alter table public.tasbeeh_sessions   enable row level security;
alter table public.reminder_events    enable row level security;
alter table public.device_tokens      enable row level security;
-- Review S1: the moderation audit trail must NOT be readable/writable with
-- the public anon key. RLS enabled with NO client policies = service-role
-- only (service role bypasses RLS, so editorial tooling keeps working).
alter table public.content_moderation_log enable row level security;

-- Content: readable by everyone (even anonymous), writable by service role only.
drop policy if exists "content_read_adhkar"   on public.adhkar;
create policy "content_read_adhkar"   on public.adhkar   for select using (true);
drop policy if exists "content_read_verses"   on public.verses;
create policy "content_read_verses"   on public.verses   for select using (true);
drop policy if exists "content_read_hadiths"  on public.hadiths;
create policy "content_read_hadiths"  on public.hadiths  for select using (true);
drop policy if exists "content_read_daily"    on public.daily_content;
create policy "content_read_daily"    on public.daily_content for select using (true);

-- User tables: strict ownership.
drop policy if exists "own_profile"      on public.profiles;
create policy "own_profile"      on public.profiles
  using (auth.uid() = id) with check (auth.uid() = id);
drop policy if exists "own_favorites"    on public.user_favorites;
create policy "own_favorites"    on public.user_favorites
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_progress"     on public.user_progress;
create policy "own_progress"     on public.user_progress
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_tasbeeh"      on public.tasbeeh_sessions;
create policy "own_tasbeeh"      on public.tasbeeh_sessions
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_events"       on public.reminder_events;
create policy "own_events"       on public.reminder_events
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_tokens"       on public.device_tokens;
create policy "own_tokens"       on public.device_tokens
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- updated_at triggers
-- ----------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists adhkar_touch on public.adhkar;
create trigger adhkar_touch  before update on public.adhkar
  for each row execute function public.touch_updated_at();
drop trigger if exists verses_touch on public.verses;
create trigger verses_touch  before update on public.verses
  for each row execute function public.touch_updated_at();
drop trigger if exists hadiths_touch on public.hadiths;
create trigger hadiths_touch before update on public.hadiths
  for each row execute function public.touch_updated_at();
drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Helpful indexes for incremental sync (the app pulls `updated_at >= cursor`).
create index if not exists idx_adhkar_updated   on public.adhkar(updated_at);
create index if not exists idx_verses_updated   on public.verses(updated_at);
create index if not exists idx_hadiths_updated  on public.hadiths(updated_at);

-- Review M8: user tables are filtered by user_id (app queries AND the RLS
-- predicate itself) — index them or reads sequentially scan all users' rows.
create index if not exists idx_user_favorites_user   on public.user_favorites(user_id);
create index if not exists idx_user_progress_user    on public.user_progress(user_id, day);
create index if not exists idx_tasbeeh_sessions_user on public.tasbeeh_sessions(user_id, started_at);
create index if not exists idx_reminder_events_user  on public.reminder_events(user_id, scheduled_at);
create index if not exists idx_device_tokens_user    on public.device_tokens(user_id);
