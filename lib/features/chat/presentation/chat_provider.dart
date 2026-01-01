import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/presentation/settings_provider.dart';
import 'package:aurora/shared/services/openai_llm_service.dart';
import '../domain/message.dart';
import 'package:aurora/shared/services/llm_service.dart';
import '../data/chat_storage.dart';
import '../data/session_entity.dart';

final llmServiceProvider = Provider<LLMService>((ref) {
  final settings = ref.watch(settingsProvider);
  return OpenAILLMService(settings);
});

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  const ChatState(
      {this.messages = const [], this.isLoading = false, this.error});
  ChatState copyWith(
      {List<Message>? messages, bool? isLoading, String? error}) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final LLMService _llmService;
  final SettingsState _settings;
  final ChatStorage _storage;
  String _sessionId;
  final void Function(String newId)? onSessionCreated;
  ChatNotifier({
    required LLMService llmService,
    required SettingsState settings,
    required ChatStorage storage,
    required String sessionId,
    this.onSessionCreated,
  })  : _llmService = llmService,
        _settings = settings,
        _storage = storage,
        _sessionId = sessionId,
        super(const ChatState()) {
    if (_sessionId != 'chat' && _sessionId != 'new_chat') {
      _loadHistory();
    }
  }
  Future<void> _loadHistory() async {
    final messages = await _storage.loadHistory(_sessionId);
    state = state.copyWith(messages: messages);
  }

  Future<String> sendMessage(String text,
      {List<String> attachments = const [], String? apiContent}) async {
    if (text.trim().isEmpty && attachments.isEmpty) return _sessionId;
    if (_sessionId == 'chat' || _sessionId == 'new_chat') {
      final title = text.length > 20 ? '${text.substring(0, 20)}...' : text;
      final realId = await _storage.createSession(title: title);
      if (_sessionId == 'new_chat' && onSessionCreated != null) {
        onSessionCreated!(realId);
      }
      _sessionId = realId;
    }
    final userMessage = Message.user(text, attachments: attachments);
    await _storage.saveMessage(userMessage, _sessionId);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );
    try {
      List<Message> messagesForApi = state.messages;
      if (apiContent != null) {
        messagesForApi = List<Message>.from(state.messages);
        messagesForApi.removeLast();
        messagesForApi.add(Message.user(apiContent, attachments: attachments));
      }
      final responseStream =
          _llmService.streamResponse(messagesForApi, attachments: attachments);
      final activeModel = _settings.selectedModel;
      final activeProvider = _settings.activeProvider?.name;
      var aiMsg = Message.ai('', model: activeModel, provider: activeProvider);
      state = state.copyWith(messages: [...state.messages, aiMsg]);
      await for (final chunk in responseStream) {
        aiMsg = Message(
          id: aiMsg.id,
          content: aiMsg.content + (chunk.content ?? ''),
          reasoningContent:
              (aiMsg.reasoningContent ?? '') + (chunk.reasoning ?? ''),
          isUser: false,
          timestamp: aiMsg.timestamp,
          attachments: aiMsg.attachments,
          images: [...aiMsg.images, ...chunk.images],
          model: aiMsg.model,
          provider: aiMsg.provider,
        );
        final newMessages = List<Message>.from(state.messages);
        newMessages.removeLast();
        newMessages.add(aiMsg);
        state = state.copyWith(messages: newMessages);
      }
      await _storage.saveMessage(aiMsg, _sessionId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
    return _sessionId;
  }

  Future<void> deleteMessage(String id) async {
    final newMessages = state.messages.where((m) => m.id != id).toList();
    state = state.copyWith(messages: newMessages);
    await _storage.deleteMessage(id);
  }

  Future<void> editMessage(String id, String newContent,
      {List<String>? newAttachments}) async {
    final index = state.messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final oldMsg = state.messages[index];
    final updatedAttachments = newAttachments ?? oldMsg.attachments;
    List<String> updatedImages = oldMsg.images;
    if (newAttachments != null) {
      final imageExts = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
      updatedImages = newAttachments.where((path) {
        final ext = path.split('.').last.toLowerCase();
        return imageExts.contains(ext);
      }).toList();
    }
    final newMsg = Message(
      id: oldMsg.id,
      content: newContent,
      isUser: oldMsg.isUser,
      timestamp: oldMsg.timestamp,
      reasoningContent: oldMsg.reasoningContent,
      attachments: updatedAttachments,
      images: updatedImages,
    );
    final newMessages = List<Message>.from(state.messages);
    newMessages[index] = newMsg;
    state = state.copyWith(messages: newMessages);
    await _storage.updateMessage(newMsg);
  }

  Future<void> regenerateResponse(String rootMessageId) async {
    final index = state.messages.indexWhere((m) => m.id == rootMessageId);
    if (index == -1) return;
    final rootMsg = state.messages[index];
    List<Message> historyToKeep;
    List<String> lastAttachments = [];
    String? lastApiContent;
    if (rootMsg.isUser) {
      historyToKeep = state.messages.sublist(0, index + 1);
      lastAttachments = rootMsg.attachments;
    } else {
      if (index == 0) return;
      historyToKeep = state.messages.sublist(0, index);
      final lastUserMsg = historyToKeep.last;
      lastAttachments = lastUserMsg.attachments;
    }
    final oldMessages = state.messages;
    state =
        state.copyWith(messages: historyToKeep, isLoading: true, error: null);
    final idsToDelete =
        oldMessages.skip(historyToKeep.length).map((m) => m.id).toList();
    for (final mid in idsToDelete) {
      await _storage.deleteMessage(mid);
    }
    try {
      final messagesForApi = List<Message>.from(historyToKeep);
      final responseStream = _llmService.streamResponse(messagesForApi,
          attachments: lastAttachments);
      var aiMsg = Message.ai('');
      state = state.copyWith(messages: [...state.messages, aiMsg]);
      await for (final chunk in responseStream) {
        aiMsg = Message(
          id: aiMsg.id,
          content: aiMsg.content + (chunk.content ?? ''),
          reasoningContent:
              (aiMsg.reasoningContent ?? '') + (chunk.reasoning ?? ''),
          isUser: false,
          timestamp: aiMsg.timestamp,
          attachments: aiMsg.attachments,
          images: [...aiMsg.images, ...chunk.images],
        );
        final newMessages = List<Message>.from(state.messages);
        newMessages.removeLast();
        newMessages.add(aiMsg);
        state = state.copyWith(messages: newMessages);
      }
      await _storage.saveMessage(aiMsg, _sessionId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> clearContext() async {
    if (_sessionId == 'new_chat' || _sessionId == 'translation') {
      state = const ChatState();
      return;
    }
    await _storage.clearSessionMessages(_sessionId);
    state = const ChatState();
  }
}

final chatStorageProvider = Provider<ChatStorage>((ref) {
  final settingsStorage = ref.watch(settingsStorageProvider);
  return ChatStorage(settingsStorage);
});
final translationProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final service = ref.watch(llmServiceProvider);
  final settings = ref.watch(settingsProvider);
  final storage = ref.watch(chatStorageProvider);
  return ChatNotifier(
      llmService: service,
      settings: settings,
      storage: storage,
      sessionId: 'translation');
});

class SessionsState {
  final List<SessionEntity> sessions;
  final bool isLoading;
  SessionsState({this.sessions = const [], this.isLoading = false});
}

class SessionsNotifier extends StateNotifier<SessionsState> {
  final ChatStorage _storage;
  SessionsNotifier(this._storage) : super(SessionsState()) {
    loadSessions();
  }
  Future<void> loadSessions() async {
    state = SessionsState(sessions: state.sessions, isLoading: true);
    final sessions = await _storage.loadSessions();
    state = SessionsState(sessions: sessions, isLoading: false);
  }

  Future<String> createNewSession(String title) async {
    final id = await _storage.createSession(title: title);
    await loadSessions();
    return id;
  }

  Future<void> deleteSession(String id) async {
    await _storage.deleteSession(id);
    await loadSessions();
  }
}

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, SessionsState>((ref) {
  final storage = ref.watch(chatStorageProvider);
  return SessionsNotifier(storage);
});
final selectedHistorySessionIdProvider = StateProvider<String?>((ref) => null);
final isHistorySidebarVisibleProvider = StateProvider<bool>((ref) => true);
final sessionSearchQueryProvider = StateProvider<String>((ref) => '');
final historyChatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final service = ref.watch(llmServiceProvider);
  final settings = ref.watch(settingsProvider);
  final storage = ref.watch(chatStorageProvider);
  final sessionId = ref.watch(selectedHistorySessionIdProvider);
  if (sessionId == null) {
    return ChatNotifier(
        llmService: service,
        settings: settings,
        storage: storage,
        sessionId: 'temp_empty');
  }
  return ChatNotifier(
      llmService: service,
      settings: settings,
      storage: storage,
      sessionId: sessionId,
      onSessionCreated: (newId) {
        ref.read(sessionsProvider.notifier).loadSessions();
      });
});
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final service = ref.watch(llmServiceProvider);
  final settings = ref.watch(settingsProvider);
  final storage = ref.watch(chatStorageProvider);
  return ChatNotifier(
      llmService: service,
      settings: settings,
      storage: storage,
      sessionId: 'chat');
});
