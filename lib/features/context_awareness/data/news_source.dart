import '../domain/context_topic.dart';
import '../domain/news_classifier.dart';
import 'http_json.dart';

/// Reads public RSS feeds and reduces them to a single [ContextTopic].
///
/// What leaves this class is one enum value. Headlines are parsed, classified
/// and dropped inside [topicFor]; they are never returned, stored, logged or
/// rendered. That is the contract described in `context_topic.dart`, and it is
/// what lets the app respond to the day without quoting anyone, naming any
/// party, or reproducing third-party text.
///
/// RSS was chosen over a news API for the same reason as Open-Meteo: no key,
/// so no secret ships inside the APK.
class NewsSource {
  const NewsSource({this.classifier = const NewsTopicClassifier()});

  final NewsTopicClassifier classifier;

  /// Feeds are keyless and public. Swap these for outlets you trust — the
  /// classifier is source-agnostic, and nothing from a feed is displayed, so
  /// the choice affects coverage rather than tone.
  static const List<String> defaultFeeds = [
    'https://feeds.bbci.co.uk/arabic/rss.xml',
    'https://feeds.bbci.co.uk/news/world/rss.xml',
  ];

  static final RegExp _title =
      RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true, caseSensitive: false);
  static final RegExp _cdata = RegExp(r'^\s*<!\[CDATA\[(.*?)\]\]>\s*$', dotAll: true);
  static final RegExp _tag = RegExp(r'<[^>]+>');

  /// Extracts headline strings from an RSS/Atom document.
  ///
  /// Visible for testing — a crude regex is adequate because the output is
  /// classified and discarded immediately, so a malformed title costs a missed
  /// signal rather than a wrong one. The first `<title>` is the channel name,
  /// not a headline, so it is skipped.
  static List<String> parseTitles(String xml) {
    final all = _title
        .allMatches(xml)
        .map((m) => m.group(1) ?? '')
        .map((t) {
          final cd = _cdata.firstMatch(t);
          return (cd != null ? cd.group(1)! : t).replaceAll(_tag, '').trim();
        })
        .where((t) => t.isNotEmpty)
        .toList();
    return all.length > 1 ? all.sublist(1) : const [];
  }

  /// One topic for the day, or [ContextTopic.none].
  Future<ContextTopic> topicFor({
    List<String> feeds = defaultFeeds,
    int maxHeadlinesPerFeed = 30,
  }) async {
    var best = ContextTopic.none;
    for (final feed in feeds) {
      final uri = Uri.tryParse(feed);
      if (uri == null) continue;
      final body = await httpGetBody(uri);
      if (body == null) continue;

      final titles = parseTitles(body).take(maxHeadlinesPerFeed);
      final topic = classifier.classifyFeed(titles);
      // `titles` goes out of scope here and is never retained.
      if (topic == ContextTopic.none) continue;
      if (best == ContextTopic.none ||
          topic.severity.index > best.severity.index) {
        best = topic;
      }
    }
    return best;
  }
}
