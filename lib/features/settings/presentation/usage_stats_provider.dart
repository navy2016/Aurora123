import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_storage.dart';
import 'settings_provider.dart';

class UsageStatsState {
  final Map<
      String,
      ({
        int success,
        int failure,
        int totalDurationMs,
        int validDurationCount,
        int totalFirstTokenMs,
        int validFirstTokenCount,
        int totalTokenCount
      })> stats;
  final bool isLoading;
  const UsageStatsState({
    this.stats = const {},
    this.isLoading = false,
  });
  UsageStatsState copyWith({
    Map<
            String,
            ({
              int success,
              int failure,
              int totalDurationMs,
              int validDurationCount,
              int totalFirstTokenMs,
              int validFirstTokenCount,
              int totalTokenCount
            })>?
        stats,
    bool? isLoading,
  }) {
    return UsageStatsState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get totalCalls =>
      stats.values.fold(0, (sum, s) => sum + s.success + s.failure);
  int get totalSuccess => stats.values.fold(0, (sum, s) => sum + s.success);
  int get totalFailure => stats.values.fold(0, (sum, s) => sum + s.failure);
  int get totalTokens => stats.values.fold(0, (sum, s) => sum + s.totalTokenCount);
}

class UsageStatsNotifier extends StateNotifier<UsageStatsState> {
  final SettingsStorage _storage;
  UsageStatsNotifier(this._storage) : super(const UsageStatsState()) {
    loadStats();
  }
  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true);
    final entities = await _storage.loadAllUsageStats();
    final statsMap = <String,
        ({
      int success,
      int failure,
      int totalDurationMs,
      int validDurationCount,
      int totalFirstTokenMs,
      int validFirstTokenCount,
      int totalTokenCount
    })>{};
    for (final e in entities) {
      statsMap[e.modelName] = (
        success: e.successCount,
        failure: e.failureCount,
        totalDurationMs: e.totalDurationMs,
        validDurationCount: e.validDurationCount,
        totalFirstTokenMs: e.totalFirstTokenMs,
        validFirstTokenCount: e.validFirstTokenCount,
        totalTokenCount: e.totalTokenCount,
      );
    }
    state = UsageStatsState(stats: statsMap, isLoading: false);
  }

  Future<void> incrementUsage(String modelName,
      {bool success = true,
      int durationMs = 0,
      int firstTokenMs = 0,
      int tokenCount = 0}) async {
    await _storage.incrementUsage(modelName,
        success: success,
        durationMs: durationMs,
        firstTokenMs: firstTokenMs,
        tokenCount: tokenCount);
    final current = state.stats[modelName] ??
        (
          success: 0,
          failure: 0,
          totalDurationMs: 0,
          validDurationCount: 0,
          totalFirstTokenMs: 0,
          validFirstTokenCount: 0,
          totalTokenCount: 0
        );
    final newStats = Map<
        String,
        ({
          int success,
          int failure,
          int totalDurationMs,
          int validDurationCount,
          int totalFirstTokenMs,
          int validFirstTokenCount,
          int totalTokenCount
        })>.from(state.stats);
    newStats[modelName] = (
      success: current.success + (success ? 1 : 0),
      failure: current.failure + (success ? 0 : 1),
      totalDurationMs:
          current.totalDurationMs + (durationMs > 0 ? durationMs : 0),
      validDurationCount:
          current.validDurationCount + (durationMs > 0 ? 1 : 0),
      totalFirstTokenMs:
          current.totalFirstTokenMs + (firstTokenMs > 0 ? firstTokenMs : 0),
      validFirstTokenCount:
          current.validFirstTokenCount + (firstTokenMs > 0 ? 1 : 0),
      totalTokenCount: current.totalTokenCount + tokenCount,
    );
    state = state.copyWith(stats: newStats);
  }

  Future<void> clearStats() async {
    await _storage.clearUsageStats();
    state = const UsageStatsState();
  }
}

final usageStatsProvider =
    StateNotifierProvider<UsageStatsNotifier, UsageStatsState>((ref) {
  final storage = ref.watch(settingsStorageProvider);
  return UsageStatsNotifier(storage);
});
