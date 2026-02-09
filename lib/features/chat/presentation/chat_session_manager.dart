part of 'chat_provider.dart';

class ChatSessionManager {
  final Map<String, ChatNotifier> _cache = {};
  final ChatStorage _storage;
  final Ref _ref;
  final StateController<int> _updateTrigger;
  ChatSessionManager(this._ref, this._storage, this._updateTrigger);
  ChatNotifier getOrCreate(String sessionId) {
    if (!_cache.containsKey(sessionId)) {
      _cache[sessionId] = ChatNotifier(
        ref: _ref,
        storage: _storage,
        sessionId: sessionId,
        onSessionCreated: (newId) {
          if (_cache.containsKey(sessionId)) {
            _cache[newId] = _cache.remove(sessionId)!;
          }
          // Restore missing navigation and session list refresh
          _ref.read(sessionsProvider.notifier).loadSessions();
          _ref.read(selectedHistorySessionIdProvider.notifier).state = newId;
        },
        onStateChanged: () {
          _updateTrigger.state++;
        },
      );
    }
    return _cache[sessionId]!;
  }

  void resetSession(String sessionId) {
    _cache.remove(sessionId)?.dispose();
    _updateTrigger.state++;
  }

  void disposeSession(String sessionId) {
    resetSession(sessionId);
  }

  void disposeAll() {
    for (final notifier in _cache.values) {
      notifier.dispose();
    }
    _cache.clear();
  }

  ChatState? getState(String sessionId) {
    return _cache[sessionId]?.currentState;
  }
}
