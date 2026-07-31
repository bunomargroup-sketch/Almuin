import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings_service.dart';
import '../../../core/utils/hijri_utils.dart';
import '../../adhkar/presentation/adhkar_providers.dart';
import '../data/news_source.dart';
import '../data/weather_source.dart';
import '../domain/context_topic.dart';
import '../domain/contextual_matcher.dart';

/// Calendar topics need no network and no permission — they are derived from
/// the Hijri date the home screen already computes.
ContextTopic calendarTopic(DateTime now) {
  final h = hijriOf(now);
  if (h.isRamadan) return ContextTopic.ramadan;
  if (h.isAshura) return ContextTopic.ashura;
  // The ten days of Dhul-Hijjah.
  if (h.month == 12 && h.day <= 10) return ContextTopic.dhulHijjah;
  if (now.weekday == DateTime.friday) return ContextTopic.friday;
  return ContextTopic.none;
}

/// Picks the single topic worth acting on.
///
/// One suggestion a day, not three. Severity decides; a tie goes to the more
/// immediate source, since rain outside the window is more present to the user
/// than a calendar fact.
ContextTopic pickTopic({
  required ContextTopic weather,
  required ContextTopic news,
  required ContextTopic calendar,
}) {
  final ordered = [news, weather, calendar]
      .where((t) => t != ContextTopic.none && !t.awaitingCorpus)
      .toList();
  if (ordered.isEmpty) return ContextTopic.none;
  ordered.sort((a, b) => b.severity.index.compareTo(a.severity.index));
  return ordered.first;
}

final _weatherSourceProvider = Provider((_) => const WeatherSource());
final _newsSourceProvider = Provider((_) => const NewsSource());

/// The dhikr to surface for today's context, or null for silence.
///
/// Silence is the common and correct outcome: clear weather, ordinary news,
/// an unremarkable day. Nothing here ever throws — a failed fetch degrades to
/// [ContextTopic.none], because the app is offline-first and a weather
/// hiccup must not disturb the home screen.
final contextSuggestionProvider =
    FutureProvider<ContextSuggestion?>((ref) async {
  final settings = ref.watch(settingsProvider);

  var weather = ContextTopic.none;
  if (settings.contextWeather && settings.hasLocation) {
    weather = await ref.read(_weatherSourceProvider).currentTopic(
          latitude: settings.latitude!,
          longitude: settings.longitude!,
        );
  }

  var news = ContextTopic.none;
  if (settings.contextNews) {
    news = await ref.read(_newsSourceProvider).topicFor();
  }

  final topic = pickTopic(
    weather: weather,
    news: news,
    calendar: calendarTopic(DateTime.now()),
  );
  if (topic == ContextTopic.none) return null;

  final corpus = await ref.watch(allAdhkarProvider.future);
  return const ContextualDhikrMatcher().match(topic, corpus);
});
