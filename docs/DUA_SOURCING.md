# الدعاء — sourcing pipeline

The app now has a `dua` category. `assets/data/dua_manifest.json` lists **162
supplications — 58 from the Qur'an and 104 from the Sunnah — by reference
only.** The `arabic` field of every entry is deliberately empty.

## Why the text is not in the manifest

Every displayed word of scripture in this app carries an authenticity claim.
The index of what to include is a bibliographic fact and travels safely; the
*text itself* does not survive a lossy pipe. Two sources were considered and
both were rejected as text sources:

**The OCR of فقه الدعاء والذكر** (سلسلة مفاهيم, الشيخ محمد الحسن الددو) is used
as a fiqh reference and a takhrīj checklist — see `FIQH_ALDUA.md` — but not for
text. Concrete defects found in it: Qur'an 7:55 lost `إنه لا`, inverting the
meaning; two supplications are missing an interior word (`السحاب`, `عن`);
سيد الاستغفار carries the shadda on the wrong lām; one du'ā' contradicts its own
citation (`نزول البلاء` against `باب التعوذ من جهد البلاء`); Greek, Cyrillic,
Thai and Khmer characters appear where Arabic-Indic digits should be. It is
also a transcript of a live programme, so even a flawless scan would give text
quoted from memory rather than matching the cited collection.

**A web page relayed through a summarising model** carries the same class of
risk for tashkīl, silently.

## What the manifest is good for

Each entry has a stable `id`, the `category`, `tags` for the recommender, an
`incipit` (first few words, unvocalised — enough to identify the item, not
enough to recite), and a full `reference`: collection, number, and grade.
Qur'anic entries cite surah and ayah; prophetic entries cite the collection and
hadith number as given in
[جامع الدعاء من القرآن والسنة](https://www.alukah.net/sharia/0/108314/) by
الشيخ صلاح نجيب الدق.

## Filling the text

1. **Qur'anic (58).** Take the text from a canonical machine-readable muṣḥaf —
   Tanzil's Uthmani text with tashkīl, or an equivalent you trust. The
   surah/ayah references in the manifest are exact, so this step is
   mechanical and verifiable: the filled text must match the cited ayah range
   character for character.
2. **Prophetic (104).** Take each matn from the cited collection in a vocalised
   digital corpus, not from a summary. Where the manifest grade is `pending`
   (currently only `مسند أحمد ١٨٢٩٤`), resolve the grading before shipping.
3. **Then** move the entries into `adhkar_seed.json`, set `textStatus` to
   `filled`, and bump `seedVersion` in `app_database.dart` so existing installs
   re-import.

## The guard

`test/dua_manifest_test.dart` runs in CI and enforces:

- every entry has a complete reference (collection, number, grade);
- an entry has text **if and only if** its `textStatus` is not `pending`;
- **no shipped seed entry may have empty Arabic**;
- **no shipped seed entry may carry a `pending` or unknown grade**.

So a half-finished import fails the build instead of putting incomplete
scripture in front of a user. When you fill the texts, these tests are what
tell you the job is actually done.
