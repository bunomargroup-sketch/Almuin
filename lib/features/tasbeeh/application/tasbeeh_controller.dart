import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_database.dart';
import '../../adhkar/domain/dhikr.dart';
import '../../adhkar/presentation/adhkar_providers.dart';
import '../../gamification/application/gamification_providers.dart';

/// State of the live digital-tasbeeh session.
class TasbeehState {
  const TasbeehState({
    required this.dhikrText,
    this.dhikrId,
    this.target = 33,
    this.count = 0,
    required this.startedAt,
  });

  final String dhikrText;
  final String? dhikrId;
  final int target;
  final int count;
  final DateTime startedAt;

  bool get reached => count >= target;

  TasbeehState copyWith({
    String? dhikrText,
    String? dhikrId,
    int? target,
    int? count,
    DateTime? startedAt,
  }) =>
      TasbeehState(
        dhikrText: dhikrText ?? this.dhikrText,
        dhikrId: dhikrId ?? this.dhikrId,
        target: target ?? this.target,
        count: count ?? this.count,
        startedAt: startedAt ?? this.startedAt,
      );
}

final tasbeehControllerProvider =
    NotifierProvider<TasbeehController, TasbeehState>(TasbeehController.new);

class TasbeehController extends Notifier<TasbeehState> {
  static const defaultDhikr = 'سُبْحَانَ اللهِ وَبِحَمْدِهِ';

  @override
  TasbeehState build() =>
      TasbeehState(dhikrText: defaultDhikr, startedAt: DateTime.now());

  void selectDhikr(Dhikr d) {
    _persistIfMeaningful();
    state = TasbeehState(
      dhikrText: d.arabic,
      dhikrId: d.id,
      target: state.target,
      startedAt: DateTime.now(),
    );
  }

  void selectText(String text) {
    _persistIfMeaningful();
    state = TasbeehState(
      dhikrText: text,
      target: state.target,
      startedAt: DateTime.now(),
    );
  }

  void setTarget(int target) => state = state.copyWith(target: target);

  /// One bead.
  Future<void> increment() async {
    if (state.reached) {
      // Round already complete & persisted — extra beads start a FRESH
      // session instead of re-persisting the finished one (review H3).
      HapticFeedback.selectionClick();
      state = TasbeehState(
        dhikrText: state.dhikrText,
        dhikrId: state.dhikrId,
        target: state.target,
        count: 1,
        startedAt: DateTime.now(),
      );
      return;
    }
    final next = state.count + 1;
    HapticFeedback.selectionClick();
    state = state.copyWith(count: next);
    if (next >= state.target) {
      // Completion: strong haptic + persist finished session exactly once.
      HapticFeedback.mediumImpact();
      await _persist(completed: true);
      await _celebrate();
    }
  }

  Future<void> reset() async {
    await _persistIfMeaningful();
    state = TasbeehState(
      dhikrText: state.dhikrText,
      dhikrId: state.dhikrId,
      target: state.target,
      startedAt: DateTime.now(),
    );
  }

  Future<void> _persistIfMeaningful() async {
    if (state.count > 0) await _persist(completed: state.reached);
  }

  Future<void> _persist({required bool completed}) async {
    if (state.count == 0) return;
    await AppDatabase.instance.saveTasbeehSession(
      dhikrId: state.dhikrId,
      dhikrText: state.dhikrText,
      target: state.target,
      count: state.count,
      startedAt: state.startedAt,
      completedAt: completed ? DateTime.now() : null,
    );
    if (state.dhikrId != null) {
      await AppDatabase.instance.markDhikrRead(state.dhikrId!);
    }
    ref.invalidate(tasbeehTodayProviderShim);
  }

  Future<void> _celebrate() async {
    final fresh = await AchievementEvaluator.evaluate();
    if (fresh.isNotEmpty) {
      ref.read(achievementUnlockProvider.notifier).state = fresh.first;
      ref.invalidate(unlockedAchievementsProvider);
    }
  }
}

/// A tiny indirection so this controller can invalidate the home stat
/// without importing the presentation file (kept at presentation layer).
final tasbeehTodayProviderShim = FutureProvider<int>((ref) {
  return AppDatabase.instance.tasbeehTodayTotal();
});

/// Preset tasbeeh phrases from the verified DB (category: tasbeeh).
final tasbeehPresetsProvider = FutureProvider<List<Dhikr>>((ref) async {
  await ref.watch(seededProvider.future);
  final items =
      await ref.watch(dhikrRepositoryProvider).all(category: DhikrCategory.tasbeeh);
  return items;
});
