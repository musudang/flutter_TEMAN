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
  });

  bool get isFull => participantIds.length >= maxParticipants;
  int get participantCount => participantIds.length;
}
