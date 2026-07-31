/// Contextual signals that can justify surfacing a *specific* authentic dhikr.
///
/// Design contract (read before extending)
/// ---------------------------------------
/// A topic is a **signal**, never **content**. Nothing derived from a news
/// headline is ever shown to the user: no title, no outlet, no place, no
/// party, no numbers. The signal only decides *which already-verified dhikr*
/// from the local corpus is surfaced, and the dhikr speaks for itself.
///
/// This keeps three promises at once:
///  * the app never renders religious text it did not ship and grade
///    (the guarantee `docs/AI_SAFETY.md` is built on);
///  * the app never appears to editorialise about a contested event;
///  * no third-party text is reproduced, so there is no attribution or
///    licensing question.
library;

/// How strongly a signal should influence what the user sees.
enum ContextSeverity {
  /// Ambient, pleasant, or purely calendrical. Safe to show any time.
  ambient,

  /// Worth a gentle nudge — active weather, a notable day.
  notable,

  /// Something grievous. Comfort only, and never more than one a day.
  grave,
}

/// The normalised meaning of a signal, independent of where it came from.
enum ContextTopic {
  // ── Weather and natural events (objective, location-derived) ───────────
  rain,
  thunderstorm,
  strongWind,
  snow,
  extremeHeat,
  extremeCold,
  fog,
  earthquake,
  eclipse,

  // ── News-derived, deliberately coarse (see the contract above) ─────────
  /// Loss of life, disaster, or widespread suffering, anywhere.
  calamity,

  /// Disease outbreak or a public health emergency.
  illness,

  /// Economic hardship, drought, displacement — grief without a death toll.
  hardship,

  // ── Islamic calendar ───────────────────────────────────────────────────
  friday,
  ramadan,
  dhulHijjah,
  ashura,

  /// Nothing actionable. The correct and common outcome.
  none;

  ContextSeverity get severity => switch (this) {
        ContextTopic.calamity => ContextSeverity.grave,
        ContextTopic.illness => ContextSeverity.grave,
        ContextTopic.earthquake => ContextSeverity.grave,
        ContextTopic.hardship => ContextSeverity.notable,
        ContextTopic.thunderstorm => ContextSeverity.notable,
        ContextTopic.strongWind => ContextSeverity.notable,
        ContextTopic.extremeHeat => ContextSeverity.notable,
        ContextTopic.extremeCold => ContextSeverity.notable,
        ContextTopic.eclipse => ContextSeverity.notable,
        ContextTopic.snow => ContextSeverity.ambient,
        ContextTopic.fog => ContextSeverity.ambient,
        ContextTopic.rain => ContextSeverity.ambient,
        ContextTopic.friday => ContextSeverity.ambient,
        ContextTopic.ramadan => ContextSeverity.ambient,
        ContextTopic.dhulHijjah => ContextSeverity.ambient,
        ContextTopic.ashura => ContextSeverity.ambient,
        ContextTopic.none => ContextSeverity.ambient,
      };

  /// Topics whose prescribed adhkar are **not yet in the seed corpus**.
  ///
  /// The app must stay silent for these rather than substitute a loosely
  /// related dhikr — surfacing the wrong supplication for an eclipse is worse
  /// than surfacing nothing. See `docs/CONTEXT_CORPUS_GAPS.md` for the list
  /// that still needs sourcing and grading.
  bool get awaitingCorpus => switch (this) {
        ContextTopic.eclipse => true,
        ContextTopic.earthquake => true,
        ContextTopic.snow => true,
        ContextTopic.fog => true,
        ContextTopic.ashura => true,
        _ => false,
      };
}
