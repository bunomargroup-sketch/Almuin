import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the du'ā' corpus pipeline.
///
/// The manifest lists 162 supplications by reference only — the Arabic text is
/// deliberately empty until it is filled from an authoritative vocalised
/// corpus. These tests exist so that an unsourced or half-sourced item can
/// never reach the shipped seed by accident: if someone wires the manifest
/// into seeding before the texts are filled, the build fails here rather than
/// putting incomplete scripture on a user's screen.
void main() {
  late Map<String, dynamic> manifest;
  late List<dynamic> manifestItems;
  late List<dynamic> seedItems;

  setUpAll(() {
    manifest = jsonDecode(File('assets/data/dua_manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    manifestItems = manifest['items'] as List<dynamic>;
    seedItems = (jsonDecode(File('assets/data/adhkar_seed.json').readAsStringSync())
        as Map<String, dynamic>)['items'] as List<dynamic>;
  });

  group('du\'ā\' manifest integrity', () {
    test('holds 58 Qur\'anic and 104 prophetic supplications', () {
      expect(manifestItems.length, 162);
      expect(manifestItems.where((e) => e['source'] == 'quran').length, 58);
      expect(manifestItems.where((e) => e['source'] == 'sunnah').length, 104);
    });

    test('ids are unique', () {
      final ids = manifestItems.map((e) => e['id'] as String).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every item carries a full reference', () {
      for (final raw in manifestItems) {
        final e = raw as Map<String, dynamic>;
        final ref = e['reference'] as Map<String, dynamic>?;
        expect(ref, isNotNull, reason: '${e['id']} has no reference');
        expect((ref!['collection'] as String?) ?? '', isNotEmpty,
            reason: '${e['id']} has no collection');
        expect((ref['number'] as String?) ?? '', isNotEmpty,
            reason: '${e['id']} has no number');
        expect((ref['grade'] as String?) ?? '', isNotEmpty,
            reason: '${e['id']} has no grade');
      }
    });

    test('an item has text if and only if it is no longer pending', () {
      for (final raw in manifestItems) {
        final e = raw as Map<String, dynamic>;
        final hasText = ((e['arabic'] as String?) ?? '').trim().isNotEmpty;
        final pending = e['textStatus'] == 'pending';
        expect(hasText, !pending,
            reason: '${e['id']}: textStatus=${e['textStatus']} but '
                'arabic is ${hasText ? 'filled' : 'empty'} — the two must agree');
      }
    });

    test('every Qur\'anic item cites a surah and ayah', () {
      final quranic = manifestItems.where((e) => e['source'] == 'quran');
      for (final raw in quranic) {
        final e = raw as Map<String, dynamic>;
        final ref = e['reference'] as Map<String, dynamic>;
        expect(ref['grade'], 'quran', reason: '${e['id']}');
        // "<surah> <ayah>" — e.g. "البقرة 201" or "طه 25-26".
        expect(RegExp(r'\s\d').hasMatch(ref['number'] as String), isTrue,
            reason: '${e['id']} reference "${ref['number']}" has no ayah number');
      }
    });
  });

  group('shipped seed safety', () {
    test('no seeded dhikr has empty Arabic text', () {
      for (final raw in seedItems) {
        final e = raw as Map<String, dynamic>;
        expect(((e['arabic'] as String?) ?? '').trim(), isNotEmpty,
            reason: '${e['id']} would ship with no text');
      }
    });

    test('no seeded dhikr carries an unresolved grade', () {
      const valid = {'quran', 'sahih', 'hasan', 'daif', 'custom'};
      for (final raw in seedItems) {
        final e = raw as Map<String, dynamic>;
        for (final r in (e['references'] as List<dynamic>? ?? const [])) {
          final grade = (r as Map<String, dynamic>)['grade'];
          expect(valid.contains(grade), isTrue,
              reason: '${e['id']} has grade "$grade"; "pending" and unknown '
                  'grades must never ship');
        }
      }
    });

    test('nothing from the manifest has leaked into the seed untranslated', () {
      // Belt and braces: if manifest ids ever appear in the seed, they must
      // have real text by then.
      final seedById = {
        for (final raw in seedItems)
          (raw as Map<String, dynamic>)['id'] as String: raw,
      };
      for (final raw in manifestItems) {
        final e = raw as Map<String, dynamic>;
        final seeded = seedById[e['id'] as String];
        if (seeded == null) continue;
        expect(((seeded['arabic'] as String?) ?? '').trim(), isNotEmpty,
            reason: '${e['id']} is seeded but still has no text');
      }
    });
  });
}
