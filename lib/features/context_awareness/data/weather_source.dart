import '../domain/context_topic.dart';
import '../domain/weather_codes.dart';
import 'http_json.dart';

/// Current conditions at a coarse location, from Open-Meteo.
///
/// Open-Meteo needs **no API key**, which is the reason it was chosen: any
/// keyed weather service would mean shipping a secret inside the APK, where
/// anyone can extract it — the same problem the Supabase anon key already
/// has. Coordinates are sent at two decimal places (~1 km), enough for
/// weather and no more precise than the prayer-time calculation already is.
class WeatherSource {
  const WeatherSource();

  static const _host = 'api.open-meteo.com';
  static const _path = '/v1/forecast';

  Future<ContextTopic> currentTopic({
    required double latitude,
    required double longitude,
    WeatherThresholds thresholds = const WeatherThresholds(),
  }) async {
    final url = Uri.https(_host, _path, {
      'latitude': latitude.toStringAsFixed(2),
      'longitude': longitude.toStringAsFixed(2),
      'current': 'weather_code,temperature_2m,wind_speed_10m',
      'wind_speed_unit': 'kmh',
      'timezone': 'auto',
    });

    final json = await httpGetJson(url);
    final current = json?['current'];
    if (current is! Map) return ContextTopic.none;

    final code = (current['weather_code'] as num?)?.toInt();
    if (code == null) return ContextTopic.none;

    return topicForConditions(
      weatherCode: code,
      temperatureC: (current['temperature_2m'] as num?)?.toDouble(),
      windKph: (current['wind_speed_10m'] as num?)?.toDouble(),
      thresholds: thresholds,
    );
  }
}
