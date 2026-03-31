class ChatState {
  final List<Map<String, dynamic>> messages;
  final bool isLoading;
  final bool isConnected;
  final Set<String> typingUsers;
  final Map<String, String> memberKeys;

  ChatState({
    required this.messages,
    this.isLoading = false,
    this.isConnected = false,
    required this.typingUsers,
    required this.memberKeys,
  });

  ChatState copyWith({
    List<Map<String, dynamic>>? messages,
    bool? isLoading,
    bool? isConnected,
    Set<String>? typingUsers,
    Map<String, String>? memberKeys,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      typingUsers: typingUsers ?? this.typingUsers,
      memberKeys: memberKeys ?? this.memberKeys,
    );
  }
}
