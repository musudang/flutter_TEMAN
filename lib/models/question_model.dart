import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final DateTime timestamp;
  final int answersCount;
  final bool isAnonymous;
  
  // [NEW] University badge
  final String? authorUniversityId;

  Question({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.timestamp,
    this.answersCount = 0,
    this.isAnonymous = false,
    this.authorUniversityId,
  });

  factory Question.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Question(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      authorAvatar: data['authorAvatar'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      answersCount: data['answersCount'] ?? 0,
      isAnonymous: data['isAnonymous'] ?? false,
      authorUniversityId: data['authorUniversityId'],
    );
  }
}
