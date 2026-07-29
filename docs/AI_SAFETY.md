# AI Safety Model (نموذج السلامة الشرعية)

The AI assistant is built around one non-negotiable rule:

> **The app never generates Islamic content. It can only retrieve and rank
> verified, referenced content.**

## The pipeline

```
user message (AR/EN)
   │
   ▼  1. SituationClassifier (deterministic keywords, on-device)
SituationIntent (anxiety, insomnia, travel, gratitude, anger, illness,
                 exam, financialHardship, worry, fear, sadness, rain, general)
   │
   ▼  2. AdhkarRecommender (deterministic scoring, offline)
verified candidates from SQLite — each with text + reference + grade
   │
   ▼  3. (optional) RemoteAiService → Supabase edge fn
re-RANK ONLY, validated subset of candidate ids
   │
   ▼
reply composed exclusively from DB fields (text, reference, reward)
```

## Invariants (enforced in code, covered by tests)

1. **Source-closed retrieval** — recommendations draw exclusively from the
   seeded/synced DB content, every item carrying `collection + number +
   grade`.
2. **Weak-content policy** — `AuthenticityGrade.daif` is excluded from
   unsolicited suggestions unless the developer explicitly sets
   `AdhkarRecommender(allowWeak: true)`; when shown, the ضعيف badge is
   always rendered. Nothing da'if ships in the bundled seed.
3. **User customs are never scripture** — `custom` items are excluded from AI
   suggestions entirely.
4. **Honest fallback** — when nothing matches, the assistant returns a fixed
   admission line ("لم أجد في قاعدتنا الموثّقة… ولن أختلق") and suggests
   universally authentic dhikr (istighfar, tasbih) with their refs.
5. **Cloud can never inject text** — the edge function
   (`supabase/functions/ai-assistant`) receives only {id, reference, grade}
   and outputs only `{selected_ids, empathy}`. The client **discards the
   entire response** if any id is not in the candidate set. The `empathy`
   line is explicitly non-Islamic (validation: it's capped, templated
   around, and displayed with the standard footer noting all religious text
   comes from the references shown beneath each item).
6. **Templated empathy** — the intro sentences are fixed strings per intent
   (`AdhkarRecommender._introFor`), not free generation.

## What the AI deliberately does NOT do

- No invented isnad/matn, no "estimated" authenticity.
- No fatwa. Medical/haram-fiqh-phrased questions get the honest fallback and
  a pointer to consult qualified scholars.
- No Quranic tafsir beyond the curated `tafsir_brief_ar` field per verse.

## Source hierarchy for content (docs/DATA_SOURCES.md)

Quran (mus'haf text) → Sahih Bukhari / Sahih Muslim → Sunan collections with
al-Albani's grading → Hisnul Muslim selections. Each new content batch must
pass `make seed-validate` (category/grade/references checks) before release.
