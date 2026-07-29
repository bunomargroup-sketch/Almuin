import 'package:almuin/features/ai_assistant/domain/situation_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const clf = SituationClassifier();

  group('Arabic situations', () {
    test('stress', () {
      expect(clf.classify('أشعر بتوتر شديد اليوم').intent,
          SituationIntent.anxiety);
    });

    test('insomnia', () {
      expect(clf.classify('لا أستطيع النوم منذ أيام').intent,
          SituationIntent.insomnia);
    });

    test('travel', () {
      expect(clf.classify('أنا مسافر غدًا بإذن الله').intent,
          SituationIntent.travel);
    });

    test('worry', () {
      expect(clf.classify('عندي همّ كبير').intent, SituationIntent.worry);
    });

    test('gratitude', () {
      expect(clf.classify('الحمد لله أشعر بالامتنان لنعم الله').intent,
          SituationIntent.gratitude);
    });

    test('anger', () {
      expect(clf.classify('أنا غاضب جدًا').intent, SituationIntent.anger);
    });

    test('illness (relational)', () {
      expect(clf.classify('أمي مريضة في المستشفى').intent,
          SituationIntent.illness);
    });

    test('exam', () {
      expect(clf.classify('عندي امتحان بكرة').intent, SituationIntent.exam);
    });

    test('financial hardship', () {
      expect(clf.classify('فصلت من وظيفتي وأنا قلق على الرزق').intent,
          isIn([SituationIntent.financialHardship, SituationIntent.anxiety]));
    });

    test('weird text falls back to general with low confidence', () {
      final m = clf.classify('الطقس حار');
      expect(m.intent, SituationIntent.general);
      expect(m.confidence, lessThan(0.5));
    });
  });

  group('English situations', () {
    test('stressed', () {
      expect(clf.classify('I feel stressed and anxious').intent,
          SituationIntent.anxiety);
    });

    test('cannot sleep', () {
      expect(clf.classify("I can't sleep at night").intent,
          SituationIntent.insomnia);
    });

    test('traveling', () {
      expect(clf.classify('I am traveling tomorrow').intent,
          SituationIntent.travel);
    });

    test('lost job', () {
      expect(clf.classify('I lost my job last week').intent,
          SituationIntent.financialHardship);
    });

    test('grateful', () {
      expect(clf.classify('I feel so grateful today').intent,
          SituationIntent.gratitude);
    });

    test('tashkeel & letter variants are normalized', () {
      expect(clf.classify('أَشْعُرُ بِالْقَلَقِ').intent,
          SituationIntent.anxiety);
      expect(clf.classify('أنا مهمومة').intent, SituationIntent.worry);
    });
  });
}
