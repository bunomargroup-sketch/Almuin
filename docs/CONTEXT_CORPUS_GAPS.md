# Context-aware suggestions — corpus gaps

The context feature maps a signal (weather, calendar, a coarse news topic) to
an **already-verified dhikr from the local corpus**. It never generates
religious text and never displays anything derived from a news headline.

Several signals the app can already *detect* have no matching entry in
`assets/data/adhkar_seed.json`. For those, `ContextTopic.awaitingCorpus`
returns true and the app deliberately stays silent — surfacing a loosely
related supplication for an eclipse is worse than surfacing nothing.

Filling these gaps is sourcing and grading work, not code. Each needs the
Arabic text, a collection and number, and an authenticity grade, in the same
shape as existing seed entries.

| Topic | Needed | Notes |
|---|---|---|
| `eclipse` | Adhkar/salat al-kusuf guidance | Prayer, not only dhikr — may warrant its own screen rather than a card |
| `earthquake` | Supplication on earthquake / at signs in nature | Currently falls back to silence despite being classified as grave |
| `snow` | Dhikr on snow and hail | Often grouped with rain in the sources |
| `fog` | — | Low value; consider dropping the topic instead of sourcing it |
| `ashura` | Fasting and dhikr for Ashura and Muharram | Calendar detection already exists via `hijri_utils.dart` |

Also worth strengthening, though these do resolve today via tag fallback:

| Topic | Currently resolves via | Better with |
|---|---|---|
| `strongWind` | `protection` / `fear` tags | The specific wind supplication (`اللهم إني أسألك خيرها…`) |
| `calamity` | `sadness` / `distress` / `relief` tags | Istirja' (`إنا لله وإنا إليه راجعون`) and the dua on affliction |
| `illness` | `illness` / `healing` tags — only 3 items carry them | The prophetic supplications for the sick and for well-being |
| `extremeHeat` / `extremeCold` | `protection` / `relief` | The narrations on the breath of Hellfire, if you consider them fit |

## Adding an entry

Add to `assets/data/adhkar_seed.json` with a category and tags that the
mapping in `contextual_matcher.dart` already looks for, then bump
`seedVersion` so existing installs re-import. Remove the topic from
`ContextTopic.awaitingCorpus` once its entry exists — the tests in
`test/context_awareness_test.dart` assert silence for anything still listed
there, so that test will tell you if you forget one half of the change.
