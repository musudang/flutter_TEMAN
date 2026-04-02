import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final DateTime timestamp;
  final String? sharedPostId;
  final String? sharedPostType; // 'meetup' or 'post'
  final String? sharedPostTitle;
  final String? sharedPostDescription;

  // New fields
  final String? replyToMessageId;
  final String? replyToMessageText;
  final String? replyToMessageSender;
  final Map<String, String>? reactions;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    required this.timestamp,
    this.sharedPostId,
    this.sharedPostType,
    this.sharedPostTitle,
    this.sharedPostDescription,
    this.replyToMessageId,
    this.replyToMessageText,
    this.replyToMessageSender,
    this.reactions,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderAvatar: data['senderAvatar'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sharedPostId: data['sharedPostId'],
      sharedPostType: data['sharedPostType'],
      sharedPostTitle: data['sharedPostTitle'],
      sharedPostDescription: data['sharedPostDescription'],
      replyToMessageId: data['replyToMessageId'],
      replyToMessageText: data['replyToMessageText'],
      replyToMessageSender: data['replyToMessageSender'],
      reactions: data['reactions'] != null ? Map<String, String>.from(data['reactions']) : null,
    );
  }
}
