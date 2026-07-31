import 'dart:io';

import 'package:almuin/features/adhkar/domain/dhikr.dart';
import 'package:almuin/features/ai_assistant/domain/adhkar_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

/// Encodes the AI safety contract as executable checks.
///
/// Most of this is asserted against source text rather than behaviour, which
/// is unusual — but the contract here is about what the code is *allowed to
/// contain*, not only what it computes. "The model may not return prose" is
/// only true while there is no prose field to return; the cheapest way to keep
/// that true is to fail the build when one reappears.
void main() {
  late String edgeFn;
  late String client;
  late String schema;

  setUpAll(() {
    edgeFn = File('supabase/functions/ai-assistant/index.ts').readAsStringSync();
    client = File('lib/features/ai_assistant/data/remote_ai_service.dart')
        .readAsStringSync();
    schema = File('supabase/schema.sql').readAsStringSync();
  });

  group('the model returns ids and nothing else', () {
    test('no free-text field survives anywhere in the AI path', () {
      // The S4 finding: a single free-form string rendered under a
      // "verified sources" footer. It was removed rather than filtered,
      // because a filter is only as good as its denylist.
      for (final needle in ['empathy', 'Empathy']) {
        expect(edgeFn.contains(needle), isFalse,
            reason: 'edge function reintroduced "$needle"');
        expect(client.contains(needle), isFalse,
            reason: 'client reintroduced "$needle"');
      }
    });

    test('the edge function response schema is ids-only', () {
      expect(edgeFn.contains('selected_ids'), isTrue);
      // A prose key would show up as a quoted JSON field next to selected_ids.
      for (final banned in ['"message"', '"text"', '"reply"', '"intro"']) {
        expect(edgeFn.contains(banned), isFalse,
            reason: 'edge function returns a prose field $banned');
      }
    });

    test('one bad id voids the whole response', () {
      expect(edgeFn.contains('rawIds.some'), isTrue,
          reason: 'the subset gate must reject the entire response, not '
              'silently filter the bad ids out');
    });
  });

  group('scripture never leaves the device', () {
    test('the client does not send candidate Arabic text to the function', () {
      final body = client.substring(
        client.indexOf('body: {'),
        client.indexOf('final data = res.data'),
      );
      expect(body.contains("'arabic'"), isFalse,
          reason: 'candidate Arabic text must not be sent to a third party — '
              'the model ranks on reference, grade and tags');
      expect(body.contains("'tags'"), isTrue,
          reason: 'tags are the semantic signal that replaces the text');
    });

    test('the subset gate is enforced client-side too', () {
      expect(client.contains('candidateIds.contains'), isTrue);
    });
  });

  group('tags reach the ranker', () {
    test('fromDhikr carries tags through', () {
      final d = Dhikr(
        id: 'x',
        category: DhikrCategory.distress,
        time: ContentTime.anytime,
        arabic: 'نص',
        repeat: 1,
        references: const [
          DhikrReference(
              collection: 'م', number: '1', grade: AuthenticityGrade.sahih),
        ],
        tags: const ['anxiety', 'relief'],
      );
      final item = RecommendationItem.fromDhikr(d);
      expect(item.tags, ['anxiety', 'relief']);
    });

    test('a verse item still has a tag list, even if empty', () {
      const item = RecommendationItem(
        id: 'v',
        arabic: 'نص',
        reference: 'البقرة ٢٠١',
        grade: AuthenticityGrade.quran,
      );
      expect(item.tags, isEmpty);
    });
  });

  group('cost metering', () {
    test('usage is capped before the paid call, not after', () {
      final bump = edgeFn.indexOf('bumpUsage(');
      final call = edgeFn.indexOf('api.openai.com');
      expect(bump, greaterThan(-1));
      expect(bump, lessThan(call),
          reason: 'the quota check must precede the OpenAI request');
    });

    test('ai_usage exists, is RLS-protected, and has no client policy', () {
      expect(schema.contains('create table if not exists public.ai_usage'), isTrue);
      expect(
          schema.contains('alter table public.ai_usage enable row level security'),
          isTrue);
      // Look for an actual policy targeting this table, not merely the
      // substring "ai_usage" (which also appears in its index name).
      expect(
          RegExp(r'create\s+policy[^;]*on\s+public\.ai_usage',
                  caseSensitive: false, dotAll: true)
              .hasMatch(schema),
          isFalse,
          reason: 'no client policy — a user must not be able to read, forge '
              'or reset their own counter');
    });

    test('the increment is atomic in SQL, not read-then-write in Deno', () {
      expect(schema.contains('function public.bump_ai_usage'), isTrue);
      expect(schema.contains('on conflict (user_id, day) do update'), isTrue,
          reason: 'concurrent requests would otherwise slip past the cap');
    });
  });

  group('privacy', () {
    test('the situation text is never persisted or logged', () {
      // The edge function may forward user_text to the model, but must not
      // write it anywhere. Any insert/log touching it is a defect.
      for (final banned in [
        'console.log(userText)',
        'insert.*user_text',
        'user_text.*insert',
      ]) {
        expect(RegExp(banned).hasMatch(edgeFn), isFalse,
            reason: 'user situation text must not be stored or logged');
      }
    });
  });
}
