import 'package:almuin/features/adhkar/domain/dhikr.dart';
import 'package:almuin/features/context_awareness/domain/arabic_text.dart';
import 'package:almuin/features/context_awareness/domain/context_topic.dart';
import 'package:almuin/features/context_awareness/domain/contextual_matcher.dart';
import 'package:almuin/features/context_awareness/domain/news_classifier.dart';
import 'package:almuin/features/context_awareness/domain/weather_codes.dart';
import 'package:flutter_test/flutter_test.dart';

Dhikr d(
  String id,
  DhikrCategory cat, {
  List<String> tags = const [],
  int timesRead = 0,
}) =>
    Dhikr(
      id: id,
      category: cat,
      time: ContentTime.anytime,
      arabic: 'نص $id',
      repeat: 1,
      references: const [
        DhikrReference(
            collection: 'مرجع', number: '1', grade: AuthenticityGrade.sahih),
      ],
      tags: tags,
      timesRead: timesRead,
    );

void main() {
  group('Arabic token matching', () {
    test('short stems do not match inside longer words', () {
      // The bug class this whole helper exists to prevent.
      final t = tokenize('اللهم صلِّ على النبي');
      expect(keywordMatches('هم', normalizeArabic('اللهم صل على النبي'), t),
          isFalse);
    });

    test('definite article is stripped so الزلزال matches زلزال', () {
      final text = normalizeArabic('وقع الزلزال في المدينة');
      final t = tokenize('وقع الزلزال في المدينة');
      expect(keywordMatches('زلزال', text, t), isTrue);
    });

    test('diacritics and alef variants are folded', () {
      expect(normalizeArabic('إِنَّا'), normalizeArabic('انا'));
      expect(normalizeArabic('رَحْمَة'), normalizeArabic('رحمه'));
    });
  });

  group('NewsTopicClassifier', () {
    const clf = NewsTopicClassifier();

    test('empty input is silent', () {
      expect(clf.classify(''), ContextTopic.none);
      expect(clf.classify('   '), ContextTopic.none);
    });

    test('conflict WITHOUT loss of life stays silent', () {
      // The editorial guarantee: the app does not react to war coverage as
      // such, only to human loss. If this ever fails, the app has started
      // commenting on politics.
      expect(clf.classify('غارة جوية على مواقع عسكرية'), ContextTopic.none);
      expect(clf.classify('Air strike targets military positions'),
          ContextTopic.none);
      expect(clf.classify('اشتباكات على الحدود'), ContextTopic.none);
    });

    test('loss of life is calamity, in either language', () {
      expect(clf.classify('عشرات القتلى في زلزال'), ContextTopic.calamity);
      expect(clf.classify('Dozens killed as floods hit the region'),
          ContextTopic.calamity);
      expect(clf.classify('ارتفاع حصيلة الضحايا'), ContextTopic.calamity);
    });

    test('ordinary news is silent', () {
      expect(clf.classify('نتائج الانتخابات البرلمانية'), ContextTopic.none);
      expect(clf.classify('Stock markets close higher'), ContextTopic.none);
      expect(clf.classify('فوز الفريق بالمباراة'), ContextTopic.none);
      expect(clf.classify('قمة اقتصادية في الرياض'), ContextTopic.none);
    });

    test('health and hardship map to their own topics', () {
      expect(clf.classify('تفشي وباء الكوليرا'), ContextTopic.illness);
      expect(clf.classify('Cholera outbreak spreads'), ContextTopic.illness);
      expect(clf.classify('جفاف يهدد المحاصيل'), ContextTopic.hardship);
      expect(clf.classify('Drought threatens harvests'), ContextTopic.hardship);
    });

    test('a feed yields exactly one topic, the most severe', () {
      final topic = clf.classifyFeed([
        'نتائج الانتخابات',
        'جفاف يهدد المحاصيل',
        'عشرات القتلى في فيضانات',
        'فوز الفريق',
      ]);
      expect(topic, ContextTopic.calamity);
    });

    test('a feed with nothing actionable stays silent', () {
      expect(
        clf.classifyFeed(['قمة اقتصادية', 'Stock markets close higher']),
        ContextTopic.none,
      );
    });
  });

  group('Weather mapping', () {
    test('WMO codes map to the expected topics', () {
      expect(topicForWeatherCode(61), ContextTopic.rain);
      expect(topicForWeatherCode(82), ContextTopic.rain);
      expect(topicForWeatherCode(95), ContextTopic.thunderstorm);
      expect(topicForWeatherCode(73), ContextTopic.snow);
      expect(topicForWeatherCode(0), ContextTopic.none);
    });

    test('thunderstorm outranks the wind that comes with it', () {
      expect(
        topicForConditions(weatherCode: 95, windKph: 90, temperatureC: 20),
        ContextTopic.thunderstorm,
      );
    });

    test('wind outranks plain rain', () {
      expect(
        topicForConditions(weatherCode: 61, windKph: 80),
        ContextTopic.strongWind,
      );
    });

    test('temperature only applies when nothing else fired', () {
      expect(
        topicForConditions(weatherCode: 0, temperatureC: 44),
        ContextTopic.extremeHeat,
      );
      expect(
        topicForConditions(weatherCode: 0, temperatureC: -3),
        ContextTopic.extremeCold,
      );
      expect(
        topicForConditions(weatherCode: 61, temperatureC: 44),
        ContextTopic.rain,
      );
    });

    test('calm clear weather produces no signal', () {
      expect(
        topicForConditions(weatherCode: 0, temperatureC: 22, windKph: 5),
        ContextTopic.none,
      );
    });
  });

  group('ContextualDhikrMatcher', () {
    const matcher = ContextualDhikrMatcher();

    final corpus = [
      d('rain_1', DhikrCategory.rain, tags: ['rain']),
      d('rain_2', DhikrCategory.rain, tags: ['rain'], timesRead: 5),
      d('distress_1', DhikrCategory.distress, tags: ['sadness', 'relief']),
      d('protect_1', DhikrCategory.morning, tags: ['protection']),
      d('salawat_1', DhikrCategory.salawat, tags: ['friday']),
    ];

    test('rain picks from the rain category', () {
      final s = matcher.match(ContextTopic.rain, corpus);
      expect(s, isNotNull);
      expect(s!.dhikr.category, DhikrCategory.rain);
      expect(s.reasonAr, isNotEmpty);
    });

    test('least-read first, so repeated signals rotate', () {
      final s = matcher.match(ContextTopic.rain, corpus);
      expect(s!.dhikr.id, 'rain_1'); // timesRead 0 beats rain_2's 5
    });

    test('calamity surfaces comfort, and names nothing', () {
      final s = matcher.match(ContextTopic.calamity, corpus);
      expect(s, isNotNull);
      expect(s!.dhikr.category, DhikrCategory.distress);
      expect(s.reasonAr, 'عند سماع ما يُحزن');
    });

    test('falls back to tags when no category matches', () {
      final s = matcher.match(ContextTopic.strongWind, corpus);
      expect(s, isNotNull);
      // No distress item carries 'protection', so the tag pool supplies it.
      expect(s!.dhikr.id, anyOf('distress_1', 'protect_1'));
    });

    test('stays silent for topics whose adhkar are not yet in the corpus', () {
      // Surfacing a loosely related dhikr for an eclipse is worse than
      // surfacing nothing.
      expect(matcher.match(ContextTopic.eclipse, corpus), isNull);
      expect(matcher.match(ContextTopic.earthquake, corpus), isNull);
    });

    test('stays silent for none, and for an empty corpus', () {
      expect(matcher.match(ContextTopic.none, corpus), isNull);
      expect(matcher.match(ContextTopic.rain, const []), isNull);
    });

    test('every mapped topic yields a non-empty templated reason', () {
      for (final t in ContextTopic.values) {
        if (t == ContextTopic.none || t.awaitingCorpus) continue;
        final s = matcher.match(t, corpus);
        if (s != null) expect(s.reasonAr.trim(), isNotEmpty);
      }
    });
  });
}
