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

  DateTime get date => dateTime; // Alias for compatibility

  factory Meetup.fromJson(Map<String, dynamic> json) {
    return Meetup(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      dateTime: json['dateTime'] != null
          ? DateTime.parse(json['dateTime'])
          : (json['date'] != null ? DateTime.parse(json['date']) : DateTime.now()),
      category: MeetupCategory.values.firstWhere(
        (c) => c.name == (json['category'] ?? 'other'),
        orElse: () => MeetupCategory.other,
      ),
      maxParticipants: json['maxParticipants'] ?? 0,
      host: User.fromJson(json['host'] ?? {}),
      participantIds: List<String>.from(json['participantIds'] ?? []),
      imageUrl: json['imageUrl'] ?? '',
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      scrappedBy: List<String>.from(json['scrappedBy'] ?? []),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      requiresApproval: json['requiresApproval'] ?? false,
      pendingParticipantIds: List<String>.from(json['pendingParticipantIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'dateTime': dateTime.toIso8601String(),
      'category': category.name,
      'maxParticipants': maxParticipants,
      'host': host.toJson(),
      'participantIds': participantIds,
      'imageUrl': imageUrl,
      'likes': likes,
      'comments': comments,
      'likedBy': likedBy,
      'scrappedBy': scrappedBy,
      'createdAt': createdAt.toIso8601String(),
      'requiresApproval': requiresApproval,
      'pendingParticipantIds': pendingParticipantIds,
    };
  }
}
