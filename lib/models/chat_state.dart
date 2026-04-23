class ChatState {
  final List<Map<String, dynamic>> messages;
  final bool isLoading;
  final bool isConnected;
  final Set<String> typingUsers;
  final Map<String, String> members; // ID -> Nom
  final Map<String, String> memberKeys;
  final bool otherUserOnline;
  final String? otherUserStatus; // 'online', 'busy', 'dnd', 'meeting', 'remote'

  ChatState({
    required this.messages,
    this.isLoading = false,
    this.isConnected = false,
    required this.typingUsers,
    required this.members,
    required this.memberKeys,
    this.otherUserOnline = false,
    this.otherUserStatus,
    this.downloadProgress = const {},
  });

  final Map<String, double> downloadProgress; // messageId -> progression (0.0 to 1.0)

  ChatState copyWith({
    List<Map<String, dynamic>>? messages,
    bool? isLoading,
    bool? isConnected,
    Set<String>? typingUsers,
    Map<String, String>? members,
    Map<String, String>? memberKeys,
    bool? otherUserOnline,
    String? otherUserStatus,
    Map<String, double>? downloadProgress,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      typingUsers: typingUsers ?? this.typingUsers,
      members: members ?? this.members,
      memberKeys: memberKeys ?? this.memberKeys,
      otherUserOnline: otherUserOnline ?? this.otherUserOnline,
      otherUserStatus: otherUserStatus ?? this.otherUserStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}
