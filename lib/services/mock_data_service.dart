import 'package:flutter/material.dart';

import '../models/meetup_model.dart';
import '../models/user_model.dart';

class MockDataService extends ChangeNotifier {
  // Mock Current User
  final User _currentUser = User(
    id: 'user_1',
    name: 'Emma W.',
    avatarUrl: 'https://i.pravatar.cc/150?u=user_1',
  );

  User get currentUser => _currentUser;

  // Mock Meetups Data
  final List<Meetup> _meetups = [
    Meetup(
      id: 'meetup_1',
      title: 'Hongdae Cafe Hopping',
      description:
          'Let us explore some hidden gem cafes in Hongdae! I have a list of 5 unique spots we can visit. Perfect for coffee lovers and Instagram enthusiasts.',
      location: 'Hongdae Station Exit 9',
      dateTime: DateTime.now().add(const Duration(days: 2, hours: 4)),
      category: MeetupCategory.cafe,
      maxParticipants: 6,
      host: User(
        id: 'host_1',
        name: 'Alex K.',
        avatarUrl: 'https://i.pravatar.cc/150?u=alex',
      ),
      participantIds: ['host_1', 'user_2', 'user_3'],
      imageUrl:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60',
    ),
    Meetup(
      id: 'meetup_2',
      title: 'Han River Night Run',
      description:
          'Casual 5k run along the Han River. All paces welcome! We will grab some chicken and beer afterwards.',
      location: 'Yeouido Park',
      dateTime: DateTime.now().add(const Duration(days: 5, hours: 10)),
      category: MeetupCategory.exercise,
      maxParticipants: 10,
      host: User(
        id: 'host_2',
        name: 'Minji L.',
        avatarUrl: 'https://i.pravatar.cc/150?u=minji',
      ),
      participantIds: ['host_2', 'user_4'],
      imageUrl:
          'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60',
    ),
    Meetup(
      id: 'meetup_3',
      title: 'Language Exchange & Pub',
      description:
          'Practice Korean/English/Japanese over drinks! Great way to make new friends in Seoul.',
      location: 'Itaewon',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      category: MeetupCategory.alcohol,
      maxParticipants: 20,
      host: User(
        id: 'host_3',
        name: 'Chris P.',
        avatarUrl: 'https://i.pravatar.cc/150?u=chris',
      ),
      participantIds: ['host_3', 'user_5', 'user_6', 'user_7', 'user_8'],
      imageUrl:
          'https://images.unsplash.com/photo-1572116469696-958721b7d6ca?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60',
    ),
  ];

  List<Meetup> get meetups => List.unmodifiable(_meetups);

  // Join Meetup Logic
  bool joinMeetup(String meetupId) {
    final meetupIndex = _meetups.indexWhere((m) => m.id == meetupId);
    if (meetupIndex == -1) {
      return false;
    }

    final meetup = _meetups[meetupIndex];
    if (meetup.participantIds.contains(_currentUser.id)) {
      return false; // Already joined
    }
    if (meetup.participantIds.length >= meetup.maxParticipants) {
      return false; // Full
    }

    // Update state
    final updatedParticipants = List<String>.from(meetup.participantIds)
      ..add(_currentUser.id);
    _meetups[meetupIndex] = Meetup(
      id: meetup.id,
      title: meetup.title,
      description: meetup.description,
      location: meetup.location,
      dateTime: meetup.dateTime,
      category: meetup.category,
      maxParticipants: meetup.maxParticipants,
      host: meetup.host,
      participantIds: updatedParticipants,
      imageUrl: meetup.imageUrl,
    );

    notifyListeners();
    return true;
  }

  // Leave Meetup Logic
  void leaveMeetup(String meetupId) {
    final meetupIndex = _meetups.indexWhere((m) => m.id == meetupId);
    if (meetupIndex == -1) {
      return;
    }

    final meetup = _meetups[meetupIndex];
    if (!meetup.participantIds.contains(_currentUser.id)) {
      return; // Not joined
    }

    final updatedParticipants = List<String>.from(meetup.participantIds)
      ..remove(_currentUser.id);
    _meetups[meetupIndex] = Meetup(
      id: meetup.id,
      title: meetup.title,
      description: meetup.description,
      location: meetup.location,
      dateTime: meetup.dateTime,
      category: meetup.category,
      maxParticipants: meetup.maxParticipants,
      host: meetup.host,
      participantIds: updatedParticipants,
      imageUrl: meetup.imageUrl,
    );

    notifyListeners();
  }

  // Add Meetup
  void addMeetup(Meetup meetup) {
    _meetups.add(meetup);
    notifyListeners();
  }
}
