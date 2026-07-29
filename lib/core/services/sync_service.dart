import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/adhkar/domain/dhikr.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';
import 'app_database.dart';
import 'settings_service.dart';

/// Pull-based content sync: Supabase → SQLite, incremental via `updated_at`.
///
/// Trust model (see docs/DATA_SOURCES.md):
/// * Content tables on Supabase are curated/moderated server-side — the app
///   never ingests user-generated or scraped Islamic content.
/// * Anything synced is *upserted*, so the verified bundled seed always has a
///   truthful baseline and cloud content can only refine or extend it.
/// * Fully optional: without network the app keeps working forever offline.
class SyncService {
  SyncService(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;

  bool get _enabled => AppConfig.supabaseEnabled;

  Future<SyncResult> syncContent() async {
    if (!_enabled) return SyncResult.skipped('no-credentials');
    final online = await _isOnline();
    if (!online) return SyncResult.skipped('offline');

    try {
      final client = Supabase.instance.client;
      final lastAt =
          _prefs.getString(AppConstants.kLastSyncAt) ?? '1970-01-01T00:00:00Z';

      var pulled = 0;
      pulled += await _pullTable(client, 'adhkar', lastAt, (rows) async {
        for (final r in rows) {
          await _db.upsertDhikr(Dhikr.fromJson(_adhkarRowToJson(r)));
        }
      });

      await _prefs.setString(
          AppConstants.kLastSyncAt, DateTime.now().toUtc().toIso8601String());
      return SyncResult.ok(pulled);
    } catch (e, st) {
      logWarn('Sync failed', e, st);
      return SyncResult.failed('$e');
    }
  }

  Future<int> _pullTable(
    SupabaseClient client,
    String table,
    String since,
    Future<void> Function(List<Map<String, dynamic>> rows) apply,
  ) async {
    final rows =
        await client.from(table).select().gte('updated_at', since).order('updated_at');
    await apply((rows as List).cast<Map<String, dynamic>>());
    return rows.length;
  }

  /// Maps the Supabase `adhkar` row shape onto the same JSON the bundled seed
  /// uses, so one parser serves both sources.
  Map<String, dynamic> _adhkarRowToJson(Map<String, dynamic> r) => {
        'id': r['id'],
        'category': r['category'],
        'time': r['time_pref'],
        'arabic': r['arabic'],
        'transliteration': r['transliteration'],
        'translationEn': r['translation_en'],
        'meaningAr': r['meaning_ar'],
        'rewardAr': r['reward_ar'],
        'repeat': r['repeat'],
        'references':
            jsonDecode((r['refs_json'] as String?) ?? '[]') as List<dynamic>,
        'tags': jsonDecode((r['tags_json'] as String?) ?? '[]') as List<dynamic>,
      };

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

class SyncResult {
  const SyncResult._(this.status, this.message, this.pulled);
  final String status; // ok | skipped | failed
  final String message;
  final int pulled;

  factory SyncResult.ok(int pulled) => SyncResult._('ok', '', pulled);
  factory SyncResult.skipped(String why) => SyncResult._('skipped', why, 0);
  factory SyncResult.failed(String err) => SyncResult._('failed', err, 0);
}

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    AppDatabase.instance,
    ref.watch(sharedPreferencesProvider),
  ),
);

/// Trigger an opportunistic sync and report the outcome.
final syncNowProvider =
    FutureProvider.autoDispose<SyncResult>((ref) => ref.watch(syncServiceProvider).syncContent());
