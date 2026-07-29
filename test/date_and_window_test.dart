import 'package:almuin/core/utils/date_utils_x.dart';
import 'package:almuin/core/utils/hijri_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeWindow (quiet hours)', () {
    const night = TimeWindow(21 * 60 + 30, 5 * 60 + 30); // 21:30 → 05:30

    test('inside a midnight-wrapping window', () {
      expect(night.contains(DateTime(2026, 7, 29, 23, 0)), isTrue);
      expect(night.contains(DateTime(2026, 7, 29, 3, 15)), isTrue);
      expect(night.contains(DateTime(2026, 7, 30, 5, 29)), isTrue);
    });

    test('outside the window', () {
      expect(night.contains(DateTime(2026, 7, 29, 12, 0)), isFalse);
      expect(night.contains(DateTime(2026, 7, 29, 21, 0)), isFalse);
      expect(night.contains(DateTime(2026, 7, 29, 6, 0)), isFalse);
    });

    test('nextExit returns the following 05:30 same or next day', () {
      final late = DateTime(2026, 7, 29, 23, 0);
      expect(night.nextExit(late), DateTime(2026, 7, 30, 5, 30));
      final early = DateTime(2026, 7, 29, 2, 0);
      expect(night.nextExit(early), DateTime(2026, 7, 29, 5, 30));
    });

    test('non-wrapping window', () {
      const lunch = TimeWindow(12 * 60, 13 * 60);
      expect(lunch.contains(DateTime(2026, 7, 29, 12, 30)), isTrue);
      expect(lunch.contains(DateTime(2026, 7, 29, 13, 30)), isFalse);
      expect(lunch.nextExit(DateTime(2026, 7, 29, 12, 30)),
          DateTime(2026, 7, 29, 13, 0));
    });
  });

  group('dayKey / HijriInfo flags', () {
    test('dayKey format', () {
      expect(DateTime(2026, 7, 5).dayKey, '2026-07-05');
    });

    test('Eid flags', () {
      const eidFitr =
          HijriInfo(year: 1447, month: 10, day: 1, isFriday: false);
      expect(eidFitr.isEidFitr, isTrue);
      expect(eidFitr.isEid, isTrue);
      expect(eidFitr.isRamadan, isFalse);

      const eidAdha =
          HijriInfo(year: 1447, month: 12, day: 10, isFriday: false);
      expect(eidAdha.isEidAdha, isTrue);

      const lastTen =
          HijriInfo(year: 1447, month: 9, day: 25, isFriday: false);
      expect(lastTen.isRamadan, isTrue);
      expect(lastTen.isLastTenOfRamadan, isTrue);
    });
  });
}
