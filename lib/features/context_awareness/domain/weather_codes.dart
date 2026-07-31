import 'context_topic.dart';

/// Maps a WMO present-weather code to a [ContextTopic].
///
/// WMO 4677 is what Open-Meteo returns, and Open-Meteo needs no API key —
/// which is what makes on-device fetching possible without shipping a secret
/// inside the APK.
ContextTopic topicForWeatherCode(int code) => switch (code) {
      45 || 48 => ContextTopic.fog,
      51 || 53 || 55 || 56 || 57 => ContextTopic.rain, // drizzle
      61 || 63 || 65 || 66 || 67 => ContextTopic.rain, // rain
      80 || 81 || 82 => ContextTopic.rain, // showers
      71 || 73 || 75 || 77 || 85 || 86 => ContextTopic.snow,
      95 || 96 || 99 => ContextTopic.thunderstorm,
      _ => ContextTopic.none,
    };

/// Thresholds for conditions WMO codes do not express.
class WeatherThresholds {
  const WeatherThresholds({
    this.strongWindKph = 60,
    this.extremeHeatC = 40,
    this.extremeColdC = 0,
  });

  final double strongWindKph;
  final double extremeHeatC;
  final double extremeColdC;
}

/// Resolves a single topic from current conditions.
///
/// Precedence is by how much the condition demands attention, not by how
/// unusual it is: a thunderstorm outranks the wind that comes with it, so the
/// user gets one signal rather than three.
ContextTopic topicForConditions({
  required int weatherCode,
  double? temperatureC,
  double? windKph,
  WeatherThresholds thresholds = const WeatherThresholds(),
}) {
  final byCode = topicForWeatherCode(weatherCode);
  if (byCode == ContextTopic.thunderstorm) return byCode;

  if (windKph != null && windKph >= thresholds.strongWindKph) {
    return ContextTopic.strongWind;
  }
  if (byCode != ContextTopic.none) return byCode;

  if (temperatureC != null) {
    if (temperatureC >= thresholds.extremeHeatC) return ContextTopic.extremeHeat;
    if (temperatureC <= thresholds.extremeColdC) return ContextTopic.extremeCold;
  }
  return ContextTopic.none;
}
