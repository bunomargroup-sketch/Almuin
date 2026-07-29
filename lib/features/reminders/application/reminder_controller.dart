import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/settings_service.dart';
import 'reminder_engine.dart';
import '../domain/reminder_models.dart';
import '../../adhkar/domain/dhikr.dart';

/// Reactive store of per-category reminder profiles (JSON-persisted).
final reminderProfilesProvider =
    NotifierProvider<ReminderProfilesNotifier, List<ReminderProfile>>(
  ReminderProfilesNotifier.new,
);

class ReminderProfilesNotifier extends Notifier<List<ReminderProfile>> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  List<ReminderProfile> build() {
    final raw = _prefs.getString(AppConstants.kReminderProfilesJson);
    if (raw == null) return ReminderProfile.defaults();
    try {
      return [
        for (final j in jsonDecode(raw) as List<dynamic>)
          ReminderProfile.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      return ReminderProfile.defaults();
    }
  }

  void _save(List<ReminderProfile> next) {
    state = next;
    _prefs.setString(
      AppConstants.kReminderProfilesJson,
      jsonEncode([for (final p in next) p.toJson()]),
    );
  }

  void setAll(List<ReminderProfile> profiles) => _save(profiles);

  void toggle(DhikrCategory category, bool enabled) {
    _save([
      for (final p in state)
        if (p.category == category) p.copyWith(enabled: enabled) else p,
    ]);
  }

  void setFrequency(DhikrCategory category, FrequencyLevel level) {
    _save([
      for (final p in state)
        if (p.category == category) p.copyWith(frequency: level) else p,
    ]);
  }
}

/// One-shot planning trigger; UI calls [replan] after relevant changes.
final reminderPlannerProvider = Provider<ReminderPlanner>(
  (_) => const ReminderPlanner(),
);

class ReminderPlanner {
  const ReminderPlanner();

  /// Profiles and settings are already persisted synchronously by their
  /// providers, so the (headless-safe) engine can simply re-read them.
  Future<void> replan() => ReminderEngine.rescheduleComingDaysHeadless();
}
