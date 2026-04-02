import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory Comment.fromFirestore(DocumentSnapshot doc, {String? defaultPostId}) {
    var data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      postId: data['postId'] ?? defaultPostId ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      authorAvatar: data['authorAvatar'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyToCommentId: data['replyToCommentId'],
      replyToCommentText: data['replyToCommentText'],
      replyToCommentAuthor: data['replyToCommentAuthor'],
      reactions: (data['reactions'] as Map<dynamic, dynamic>?)?.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
  }
}
