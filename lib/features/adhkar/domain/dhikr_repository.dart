import '../domain/dhikr.dart';

/// Domain contract (Clean Architecture): presentation depends on this
/// interface, not on SQLite.
abstract class DhikrRepository {
  Future<List<Dhikr>> all({DhikrCategory? category, String? query});
  Future<Dhikr?> byId(String id);
  Future<List<Dhikr>> favorites();
  Future<List<Dhikr>> mostRead({int limit});
  Future<void> setFavorite(String id, bool value);
  Future<void> markRead(String id);
  Future<void> upsertCustom(Dhikr dhikr);
  Future<List<Verse>> verses();
  Future<List<DailyHadith>> hadiths();
}
