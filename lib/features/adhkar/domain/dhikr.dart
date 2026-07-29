import 'dart:convert';

/// Category of adhkar — mirrors the setup-wizard choices.
enum DhikrCategory {
  morning,
  evening,
  afterPrayer,
  sleep,
  wakeUp,
  enterHome,
  leaveHome,
  enterMosque,
  leaveMosque,
  travel,
  rain,
  distress,
  gratitude,
  istighfar,
  tasbeeh,
  salawat,
  quran,
  hadith,
  custom;

  static DhikrCategory fromName(String? name) => DhikrCategory.values
      .asNameMap()[name] ?? DhikrCategory.custom;
}

/// When a dhikr is traditionally recited — drives time-aware ranking.
enum ContentTime { morning, evening, afterPrayer, night, anytime }

/// SAFETY: every piece of Islamic content in the app carries an explicit
/// authenticity grade (see docs/AI_SAFETY.md).
enum AuthenticityGrade {
  quran,
  sahih,
  hasan,
  daif,

  /// User-added personal dhikr — displayed with a distinct badge and never
  /// presented as scripture by the AI.
  custom,
}

class DhikrReference {
  const DhikrReference({
    required this.collection,
    required this.number,
    required this.grade,
    this.note,
  });

  final String collection; // e.g. "صحيح البخاري" / "Quran"
  final String number; // e.g. "6306" / "2:255"
  final AuthenticityGrade grade;
  final String? note; // e.g. "التخريج: صححه الألباني"

  factory DhikrReference.fromJson(Map<String, dynamic> j) => DhikrReference(
        collection: j['collection'] as String? ?? '',
        number: j['number'] as String? ?? '',
        grade: AuthenticityGrade.values.asNameMap()[j['grade'] as String?] ??
            AuthenticityGrade.hasan,
        note: j['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'collection': collection,
        'number': number,
        'grade': grade.name,
        if (note != null) 'note': note,
      };

  /// e.g. "صحيح البخاري ٦٣٠٦"
  String format() => number.isEmpty ? collection : '$collection $number';
}

/// Immutable dhikr entity. `timesRead` / `isFavorite` are local user state
/// merged in by the repository.
class Dhikr {
  const Dhikr({
    required this.id,
    required this.category,
    required this.time,
    required this.arabic,
    required this.repeat,
    required this.references,
    this.transliteration = '',
    this.translationEn = '',
    this.meaningAr = '',
    this.rewardAr = '',
    this.tags = const [],
    this.isFavorite = false,
    this.timesRead = 0,
  });

  final String id;
  final DhikrCategory category;
  final ContentTime time;
  final String arabic;
  final String transliteration;
  final String translationEn;
  final String meaningAr;
  final String rewardAr;
  final int repeat;
  final List<DhikrReference> references;
  final List<String> tags;

  // Local user state
  final bool isFavorite;
  final int timesRead;

  /// The highest authenticity among references — drives badges and,
  /// critically, what the AI is allowed to recommend unprompted.
  AuthenticityGrade get bestGrade {
    const order = [
      AuthenticityGrade.quran,
      AuthenticityGrade.sahih,
      AuthenticityGrade.hasan,
      AuthenticityGrade.daif,
      AuthenticityGrade.custom,
    ];
    if (references.isEmpty) return AuthenticityGrade.custom;
    return references
        .map((r) => r.grade)
        .reduce((a, b) => order.indexOf(a) <= order.indexOf(b) ? a : b);
  }

  Dhikr copyWith({bool? isFavorite, int? timesRead}) => Dhikr(
        id: id,
        category: category,
        time: time,
        arabic: arabic,
        transliteration: transliteration,
        translationEn: translationEn,
        meaningAr: meaningAr,
        rewardAr: rewardAr,
        repeat: repeat,
        references: references,
        tags: tags,
        isFavorite: isFavorite ?? this.isFavorite,
        timesRead: timesRead ?? this.timesRead,
      );

