import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

enum MeetupCategory { exercise, alcohol, cafe, culture, other }

class Meetup {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime dateTime;
  final MeetupCategory category;
  final int maxParticipants;
  final User host;
  final List<String> participantIds; // List of User IDs
  final String imageUrl;
  final int likes;
  final int comments;
  final List<String> likedBy;
  final List<String> scrappedBy;
  final DateTime createdAt; // [NEW] for sorting feed by upload time

  // [NEW] Accept/Decline feature
  final bool requiresApproval;
  final List<String> pendingParticipantIds;

  Meetup({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.dateTime,
    required this.category,
    required this.maxParticipants,
    required this.host,
    this.participantIds = const [],
    required this.imageUrl,
    this.likes = 0,
    this.comments = 0,
    this.likedBy = const [],
    this.scrappedBy = const [],
    required this.createdAt,
    this.requiresApproval = false,
    this.pendingParticipantIds = const [],
  });

  bool get isFull => participantIds.length >= maxParticipants;
  int get participantCount => participantIds.length;

  factory Meetup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meetup(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: MeetupCategory.values.firstWhere(
        (e) => e.toString() == 'MeetupCategory.${data['category']}',
        orElse: () => MeetupCategory.other,
      ),
      maxParticipants: data['maxParticipants'] ?? 0,
      host: User(
        id: data['hostId'] ?? '',
        name: data['hostName'] ?? 'Unknown',
        avatarUrl: data['hostAvatar'] ?? '',
      ),
      participantIds: List<String>.from(data['participantIds'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      scrappedBy: List<String>.from(data['scrappedBy'] ?? []),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
          : DateTime(2025, 1, 1),
      requiresApproval: data['requiresApproval'] ?? false,
      pendingParticipantIds: List<String>.from(data['pendingParticipantIds'] ?? []),
    );
  }
}

