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
  final String imageUrl; // Placeholder for image URL

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
  });

  bool get isFull => participantIds.length >= maxParticipants;
  int get participantCount => participantIds.length;
}
