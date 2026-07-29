# Data Sources & Content Policy

Almuin never scrapes websites. Islamic content comes from **three controlled
paths only**:

## 1. Bundled seeds (the offline source of truth)

`assets/data/adhkar_seed.json` (74 adhkar) · `verses_seed.json` (13 verses) ·
`hadith_seed.json` (12 hadiths).

Every item was curated from:

| Source | Used for |
|---|---|
| **Quran (mus'haf text)** | Verse of the day, situational ayat, Ayat al-Kursi, last two of Al-Baqarah |
| **Sahih al-Bukhari / Sahih Muslim** | Most adhkar (collection + hadith number on every card) |
| **Sunan Abi Dawud, Jami' at-Tirmidhi, Ibn Majah, Nasa'i** | With a takhrij note, following the grading of al-Albani where noted |
| **Hisnul Muslim (حصن المسلم)** | Category structure & wording conventions |

Numbering follows the widely used **Muhammad Fu'ad 'Abd al-Baqi (Bukhari)** /
**Darussalam** global numbering. Where numbering varies between prints, the
reference uses *collection + chapter* instead of a bare number — an honest
reference beats a potentially wrong one.

Each item declares: `id, category, time, arabic, transliteration,
translationEn, meaningAr, rewardAr, repeat, references[{collection, number,
grade, note}], tags`.

## 2. Trusted live APIs (optional, cached)

When adding online refresh, use only structured, maintained sources:

- **Quran.com API** (`api.quran.com/api/v4`) — canonical uthmani text.
- **Sunnah.com API** (`api.sunnah.com/v1`) — hadith with grades (requires
  API key; rate-limited; results are cached into SQLite like everything else).
- **Aladhan API** or the bundled `adhan` package for prayer times (the app
  already computes locally — APIs are fallback only).

Responses are **schema-validated** and any item without a collection+number
is rejected at the sync boundary.

## 3. Curated Supabase content tables

Server-side tables mirror the seed shape (`refs_json`, `grade`, review
metadata, `content_moderation_log` audit trail). Writes are service-role
only — clients read. Moderators add content **with references**, and the
app's incremental sync (`updated_at` cursor) upserts them into SQLite.

## Hard rules

1. **No user-generated Islamic text** is ever stored as `grade != custom`
   — customs land in the user's `custom` category, never mixed into the
   curated corpus, never AI-suggested.
2. **No unauthenticated hadith by default**: `daif` is excluded from the
   seed and from unsolicited suggestions.
3. **Every card shows its reference** — the detail page renders the
   `dhikrReference` section unconditionally; cards carry the authenticity
   badge.
4. **Rewards are sourced** (`rewardAr` corresponds to the referenced hadith,
   not a paraphrase of marketing copy).
5. **Versioned corps** — `meta.seed_version` allows reviewable, monotonic
   content updates.
