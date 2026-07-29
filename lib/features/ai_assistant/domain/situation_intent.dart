/// The situations Almuin understands (Arabic + English keywords).
///
/// This classifier is deliberately *deterministic* and on-device: matching a
/// user's feelings to topics never requires a hallucination-prone model.
/// An optional cloud LLM can re-rank candidates — but can never add Islamic
/// content (see docs/AI_SAFETY.md).
enum SituationIntent {
  anxiety,
  stress,
  worry,
  fear,
  sadness,
  insomnia,
  travel,
  gratitude,
  anger,
  illness,
  exam,
  financialHardship,
  rain,
  general,
}

class IntentMatch {
  const IntentMatch(this.intent, this.confidence);
  final SituationIntent intent;
  final double confidence; // 0..1 — used to decide when to say "not sure"
}

class SituationClassifier {
  /// Keyword banks: Arabic stems + English words, weighted.
  static const Map<SituationIntent, List<String>> _keywords = {
    SituationIntent.anxiety: [
      'قلق', 'قلقة', 'مقلق', 'توتر', 'متوتر', 'anxious', 'anxiety',
      'stressed', 'stress', 'panic', 'worried sick',
    ],
    SituationIntent.worry: [
      'أفكر', 'هم', 'هموم', 'مهموم', 'كرب', 'مكروب', 'ضيق', 'ضائق',
      'worry', 'worried', 'overwhelmed', 'burden', 'distress',
    ],
    SituationIntent.fear: [
      'خائف', 'خوف', 'أخاف', 'مرعوب', 'fear', 'afraid', 'scared', 'terrified',
    ],
    SituationIntent.sadness: [
      'حزين', 'حزن', 'كئيب', 'اكتئاب', 'بكاء', 'sad', 'depressed', 'cry',
      'heartbroken', 'grief',
    ],
    SituationIntent.insomnia: [
      'نوم', 'أرق', 'أرهقني النوم', 'ما أقدر أنام', 'لا أستطيع النوم',
      'sleep', 'insomnia', 'cant sleep', "can't sleep", 'sleepless',
    ],
    SituationIntent.travel: [
      'سفر', 'مسافر', 'رحلة', 'طيارة', 'سائق', 'travel', 'traveling',
      'travelling', 'trip', 'flight', 'journey', 'driving',
    ],
    SituationIntent.gratitude: [
      'شكر', 'نعمة', 'ممتن', 'سعيد', 'فرح', 'فرحان', 'grateful', 'thankful',
      'happy', 'blessing', 'alhamdulillah', 'joy',
    ],
    SituationIntent.anger: [
      'غاضب', 'غضب', 'زعلان', 'عصبية', 'أعصاب', 'angry', 'anger', 'furious',
      'rage', 'mad',
    ],
    SituationIntent.illness: [
      'مريض', 'مرض', 'ألم', 'وجع', 'مستشفى', 'sick', 'ill', 'pain',
      'hospital', 'disease', 'cancer',
    ],
    SituationIntent.exam: [
      'امتحان', 'اختبار', 'مذاكرة', 'دراسة', 'exam', 'test tomorrow',
      'study', 'studying', 'interview', 'مقابلة',
    ],
    SituationIntent.financialHardship: [
      'وظيفة', 'فصلت من العمل', 'رزق', 'دين', 'فقر', 'ضائقة مالية',
      'job', 'fired', 'laid off', 'lost my job', 'money', 'debt', 'broke',
    ],
    SituationIntent.rain: [
      'مطر', 'أمطار', 'شتاء', 'rain', 'raining', 'storm',
    ],
  };

  /// Phrases that hint "my X" situations needing the same care, e.g.
  /// "my mother is sick" → illness.
  static const _relational = ['أمي', 'أبي', 'أم', 'أب', 'اخي', 'أختي', 'mother', 'father', 'mom', 'dad', 'son', 'daughter'];

  IntentMatch classify(String text) {
    final lower = _normalize(text);
    final scores = <SituationIntent, double>{};
    for (final entry in _keywords.entries) {
      var score = 0.0;
      for (final kw in entry.value) {
        if (lower.contains(kw)) {
          score += kw.length > 4 ? 1.0 : 0.6;
        }
      }
      if (score > 0) scores[entry.key] = score;
    }
    if (scores.isEmpty) {
      return const IntentMatch(SituationIntent.general, 0.3);
    }
    // Relational phrasing slightly boosts confidence (user told a real story).
    final relationalBoost = _relational.any(lower.contains) ? 0.15 : 0.0;
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final confidence =
        (best.value / 2.5 + relationalBoost).clamp(0.0, 1.0).toDouble();
    return IntentMatch(best.key, confidence);
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[ً-ْٰ]'), '') // strip harakat
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
