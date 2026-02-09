part of 'chat_provider.dart';

enum SearchEngine { duckduckgo, google, bing }

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final bool hasUnreadResponse;
  final bool isAutoScrollEnabled;
  final bool isStreaming;
  final String? currentStreamContent;
  final String? currentStreamReasoning;
  final double? currentReasoningTimer;
  final bool isStreamEnabled;
  final bool isLoadingHistory;
  final String? activePresetName;
  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.hasUnreadResponse = false,
    this.isAutoScrollEnabled = true,
    this.isStreaming = false,
    this.currentStreamContent,
    this.currentStreamReasoning,
    this.currentReasoningTimer,
    this.isStreamEnabled = true,
    this.isLoadingHistory = false,
    this.activePresetName,
  });
  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    bool? hasUnreadResponse,
    bool? isAutoScrollEnabled,
    bool? isStreaming,
    String? currentStreamContent,
    String? currentStreamReasoning,
    double? currentReasoningTimer,
    bool? isStreamEnabled,
    bool? isLoadingHistory,
    Object? activePresetName = _sentinel,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasUnreadResponse: hasUnreadResponse ?? this.hasUnreadResponse,
      isAutoScrollEnabled: isAutoScrollEnabled ?? this.isAutoScrollEnabled,
      isStreaming: isStreaming ?? this.isStreaming,
      currentStreamContent: currentStreamContent ?? this.currentStreamContent,
      currentStreamReasoning:
          currentStreamReasoning ?? this.currentStreamReasoning,
      currentReasoningTimer:
          currentReasoningTimer ?? this.currentReasoningTimer,
      isStreamEnabled: isStreamEnabled ?? this.isStreamEnabled,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      activePresetName: activePresetName == _sentinel
          ? this.activePresetName
          : activePresetName as String?,
    );
  }
}

const Object _sentinel = Object();
