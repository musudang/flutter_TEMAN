import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts; // map of userId -> count
  final bool isGroup;
  final String? groupName;
  final String? meetupId;
  final List<String> hiddenByIds;

  // [NEW] Anonymous DM support
  final String? type;             // null or 'direct' = normal, 'anonymous_dm' = anonymous
  final String? postId;           // source post ID for anonymous DM
  final String? postTitle;        // displayed as chat room name
  final String? postCollection;   // 'posts', 'universities/{uniId}/posts', etc.
  final Map<String, int>? anonymousIndices; // {uid: anonymousIndex} per participant

  Conversation({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCounts = const {},
    this.isGroup = false,
    this.groupName,
    this.meetupId,
    this.hiddenByIds = const [],
    this.type,
    this.postId,
    this.postTitle,
    this.postCollection,
    this.anonymousIndices,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'],
      meetupId: data['meetupId'],
      hiddenByIds: List<String>.from(data['hiddenByIds'] ?? []),
      type: data['type'],
      postId: data['postId'],
      postTitle: data['postTitle'],
      postCollection: data['postCollection'],
      anonymousIndices: data['anonymousIndices'] != null
          ? Map<String, int>.from(
              (data['anonymousIndices'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toInt()),
              ),
            )
          : null,
    );
  }

  /// Whether this conversation is an anonymous DM
  bool get isAnonymousDm => type == 'anonymous_dm';
}
