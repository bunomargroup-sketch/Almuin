import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/adhkar/domain/dhikr.dart';
import '../constants/app_constants.dart';
import '../utils/date_utils_x.dart';
import '../utils/logger.dart';

/// Offline-first SQLite store (Clean Architecture: infrastructure layer).
///
/// Everything the app shows — adhkar, verses, hadiths, reminder history,
/// tasbeeh, achievements — lives here first. Supabase is only a *source of
/// truth refresh*; the UI never reads the network directly.
///
/// Also reachable from the notification background isolate, hence singleton.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _name = 'almuin.db';
  static const _version = 1;
  static const seedVersion = 1;

  Database? _db;
  Future<Database> get db async => _db ??= await _open();

  Future<void> warmUp() async => db;

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _name);
    return openDatabase(
      path,
      version: _version,
      onCreate: (d, v) async => _createSchema(d),
    );
  }

  static Future<void> _createSchema(Database d) async {
    await d.execute('''
      CREATE TABLE adhkar(
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        time_pref TEXT NOT NULL DEFAULT 'anytime',
        arabic TEXT NOT NULL,
        transliteration TEXT NOT NULL DEFAULT '',
        translation_en TEXT NOT NULL DEFAULT '',
        meaning_ar TEXT NOT NULL DEFAULT '',
        reward_ar TEXT NOT NULL DEFAULT '',
        repeat INTEGER NOT NULL DEFAULT 1,
        grade TEXT NOT NULL DEFAULT 'custom',
        refs_json TEXT NOT NULL DEFAULT '[]',
        tags_json TEXT NOT NULL DEFAULT '[]',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        times_read INTEGER NOT NULL DEFAULT 0,
        last_read_at TEXT,
        updated_at TEXT
      )''');
    await d.execute('''
      CREATE TABLE verses(
        id TEXT PRIMARY KEY,
        surah_name_ar TEXT NOT NULL,
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        arabic TEXT NOT NULL,
        translation_en TEXT NOT NULL DEFAULT '',
        tafsir_brief_ar TEXT NOT NULL DEFAULT '',
        tags_json TEXT NOT NULL DEFAULT '[]'
      )''');
    await d.execute('''
      CREATE TABLE hadiths(
        id TEXT PRIMARY KEY,
        arabic TEXT NOT NULL,
        translation_en TEXT NOT NULL DEFAULT '',
        benefit_ar TEXT NOT NULL DEFAULT '',
        collection TEXT NOT NULL,
        number TEXT NOT NULL,
        grade TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]'
      )''');
    await d.execute('''
      CREATE TABLE reminder_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        notification_id INTEGER,
        dhikr_id TEXT,
        category TEXT,
        title TEXT,
        body_preview TEXT,
        reason TEXT,
        scheduled_at TEXT NOT NULL,
        delivered_at TEXT,
        completed_at TEXT,
        snoozed_until TEXT,
        status TEXT NOT NULL DEFAULT 'scheduled' -- scheduled|delivered|completed|snoozed|cancelled
      )''');
    await d.execute('CREATE INDEX idx_events_day ON reminder_events(scheduled_at)');
    await d.execute('''
      CREATE TABLE tasbeeh_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dhikr_id TEXT,
        dhikr_text TEXT NOT NULL,
        target INTEGER NOT NULL,
        count INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT
      )''');
    await d.execute('''
      CREATE TABLE tasbeeh_daily(
        day TEXT PRIMARY KEY,
        total_count INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE progress_daily(
        day TEXT PRIMARY KEY,
        completed INTEGER NOT NULL DEFAULT 0,
        snoozed INTEGER NOT NULL DEFAULT 0,
        adhkar_read INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE achievements(
        id TEXT PRIMARY KEY,
        unlocked_at TEXT NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE meta(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
  }

  // ------------------------------------------------------------------
  // Seeding (bundled, reviewed content) — runs once per seed version.
  // Uses sqflite batches (never the Database inside a transaction).
  // ------------------------------------------------------------------
  Future<void> ensureSeeded() async {
    final d = await db;
    final current = int.tryParse(await _metaGet('seed_version') ?? '0') ?? 0;
    if (current >= seedVersion) return;

    WidgetsFlutterBinding.ensureInitialized();

    final adhkarItems = await _loadSeedItems('assets/data/adhkar_seed.json');
    final verseItems = await _loadSeedItems('assets/data/verses_seed.json');
    final hadithItems = await _loadSeedItems('assets/data/hadith_seed.json');

    final batch = d.batch();
    for (final item in adhkarItems) {
      batch.insert('adhkar', Dhikr.fromJson(item).toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final item in verseItems) {
      final v = Verse.fromJson(item);
      batch.insert('verses', {
        'id': v.id,
        'surah_name_ar': v.surahNameAr,
        'surah_number': v.surahNumber,
        'ayah_number': v.ayahNumber,
        'arabic': v.arabic,
        'translation_en': v.translationEn,
        'tafsir_brief_ar': v.tafsirBriefAr,
        'tags_json': jsonEncode(v.tags),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final item in hadithItems) {
      final h = DailyHadith.fromJson(item);
      batch.insert('hadiths', {
        'id': h.id,
        'arabic': h.arabic,
        'translation_en': h.translationEn,
        'benefit_ar': h.benefitAr,
        'collection': h.collection,
        'number': h.number,
        'grade': h.grade.name,
        'tags_json': jsonEncode(h.tags),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    await _metaSet('seed_version', '$seedVersion');
    logInfo('Content seeded (v$seedVersion): '
        '${adhkarItems.length} adhkar, ${verseItems.length} verses, '
        '${hadithItems.length} hadiths');
  }

  Future<List<Map<String, dynamic>>> _loadSeedItems(String asset) async {
    final raw = await rootBundle.loadString(asset);
    final items = (jsonDecode(raw) as Map<String, dynamic>)['items']
        as List<dynamic>;
    return items.cast<Map<String, dynamic>>();
  }

  // ------------------------------------------------------------------
  // Adhkar queries
  // ------------------------------------------------------------------
  Future<List<Dhikr>> adhkar({DhikrCategory? category, String? query}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (category != null) {
      where.add('category = ?');
      args.add(category.name);
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add('(arabic LIKE ? OR translation_en LIKE ? OR meaning_ar LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }
    final rows = await d.query(
      'adhkar',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'category, rowid',
    );
    return rows.map(Dhikr.fromRow).toList();
  }

  Future<Dhikr?> dhikrById(String id) async {
    final d = await db;
    final rows = await d.query('adhkar', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Dhikr.fromRow(rows.first);
  }

  Future<void> upsertDhikr(Dhikr dhikr) async {
    final d = await db;
    await d.insert('adhkar', dhikr.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> setFavorite(String id, bool fav) async {
    final d = await db;
    return d.update('adhkar', {'is_favorite': fav ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markDhikrRead(String id, {int times = 1}) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE adhkar SET times_read = times_read + ?, last_read_at = ? WHERE id = ?',
      [times, DateTime.now().toIso8601String(), id],
    );
    await bumpProgressAdhkarRead();
  }

  Future<List<Dhikr>> favorites() async {
    final d = await db;
    final rows = await d.query('adhkar',
        where: 'is_favorite = 1', orderBy: 'last_read_at DESC');
    return rows.map(Dhikr.fromRow).toList();
  }

  Future<List<Dhikr>> mostRead({int limit = 5}) async {
    final d = await db;
    final rows = await d.query('adhkar',
        where: 'times_read > 0', orderBy: 'times_read DESC', limit: limit);
    return rows.map(Dhikr.fromRow).toList();
  }

  // ------------------------------------------------------------------
  // Verses & hadiths
  // ------------------------------------------------------------------
  Future<List<Verse>> verses() async {
    final d = await db;
    final rows = await d.query('verses', orderBy: 'rowid');
    return rows
        .map((r) => Verse.fromJson({
              'id': r['id'],
              'surahNameAr': r['surah_name_ar'],
              'surahNumber': r['surah_number'],
              'ayahNumber': r['ayah_number'],
              'arabic': r['arabic'],
              'translationEn': r['translation_en'],
              'tafsirBriefAr': r['tafsir_brief_ar'],
              'tags': jsonDecode((r['tags_json'] as String?) ?? '[]'),
            }))
        .toList();
  }

  Future<List<DailyHadith>> hadiths() async {
    final d = await db;
    final rows = await d.query('hadiths', orderBy: 'rowid');
    return rows
        .map((r) => DailyHadith.fromJson({
              'id': r['id'],
              'arabic': r['arabic'],
              'translationEn': r['translation_en'],
              'benefitAr': r['benefit_ar'],
              'collection': r['collection'],
              'number': r['number'],
              'grade': r['grade'],
              'tags': jsonDecode((r['tags_json'] as String?) ?? '[]'),
            }))
        .toList();
  }

  // ------------------------------------------------------------------
  // Reminder events + daily progress
  // ------------------------------------------------------------------
  Future<int> insertReminderEvent(Map<String, Object?> event) async {
    final d = await db;
    return d.insert('reminder_events', event);
  }

  Future<Map<String, Object?>?> eventByNotificationId(int notifId) async {
    final d = await db;
    final rows = await d.query('reminder_events',
        where: 'notification_id = ?',
        whereArgs: [notifId],
        orderBy: 'id DESC',
        limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markDelivered(int notifId) async {
    final d = await db;
    await d.update(
      'reminder_events',
      {
        'status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String()
      },
      where: 'notification_id = ? AND status = ?',
      whereArgs: [notifId, 'scheduled'],
    );
  }

  Future<void> completeByNotificationId(int notifId) async {
    final d = await db;
    final now = DateTime.now();
    final rows = await d.query('reminder_events',
        where: 'notification_id = ?',
        whereArgs: [notifId],
        orderBy: 'id DESC',
        limit: 1);
    if (rows.isEmpty) return;
    final event = rows.first;
    await d.update(
      'reminder_events',
      {'status': 'completed', 'completed_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [event['id']],
    );
    await _bumpProgress(now.dayKey, completed: true);
    final dhikrId = event['dhikr_id'] as String?;
    if (dhikrId != null) await markDhikrRead(dhikrId);
  }

  Future<void> snoozeByNotificationId(int notifId, DateTime until) async {
    final d = await db;
    await d.update(
      'reminder_events',
      {'status': 'snoozed', 'snoozed_until': until.toIso8601String()},
      where: 'notification_id = ?',
      whereArgs: [notifId],
    );
    await _bumpProgress(DateTime.now().dayKey, snoozed: true);
  }

  /// Removes still-pending events for a day before a fresh planning pass, so
  /// analytics denominators stay exact across repeated re-schedules.
  Future<void> deleteScheduledEventsFor(String day) async {
    final d = await db;
    await d.delete(
      'reminder_events',
      where: "substr(scheduled_at,1,10) = ? AND status = 'scheduled'",
      whereArgs: [day],
    );
  }

  Future<void> _bumpProgress(String day,
      {bool completed = false, bool snoozed = false}) async {
    final d = await db;
    await d.rawInsert(
      'INSERT INTO progress_daily(day, completed, snoozed, adhkar_read) '
      'VALUES(?, ?, ?, 0) '
      'ON CONFLICT(day) DO UPDATE SET '
      'completed = completed + ?, snoozed = snoozed + ?',
      [
        day,
        completed ? 1 : 0,
        snoozed ? 1 : 0,
        completed ? 1 : 0,
        snoozed ? 1 : 0
      ],
    );
  }

  Future<void> bumpProgressAdhkarRead() async {
    final d = await db;
    final day = DateTime.now().dayKey;
    await d.rawInsert(
      'INSERT INTO progress_daily(day, completed, snoozed, adhkar_read) '
      'VALUES(?, 0, 0, 1) '
      'ON CONFLICT(day) DO UPDATE SET adhkar_read = adhkar_read + 1',
      [day],
    );
  }

  Future<int> scheduledCountFor(String day) async {
    final d = await db;
    final r = await d.rawQuery(
      "SELECT COUNT(*) c FROM reminder_events WHERE substr(scheduled_at,1,10) = ? AND status != 'cancelled'",
      [day],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<Map<String, int>> progressFor(String day) async {
    final d = await db;
    final rows = await d
        .query('progress_daily', where: 'day = ?', whereArgs: [day]);
    if (rows.isEmpty) return {'completed': 0, 'snoozed': 0, 'adhkarRead': 0};
    final r = rows.first;
    return {
      'completed': (r['completed'] as int?) ?? 0,
      'snoozed': (r['snoozed'] as int?) ?? 0,
      'adhkarRead': (r['adhkar_read'] as int?) ?? 0,
    };
  }

  /// Completed-per-day series for charts: last [days] days, oldest first.
  Future<List<(String, int)>> progressSeries({int days = 7}) async {
    final d = await db;
    final from = DateTime.now()
        .subtract(Duration(days: days - 1))
        .startOfDay
        .dayKey;
    final rows = await d.query('progress_daily',
        where: 'day >= ?', whereArgs: [from], orderBy: 'day');
    final map = {
      for (final r in rows)
        r['day'] as String: (r['completed'] as int? ?? 0) +
            (r['adhkar_read'] as int? ?? 0),
    };
    return [
      for (var i = days - 1; i >= 0; i--)
        (
          DateTime.now().subtract(Duration(days: i)).dayKey,
          map[DateTime.now().subtract(Duration(days: i)).dayKey] ?? 0,
        ),
    ];
  }

  // ------------------------------------------------------------------
  // Tasbeeh
  // ------------------------------------------------------------------
  Future<int> saveTasbeehSession({
    String? dhikrId,
    required String dhikrText,
    required int target,
    required int count,
    required DateTime startedAt,
    DateTime? completedAt,
  }) async {
    final d = await db;
    final id = await d.insert('tasbeeh_sessions', {
      'dhikr_id': dhikrId,
      'dhikr_text': dhikrText,
      'target': target,
      'count': count,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    });
    await d.rawInsert(
      'INSERT INTO tasbeeh_daily(day, total_count) VALUES(?, ?) '
      'ON CONFLICT(day) DO UPDATE SET total_count = total_count + ?',
      [startedAt.dayKey, count, count],
    );
    return id;
  }

  Future<int> tasbeehTodayTotal() async {
    final d = await db;
    final rows = await d.query('tasbeeh_daily',
        where: 'day = ?', whereArgs: [DateTime.now().dayKey]);
    return rows.isEmpty ? 0 : (rows.first['total_count'] as int? ?? 0);
  }

  Future<int> tasbeehLifetime() async {
    final d = await db;
    final r = await d.rawQuery('SELECT COALESCE(SUM(total_count),0) t FROM tasbeeh_daily');
    return (r.first['t'] as int?) ?? 0;
  }

  Future<List<Map<String, Object?>>> recentTasbeehSessions(
      {int limit = 10}) async {
    final d = await db;
    return d.query('tasbeeh_sessions',
        orderBy: 'id DESC', limit: limit);
  }

  Future<List<(String, int)>> tasbeehSeries({int days = 7}) async {
    final d = await db;
    final from = DateTime.now()
        .subtract(Duration(days: days - 1))
        .startOfDay
        .dayKey;
    final rows = await d.query('tasbeeh_daily',
        where: 'day >= ?', whereArgs: [from], orderBy: 'day');
    final map = {
      for (final r in rows)
        r['day'] as String: (r['total_count'] as int? ?? 0),
    };
    return [
      for (var i = days - 1; i >= 0; i--)
        (
          DateTime.now().subtract(Duration(days: i)).dayKey,
          map[DateTime.now().subtract(Duration(days: i)).dayKey] ?? 0,
        ),
    ];
  }

  // ------------------------------------------------------------------
  // Achievements
  // ------------------------------------------------------------------
  Future<Set<String>> unlockedAchievements() async {
    final d = await db;
    final rows = await d.query('achievements');
    return rows.map((r) => r['id'] as String).toSet();
  }

  Future<bool> unlockAchievement(String id) async {
    final d = await db;
    final inserted = await d.insert(
      'achievements',
      {'id': id, 'unlocked_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return inserted > 0;
  }

  // ------------------------------------------------------------------
  // Meta
  // ------------------------------------------------------------------
  Future<String?> _metaGet(String key) async {
    final d = await db;
    final rows =
        await d.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _metaSet(String key, String value) async {
    final d = await db;
    await d.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> metaGet(String key) => _metaGet(key);
  Future<void> metaSet(String key, String value) => _metaSet(key, value);

  /// Stats totals
  Future<int> totalCompletedReminders() async {
    final d = await db;
    final r = await d.rawQuery(
        "SELECT COUNT(*) c FROM reminder_events WHERE status = 'completed'");
    return (r.first['c'] as int?) ?? 0;
  }

  // ------------------------------------------------------------------
  // Streaks (computed, never stored — works from any isolate)
  // ------------------------------------------------------------------
  Future<Set<String>> activeDays({int lookbackDays = 400}) async {
    final d = await db;
    final from = DateTime.now()
        .subtract(Duration(days: lookbackDays))
        .dayKey;
    final rows = await d.rawQuery(
      'SELECT day FROM progress_daily WHERE day >= ? AND (completed > 0 OR adhkar_read > 0) '
      'UNION '
      'SELECT day FROM tasbeeh_daily WHERE day >= ? AND total_count > 0',
      [from, from],
    );
    return rows.map((r) => r['day'] as String).toSet();
  }

  /// Returns (currentStreak, longestStreak) in consecutive active days.
  Future<(int, int)> computeStreak() async {
    final days = await activeDays();
    if (days.isEmpty) return (0, 0);

    var current = 0;
    var probe = DateTime.now();
    // A quiet today doesn't break the chain yet.
    if (!days.contains(probe.dayKey)) {
      probe = probe.subtract(const Duration(days: 1));
    }
    while (days.contains(probe.dayKey)) {
      current++;
      probe = probe.subtract(const Duration(days: 1));
    }

    var longest = 0;
    var run = 0;
    DateTime? prev;
    final sorted = days.toList()..sort();
    for (final k in sorted) {
      final dt = DateTime.parse(k);
      if (prev != null && dt.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      prev = dt;
    }
    return (current, longest);
  }
}
