class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String content;
  final DateTime timestamp;
  final int likes;
  final int comments;
  final List<String> likedBy;
  final String imageUrl;
  final String category;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
    this.likedBy = const [],
    this.imageUrl = '',
    this.category = 'general',
  });
}
