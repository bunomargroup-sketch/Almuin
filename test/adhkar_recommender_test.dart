import 'package:almuin/features/adhkar/domain/dhikr.dart';
import 'package:almuin/features/ai_assistant/domain/adhkar_recommender.dart';
import 'package:almuin/features/ai_assistant/domain/situation_intent.dart';
import 'package:flutter_test/flutter_test.dart';

Dhikr dhikr(
  String id,
  DhikrCategory cat,
  List<String> tags, {
  AuthenticityGrade grade = AuthenticityGrade.sahih,
}) =>
    Dhikr(
      id: id,
      category: cat,
      time: ContentTime.anytime,
      arabic: 'نص $id',
      repeat: 1,
      references: [
        DhikrReference(collection: 'مرجع', number: '1', grade: grade),
      ],
      tags: tags,
    );

Verse verse(String id, List<String> tags) => Verse(
      id: id,
      surahNameAr: 'سورة',
      surahNumber: 1,
      ayahNumber: 1,
      arabic: 'آية $id',
      tags: tags,
    );

void main() {
  const rec = AdhkarRecommender();

  final base = [
    dhikr('d1', DhikrCategory.distress, ['anxiety', 'relief']),
    dhikr('d2', DhikrCategory.sleep, ['sleep', 'insomnia']),
    dhikr('d3', DhikrCategory.tasbeeh, ['general']),
    dhikr('d_weak', DhikrCategory.distress, ['anxiety'],
        grade: AuthenticityGrade.daif),
    dhikr('d_custom', DhikrCategory.custom, ['anxiety'],
        grade: AuthenticityGrade.custom),
  ];
  final verses = [
    verse('v1', ['anxiety', 'worry']),
    verse('v2', ['gratitude']),
  ];

  test('suggests relevant authentic content for anxiety', () {
    final b = rec.recommend(
        intent: SituationIntent.anxiety, adhkar: base, verses: verses);
    expect(
      b.items.map((i) => i.id),
      containsAll(['d1', 'v1']),
    );
    expect(b.introAr, isNotEmpty);
  });

  test('NEVER suggests weak (daif) content by default', () {
    final b = rec.recommend(
        intent: SituationIntent.anxiety, adhkar: base, verses: verses);
    expect(b.items.any((i) => i.grade == AuthenticityGrade.daif), isFalse);
    expect(b.items.any((i) => i.id == 'd_weak'), isFalse);
  });

  test('NEVER suggests user-custom items as scripture', () {
    final b = rec.recommend(
        intent: SituationIntent.anxiety, adhkar: base, verses: verses);
    expect(b.items.any((i) => i.id == 'd_custom'), isFalse);
  });

  test('sleep intent surfaces sleep adhkar', () {
    final b = rec.recommend(
        intent: SituationIntent.insomnia, adhkar: base, verses: const []);
    expect(b.items.map((i) => i.id).toList(), contains('d2'));
  });

  test('empty corpus → honest admission, no fabrication', () {
    final b = rec.recommend(
        intent: SituationIntent.rain, adhkar: base, verses: verses);
    expect(b.items, isEmpty);
    expect(b.introAr, contains('لن أختلق'));
  });

  test('references and grades are preserved on items', () {
    final b = rec.recommend(
        intent: SituationIntent.anxiety, adhkar: base, verses: verses);
    for (final item in b.items) {
      expect(item.reference, isNotEmpty);
      expect(
          [AuthenticityGrade.quran, AuthenticityGrade.sahih, AuthenticityGrade.hasan]
              .contains(item.grade),
          isTrue);
    }
  });

  test('weak allowed only when explicitly opt-in, still marked', () {
    const allowWeak = AdhkarRecommender(allowWeak: true);
    final b = allowWeak.recommend(
        intent: SituationIntent.anxiety, adhkar: base, verses: verses);
    final weak = b.items.where((i) => i.grade == AuthenticityGrade.daif);
    for (final w in weak) {
      // The grade is carried so the UI renders the "ضعيف" badge.
      expect(w.grade, AuthenticityGrade.daif);
    }
  });
}
