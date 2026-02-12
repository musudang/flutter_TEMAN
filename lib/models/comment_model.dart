class Comment {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.timestamp,
  });
}
