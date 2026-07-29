import '../../../core/services/app_database.dart';
import '../domain/dhikr.dart';
import '../domain/dhikr_repository.dart';

/// SQLite-backed repository — the single offline source the UI reads.
class DhikrRepositoryImpl implements DhikrRepository {
  DhikrRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<Dhikr>> all({DhikrCategory? category, String? query}) =>
      _db.adhkar(category: category, query: query);

  @override
  Future<Dhikr?> byId(String id) => _db.dhikrById(id);

  @override
  Future<List<Dhikr>> favorites() => _db.favorites();

  @override
  Future<List<Dhikr>> mostRead({int limit = 5}) => _db.mostRead(limit: limit);

  @override
  Future<void> setFavorite(String id, bool value) =>
      _db.setFavorite(id, value);

  @override
  Future<void> markRead(String id) => _db.markDhikrRead(id);

  @override
  Future<void> upsertCustom(Dhikr dhikr) => _db.upsertDhikr(dhikr);

  @override
  Future<List<Verse>> verses() => _db.verses();

  @override
  Future<List<DailyHadith>> hadiths() => _db.hadiths();
}
