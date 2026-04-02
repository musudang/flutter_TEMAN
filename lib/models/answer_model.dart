import 'package:cloud_firestore/cloud_firestore.dart';

class Answer {
  final String id;
  final String questionId;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final DateTime timestamp;

  Answer({
    required this.id,
    required this.questionId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.timestamp,
  });

  factory Answer.fromFirestore(DocumentSnapshot doc, String questionId) {
    var data = doc.data() as Map<String, dynamic>;
    return Answer(
      id: doc.id,
      questionId: questionId,
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      authorAvatar: data['authorAvatar'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
