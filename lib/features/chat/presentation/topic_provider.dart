import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_provider.dart';
import '../data/topic_entity.dart';

// Provides the list of topics
final topicsProvider = FutureProvider<List<TopicEntity>>((ref) async {
  final storage = ref.watch(chatStorageProvider);
  return await storage.getAllTopics();
});

final selectedTopicIdProvider = StateProvider<int?>((ref) => null);

// Topic Notifier for CRUD operations
class TopicNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  
  TopicNotifier(this.ref) : super(const AsyncValue.data(null));
  
  Future<void> createTopic(String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final storage = ref.read(chatStorageProvider);
      await storage.createTopic(name);
      ref.invalidate(topicsProvider);
    });
  }
  
  Future<void> updateTopic(int id, String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final storage = ref.read(chatStorageProvider);
      await storage.updateTopic(id, name);
      ref.invalidate(topicsProvider);
    });
  }
  
  Future<void> deleteTopic(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final storage = ref.read(chatStorageProvider);
      await storage.deleteTopic(id);
      ref.invalidate(topicsProvider);
      ref.invalidate(sessionsProvider); // Sessions might have improved/changed
    });
  }
}

final topicNotifierProvider = StateNotifierProvider<TopicNotifier, AsyncValue<void>>((ref) {
  return TopicNotifier(ref);
});
