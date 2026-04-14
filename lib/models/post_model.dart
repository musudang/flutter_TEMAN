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
  final List<String> imageUrls;
  final String category;
  final String authorAvatar; // [NEW] Shared preference for avatar
  final String? subCategory; // [NEW] Subcategories for Events & Q&A
  final DateTime? eventDate; // [NEW] Date for Events

  // [NEW] Shared content fields
  final String? sharedItemId;
  final String? sharedItemType;
  final String? sharedItemTitle;
  final String? sharedItemImage;
  
  // [NEW] Anonymous posting field
  final bool isAnonymous;

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
    this.imageUrls = const [],
    this.category = 'general',
    this.authorAvatar = '',
    this.subCategory,
    this.eventDate,
    this.sharedItemId,
    this.sharedItemType,
    this.sharedItemTitle,
    this.sharedItemImage,
    this.isAnonymous = false,
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
      imageUrls: data['imageUrls'] != null 
          ? List<String>.from(data['imageUrls']) 
          : (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty ? [data['imageUrl']] : []),
      category: data['category'] ?? 'general',
      scrappedBy: List<String>.from(data['scrappedBy'] ?? []),
      authorAvatar: data['authorAvatar'] ?? '',
      subCategory: data['subCategory'],
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),
      sharedItemId: data['sharedItemId'],
      sharedItemType: data['sharedItemType'],
      sharedItemTitle: data['sharedItemTitle'],
      sharedItemImage: data['sharedItemImage'],
      isAnonymous: data['isAnonymous'] ?? false,
    );
  }
}
