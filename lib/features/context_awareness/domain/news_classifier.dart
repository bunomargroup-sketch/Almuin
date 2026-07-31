import 'arabic_text.dart';
import 'context_topic.dart';

/// Classifies a headline into a coarse [ContextTopic] — entirely on device.
///
/// What this deliberately does NOT do
/// ----------------------------------
/// It does not summarise, translate, quote, rank by outlet, or retain the
/// headline. The caller passes a string in and gets an enum out; the string
/// is never stored and never reaches the screen. See the contract in
/// `context_topic.dart`.
///
/// Politics is not a topic here, on purpose. A headline about a conflict
/// resolves to [ContextTopic.calamity] only when it also carries a marker of
/// human loss — and calamity surfaces adhkar of patience that name nobody.
/// Elections, statements, summits, sanctions, sport and markets resolve to
/// [ContextTopic.none]: the app stays quiet.
class NewsTopicClassifier {
  const NewsTopicClassifier();

  /// Loss of life or disaster. Arabic first, English second.
  static const _calamity = <String>[
    'قتلى', 'قتيل', 'ضحايا', 'وفاة', 'وفيات', 'مقتل', 'حصيلة',
    'زلزال', 'هزة', 'فيضان', 'فيضانات', 'إعصار', 'اعصار', 'انهيار',
    'حريق', 'كارثة', 'مجاعة', 'غرق', 'تحطم', 'انفجار', 'دمار',
    'killed', 'death', 'deaths', 'died', 'victims', 'toll', 'quake',
    'earthquake', 'flood', 'floods', 'hurricane', 'cyclone', 'wildfire',
    'famine', 'disaster', 'collapse', 'crash', 'blast', 'drowned',
  ];

  /// Public health.
  static const _illness = <String>[
    'وباء', 'جائحة', 'تفشي', 'إصابات', 'اصابات', 'عدوى', 'فيروس', 'مرض',
    'outbreak', 'epidemic', 'pandemic', 'infections', 'virus', 'disease',
    'cholera', 'measles',
  ];

  /// Grief without a death toll.
  static const _hardship = <String>[
    'جفاف', 'نزوح', 'لاجئين', 'لاجئون', 'أزمة', 'ازمة', 'فقر', 'تشريد',
    'حصار', 'مجاعه', 'تضخم',
    'drought', 'displaced', 'refugees', 'crisis', 'poverty', 'siege',
    'shortage', 'inflation',
  ];

  /// Present in most conflict coverage. On its own this is NOT actionable —
  /// it only counts alongside a loss marker. Without this gate the app would
  /// react to every political or military headline, which is precisely the
  /// editorialising we are avoiding.
  static const _conflict = <String>[
    'حرب', 'قصف', 'غارة', 'اشتباك', 'اشتباكات', 'هجوم', 'عملية', 'معارك',
    'war', 'strike', 'strikes', 'shelling', 'clashes', 'attack', 'raid',
    'offensive', 'militants',
  ];

  ContextTopic classify(String headline) {
    if (headline.trim().isEmpty) return ContextTopic.none;
    final text = normalizeArabic(headline);
    final tokens = tokenize(headline);

    bool hits(List<String> bank) =>
        bank.any((k) => keywordMatches(k, text, tokens));

    // Order matters: loss of life outranks everything else.
    if (hits(_calamity)) return ContextTopic.calamity;
    if (hits(_illness)) return ContextTopic.illness;

    // Conflict alone stays silent. Conflict is only reached here when no
    // loss marker fired, which means the headline is about the event, not
    // its human cost — not ours to respond to.
    if (hits(_conflict)) return ContextTopic.none;

    if (hits(_hardship)) return ContextTopic.hardship;
    return ContextTopic.none;
  }

  /// Reduces a batch of headlines to the single most significant topic.
  ///
  /// Returning one topic rather than a list is intentional: a feed of thirty
  /// headlines must not become thirty nudges. Severity wins, ties break
  /// toward the earlier topic in the feed.
  ContextTopic classifyFeed(Iterable<String> headlines) {
    var best = ContextTopic.none;
    for (final h in headlines) {
      final t = classify(h);
      if (t == ContextTopic.none) continue;
      if (best == ContextTopic.none ||
          t.severity.index > best.severity.index) {
        best = t;
      }
    }
    return best;
  }
}