  factory Dhikr.fromJson(Map<String, dynamic> j) => Dhikr(
        id: j['id'] as String,
        category: DhikrCategory.fromName(j['category'] as String?),
        time: ContentTime.values.asNameMap()[j['time'] as String?] ??
            ContentTime.anytime,
        arabic: j['arabic'] as String,
        transliteration: j['transliteration'] as String? ?? '',
        translationEn: j['translationEn'] as String? ?? '',
        meaningAr: j['meaningAr'] as String? ?? '',
        rewardAr: j['rewardAr'] as String? ?? '',
        repeat: (j['repeat'] as num?)?.toInt() ?? 1,
        references: [
          for (final r in (j['references'] as List<dynamic>? ?? const []))
            DhikrReference.fromJson(r as Map<String, dynamic>),
        ],
        tags: [
          for (final t in (j['tags'] as List<dynamic>? ?? const [])) '$t',
        ],
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'category': category.name,
        'time_pref': time.name,
        'arabic': arabic,
        'transliteration': transliteration,
        'translation_en': translationEn,
        'meaning_ar': meaningAr,
        'reward_ar': rewardAr,
        'repeat': repeat,
        'grade': bestGrade.name,
        'refs_json': jsonEncode([for (final r in references) r.toJson()]),
        'tags_json': jsonEncode(tags),
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory Dhikr.fromRow(Map<String, Object?> r) => Dhikr(
        id: r['id'] as String,
        category: DhikrCategory.fromName(r['category'] as String?),
        time: ContentTime.values.asNameMap()[r['time_pref'] as String?] ??
            ContentTime.anytime,
        arabic: r['arabic'] as String,
        transliteration: (r['transliteration'] as String?) ?? '',
        translationEn: (r['translation_en'] as String?) ?? '',
        meaningAr: (r['meaning_ar'] as String?) ?? '',
        rewardAr: (r['reward_ar'] as String?) ?? '',
        repeat: (r['repeat'] as int?) ?? 1,
        references: [
          for (final x in jsonDecode((r['refs_json'] as String?) ?? '[]')
              as List<dynamic>)
            DhikrReference.fromJson(x as Map<String, dynamic>),
        ],
        tags: [
          for (final t in jsonDecode((r['tags_json'] as String?) ?? '[]')
              as List<dynamic>)
            '$t',
        ],
        isFavorite: (r['is_favorite'] as int?) == 1,
        timesRead: (r['times_read'] as int?) ?? 0,
      );
}

/// A curated Quran verse used for "Verse of the day" and AI suggestions.
class Verse {
  const Verse({
    required this.id,
    required this.surahNameAr,
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabic,
    this.translationEn = '',
    this.tafsirBriefAr = '',
    this.tags = const [],
  });

  final String id;
  final String surahNameAr;
  final int surahNumber;
  final int ayahNumber;
  final String arabic;
  final String translationEn;
  final String tafsirBriefAr;
  final List<String> tags;

  String get reference => 'سورة $surahNameAr — $surahNumber:$ayahNumber';

  factory Verse.fromJson(Map<String, dynamic> j) => Verse(
        id: j['id'] as String,
        surahNameAr: j['surahNameAr'] as String,
        surahNumber: (j['surahNumber'] as num).toInt(),
        ayahNumber: (j['ayahNumber'] as num).toInt(),
        arabic: j['arabic'] as String,
        translationEn: j['translationEn'] as String? ?? '',
        tafsirBriefAr: j['tafsirBriefAr'] as String? ?? '',
        tags: [for (final t in (j['tags'] as List<dynamic>? ?? const [])) '$t'],
      );
}

/// A curated hadith used for "Hadith of the day".
class DailyHadith {
  const DailyHadith({
    required this.id,
    required this.arabic,
    required this.collection,
    required this.number,
    required this.grade,
    this.translationEn = '',
    this.benefitAr = '',
    this.tags = const [],
  });

  final String id;
  final String arabic;
  final String translationEn;
  final String benefitAr;
  final String collection;
  final String number;
  final AuthenticityGrade grade;
  final List<String> tags;

  String get reference => '$collection $number';

  factory DailyHadith.fromJson(Map<String, dynamic> j) => DailyHadith(
        id: j['id'] as String,
        arabic: j['arabic'] as String,
        translationEn: j['translationEn'] as String? ?? '',
        benefitAr: j['benefitAr'] as String? ?? '',
        collection: j['collection'] as String,
        number: j['number'] as String,
        grade: AuthenticityGrade.values.asNameMap()[j['grade'] as String?] ??
            AuthenticityGrade.sahih,
        tags: [for (final t in (j['tags'] as List<dynamic>? ?? const [])) '$t'],
      );
}
