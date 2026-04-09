class StatusModel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? mediaUrl;
  final String? text;
  final DateTime createdAt;

  StatusModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.mediaUrl,
    this.text,
    required this.createdAt,
  });

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      userAvatar: json['user_avatar'],
      mediaUrl: json['media_url'],
      text: json['text'] ?? json['content'], // Support both names
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'media_url': mediaUrl,
      'content': text, // Map text to content for SQLite
      'created_at': createdAt.toIso8601String(),
    };
  }
}
