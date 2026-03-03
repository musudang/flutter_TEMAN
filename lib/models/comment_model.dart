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
}
