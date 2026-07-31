import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../utils/date_utils_x.dart';

/// How pushy the reminder engine is overall.
enum FrequencyLevel { low, normal, high }

enum ArabicFontKey { amiri, notoNaskh, cairo }

/// Immutable, JSON-persisted user preferences.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('ar'),
    this.fontScale = 1.0,
    this.arabicFontKey = ArabicFontKey.amiri,
    this.notificationSound = true,
    this.notificationVibration = true,
    this.ttsEnabled = true,
    this.travelMode = false,
    this.batterySaver = false,
    this.contextWeather = true,
    this.contextNews = false,
    this.quietStartMinutes = 21 * 60 + 30,
    this.quietEndMinutes = 5 * 60 + 30,
    this.globalFrequency = FrequencyLevel.normal,
    this.onboardingComplete = false,
    this.latitude,
    this.longitude,
    this.locationLabel = '',
    this.calculationMethod = 'muslim_world_league',
  });

  final ThemeMode themeMode;
  final Locale locale;
  final double fontScale;
  final ArabicFontKey arabicFontKey;

  // Notification style
  final bool notificationSound;
  final bool notificationVibration;
  final bool ttsEnabled;

  // Smart-context toggles
  final bool travelMode;
  final bool batterySaver;

  /// Suggest a dhikr from local weather (rain, storm, strong wind, extreme
  /// heat or cold). On by default: it reuses the coarse coordinates already
  /// held for prayer times and adds no new privacy surface.
  final bool contextWeather;

  /// Suggest a dhikr of patience when the day's news carries human loss.
  ///
  /// Off by default, deliberately. It is the only feature that reaches out to
  /// a news source, and responding to world events — however carefully — is a
  /// choice the user should make rather than inherit.
  final bool contextNews;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final FrequencyLevel globalFrequency;

  final bool onboardingComplete;

  // Location for prayer times (coarse; user-granted or chosen city).
  final double? latitude;
  final double? longitude;
  final String locationLabel;
  final String calculationMethod;

  TimeWindow get quietHours =>
      TimeWindow(quietStartMinutes, quietEndMinutes);

  bool get hasLocation => latitude != null && longitude != null;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    double? fontScale,
    ArabicFontKey? arabicFontKey,
    bool? notificationSound,
    bool? notificationVibration,
    bool? ttsEnabled,
    bool? travelMode,
    bool? batterySaver,
    bool? contextWeather,
    bool? contextNews,
    int? quietStartMinutes,
    int? quietEndMinutes,
    FrequencyLevel? globalFrequency,
    bool? onboardingComplete,
    double? latitude,
    double? longitude,
    String? locationLabel,
    String? calculationMethod,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
        fontScale: fontScale ?? this.fontScale,
        arabicFontKey: arabicFontKey ?? this.arabicFontKey,
        notificationSound: notificationSound ?? this.notificationSound,
        notificationVibration:
            notificationVibration ?? this.notificationVibration,
        ttsEnabled: ttsEnabled ?? this.ttsEnabled,
        travelMode: travelMode ?? this.travelMode,
        batterySaver: batterySaver ?? this.batterySaver,
        contextWeather: contextWeather ?? this.contextWeather,
        contextNews: contextNews ?? this.contextNews,
        quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
        quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
        globalFrequency: globalFrequency ?? this.globalFrequency,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        locationLabel: locationLabel ?? this.locationLabel,
        calculationMethod: calculationMethod ?? this.calculationMethod,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'locale': locale.languageCode,
        'fontScale': fontScale,
        'arabicFontKey': arabicFontKey.name,
        'notificationSound': notificationSound,
        'notificationVibration': notificationVibration,
        'ttsEnabled': ttsEnabled,
        'travelMode': travelMode,
        'batterySaver': batterySaver,
        'contextWeather': contextWeather,
        'contextNews': contextNews,
        'quietStartMinutes': quietStartMinutes,
        'quietEndMinutes': quietEndMinutes,
        'globalFrequency': globalFrequency.name,
        'onboardingComplete': onboardingComplete,
        'latitude': latitude,
        'longitude': longitude,
        'locationLabel': locationLabel,
        'calculationMethod': calculationMethod,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        themeMode: ThemeMode.values.asNameMap()[j['themeMode'] as String?] ??
            ThemeMode.system,
        locale: Locale(j['locale'] as String? ?? 'ar'),
        fontScale: (j['fontScale'] as num?)?.toDouble() ?? 1.0,
        arabicFontKey: ArabicFontKey.values
                .asNameMap()[j['arabicFontKey'] as String?] ??
            ArabicFontKey.amiri,
        notificationSound: j['notificationSound'] as bool? ?? true,
        notificationVibration: j['notificationVibration'] as bool? ?? true,
        ttsEnabled: j['ttsEnabled'] as bool? ?? true,
        travelMode: j['travelMode'] as bool? ?? false,
        batterySaver: j['batterySaver'] as bool? ?? false,
        contextWeather: j['contextWeather'] as bool? ?? true,
        contextNews: j['contextNews'] as bool? ?? false,
        quietStartMinutes: (j['quietStartMinutes'] as num?)?.toInt() ?? 1290,
        quietEndMinutes: (j['quietEndMinutes'] as num?)?.toInt() ?? 330,
        globalFrequency: FrequencyLevel.values
                .asNameMap()[j['globalFrequency'] as String?] ??
            FrequencyLevel.normal,
        onboardingComplete: j['onboardingComplete'] as bool? ?? false,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        locationLabel: j['locationLabel'] as String? ?? '',
        calculationMethod:
            j['calculationMethod'] as String? ?? 'muslim_world_league',
      );
}

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final raw = _prefs.getString(AppConstants.kSettingsJson);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  void _save(AppSettings next) {
    state = next;
    _prefs.setString(AppConstants.kSettingsJson, jsonEncode(next.toJson()));
  }

  void update(AppSettings Function(AppSettings) change) => _save(change(state));

  Future<void> setLocation(double lat, double lng, String label) async {
    _save(state.copyWith(
        latitude: lat, longitude: lng, locationLabel: label));
  }

  Future<void> completeOnboarding() async {
    update((s) => s.copyWith(onboardingComplete: true));
  }
}
