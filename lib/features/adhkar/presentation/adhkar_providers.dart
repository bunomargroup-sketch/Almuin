import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_database.dart';
import '../data/dhikr_repository_impl.dart';
import '../domain/dhikr.dart';
import '../domain/dhikr_repository.dart';

final dhikrRepositoryProvider = Provider<DhikrRepository>(
  (ref) => DhikrRepositoryImpl(AppDatabase.instance),
);

/// Seeding gate — the whole content layer waits on this.
final seededProvider = FutureProvider<bool>((ref) async {
  await AppDatabase.instance.ensureSeeded();
  return true;
});

final selectedCategoryProvider =
    StateProvider<DhikrCategory?>((_) => null);
final searchQueryProvider = StateProvider<String>((_) => '');

final adhkarListProvider = FutureProvider<List<Dhikr>>((ref) async {
  await ref.watch(seededProvider.future);
  final repo = ref.watch(dhikrRepositoryProvider);
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider);
  return repo.all(category: category, query: query);
});

final dhikrProvider =
    FutureProvider.autoDispose.family<Dhikr?, String>((ref, id) async {
  await ref.watch(seededProvider.future);
  return ref.watch(dhikrRepositoryProvider).byId(id);
});

final favoritesProvider = FutureProvider<List<Dhikr>>((ref) async {
  await ref.watch(seededProvider.future);
  return ref.watch(dhikrRepositoryProvider).favorites();
});

final versesProvider = FutureProvider<List<Verse>>((ref) async {
  await ref.watch(seededProvider.future);
  return ref.watch(dhikrRepositoryProvider).verses();
});

final hadithsProvider = FutureProvider<List<DailyHadith>>((ref) async {
  await ref.watch(seededProvider.future);
  return ref.watch(dhikrRepositoryProvider).hadiths();
});
