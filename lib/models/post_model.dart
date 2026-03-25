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
  final String? subCategory; // [NEW] Subcategories for Events & Q&A
  final DateTime? eventDate; // [NEW] Date for Events

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
    this.subCategory,
    this.eventDate,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      scrappedBy: List<String>.from(json['scrappedBy'] ?? []),
      imageUrl: json['imageUrl'] ?? '',
      category: json['category'] ?? 'general',
      authorAvatar: json['authorAvatar'] ?? '',
      subCategory: json['subCategory'],
      eventDate: json['eventDate'] != null ? DateTime.parse(json['eventDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'likes': likes,
      'comments': comments,
      'likedBy': likedBy,
      'scrappedBy': scrappedBy,
      'imageUrl': imageUrl,
      'category': category,
      'authorAvatar': authorAvatar,
      'subCategory': subCategory,
      'eventDate': eventDate?.toIso8601String(),
    };
  }
}
