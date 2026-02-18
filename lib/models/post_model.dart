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
  final List<String> scrappedBy; // [NEW] For bookmarking meetups
  final String imageUrl;
  final String category;
  final String authorAvatar; // [NEW] Shared preference for avatar

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
    this.scrappedBy = const [],
    this.imageUrl = '',
    this.category = 'general',
    this.authorAvatar = '',
  });
}
