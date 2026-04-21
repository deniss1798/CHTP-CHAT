import '../../data/models/chat_models.dart';

class ChatsScreenState {
  const ChatsScreenState({
    this.isLoading = true,
    this.error,
    this.currentUserId,
    this.searchQuery = '',
    this.allChats = const <ChatSummary>[],
    this.filteredChats = const <ChatSummary>[],
    this.typingLabelByChatId = const <int, String>{},
    this.chatsNextCursor,
    this.chatsLoadingMore = false,
  });

  final bool isLoading;
  final String? error;
  final int? currentUserId;
  final String searchQuery;
  final List<ChatSummary> allChats;
  final List<ChatSummary> filteredChats;
  final Map<int, String> typingLabelByChatId;
  final String? chatsNextCursor;
  final bool chatsLoadingMore;

  ChatsScreenState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? currentUserId,
    bool keepCurrentUserId = true,
    String? searchQuery,
    List<ChatSummary>? allChats,
    List<ChatSummary>? filteredChats,
    Map<int, String>? typingLabelByChatId,
    String? chatsNextCursor,
    bool clearChatsNextCursor = false,
    bool? chatsLoadingMore,
  }) {
    return ChatsScreenState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentUserId: keepCurrentUserId
          ? (currentUserId ?? this.currentUserId)
          : currentUserId,
      searchQuery: searchQuery ?? this.searchQuery,
      allChats: allChats ?? this.allChats,
      filteredChats: filteredChats ?? this.filteredChats,
      typingLabelByChatId: typingLabelByChatId ?? this.typingLabelByChatId,
      chatsNextCursor:
          clearChatsNextCursor ? null : (chatsNextCursor ?? this.chatsNextCursor),
      chatsLoadingMore: chatsLoadingMore ?? this.chatsLoadingMore,
    );
  }
}
