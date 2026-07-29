import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_x.dart';
import '../domain/dhikr.dart';
import 'adhkar_providers.dart';
import 'category_labels.dart';
import 'widgets/dhikr_card.dart';

/// Full searchable adhkar library with category filter chips.
class AdhkarLibraryPage extends ConsumerWidget {
  const AdhkarLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adhkar = ref.watch(adhkarListProvider);
    final selected = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tabAdhkar)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              hintText: context.l10n.searchHint,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(context.l10n.commonAll),
                    selected: selected == null,
                    onSelected: (_) => ref
                        .read(selectedCategoryProvider.notifier)
                        .state = null,
                  ),
                ),
                for (final c in DhikrCategory.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(adhkarCategoryLabel(context, c)),
                      selected: selected == c,
                      onSelected: (_) => ref
                          .read(selectedCategoryProvider.notifier)
                          .state = c,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: adhkar.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) => items.isEmpty
                  ? Center(child: Text(context.l10n.statsNoData))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final d = items[i];
                        return DhikrCard(
                          dhikr: d,
                          onTap: () => context.push(
                              '${AppConstants.routeDhikrPrefix}${d.id}'),
                          onToggleFavorite: (fav) async {
                            await ref
                                .read(dhikrRepositoryProvider)
                                .setFavorite(d.id, fav);
                            ref.invalidate(adhkarListProvider);
                            ref.invalidate(favoritesProvider);
                          },
                        ).animate().fadeIn(
                            delay: (i * 30).ms, duration: 300.ms);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
