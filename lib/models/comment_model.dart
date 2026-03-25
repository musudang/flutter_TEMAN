class Comment {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final DateTime timestamp;

  // New fields for replies and reactions
  final String? replyToCommentId;
  final String? replyToCommentText;
  final String? replyToCommentAuthor;
  final Map<String, String>? reactions;

  Comment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.timestamp,
    this.replyToCommentId,
    this.replyToCommentText,
    this.replyToCommentAuthor,
    this.reactions,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      content: json['content'] ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName'] ?? '',
      authorAvatar: json['authorAvatar'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      replyToCommentId: json['replyToCommentId']?.toString(),
      replyToCommentText: json['replyToCommentText'],
      replyToCommentAuthor: json['replyToCommentAuthor'],
      reactions: json['reactions'] != null
          ? Map<String, String>.from(json['reactions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'timestamp': timestamp.toIso8601String(),
      'replyToCommentId': replyToCommentId,
      'replyToCommentText': replyToCommentText,
      'replyToCommentAuthor': replyToCommentAuthor,
      'reactions': reactions,
    };
  }
}
