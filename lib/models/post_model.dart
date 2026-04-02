import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory Post.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? 'general',
      scrappedBy: List<String>.from(data['scrappedBy'] ?? []),
      authorAvatar: data['authorAvatar'] ?? '',
      subCategory: data['subCategory'],
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),
    );
  }
}
