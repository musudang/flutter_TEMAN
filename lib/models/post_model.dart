class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime timestamp;
  final int likes;
  final int comments;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
  });
}
