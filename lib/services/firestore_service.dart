import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meetup_model.dart';
import '../models/user_model.dart' as app_models;
import '../models/post_model.dart';
import '../models/question_model.dart';

class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get Current App User (Fetches from Firestore 'users' collection using Auth UID)
  Future<app_models.User?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return app_models.User(
          id: doc['id'],
          name: doc['name'],
          avatarUrl: doc['avatarUrl'] ?? '',
        );
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
    return null;
  }

  // Helper getter for Auth UID
  String? get currentUserId => _auth.currentUser?.uid;

  // Stream of Meetups
  Stream<List<Meetup>> getMeetups() {
    return _db.collection('meetups').orderBy('dateTime').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => _fromDocument(doc)).toList();
    });
  }

  // Stream of Single Meetup
  Stream<Meetup> getMeetup(String id) {
    return _db.collection('meetups').doc(id).snapshots().map((doc) {
      if (!doc.exists) throw Exception("Meetup not found");
      return _fromDocument(doc);
    });
  }

  // Add Meetup
  Future<void> addMeetup(Meetup meetup) async {
    await _db.collection('meetups').doc(meetup.id).set(_toDocument(meetup));
  }

  // Join Meetup
  Future<bool> joinMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) return false;

    final docRef = _db.collection('meetups').doc(meetupId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Meetup does not exist!");

        final meetup = _fromDocument(snapshot);

        if (meetup.participantIds.contains(uid)) {
          return false; // Already joined
        }
        if (meetup.participantIds.length >= meetup.maxParticipants) {
          return false; // Full
        }

        final updatedParticipants = List<String>.from(meetup.participantIds)
          ..add(uid);
        transaction.update(docRef, {'participantIds': updatedParticipants});
      });
      return true;
    } catch (e) {
      debugPrint("Error joining meetup: $e");
      return false;
    }
  }

  // Leave Meetup
  Future<void> leaveMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Meetup does not exist!");

        final meetup = _fromDocument(snapshot);
        if (!meetup.participantIds.contains(uid)) {
          return; // Not joined
        }

        final updatedParticipants = List<String>.from(meetup.participantIds)
          ..remove(uid);
        transaction.update(docRef, {'participantIds': updatedParticipants});
      });
    } catch (e) {
      debugPrint("Error leaving meetup: $e");
    }
  }

  // Helper: Convert DocumentSnapshot to Meetup
  Meetup _fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meetup(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      category: MeetupCategory.values.firstWhere(
        (e) => e.toString() == 'MeetupCategory.${data['category']}',
        orElse: () => MeetupCategory.other,
      ),
      maxParticipants: data['maxParticipants'] ?? 0,
      host: app_models.User(
        id: data['hostId'] ?? '',
        name: data['hostName'] ?? 'Unknown',
        avatarUrl: data['hostAvatar'] ?? '',
      ),
      participantIds: List<String>.from(data['participantIds'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  // Helper: Convert Meetup to Map
  Map<String, dynamic> _toDocument(Meetup meetup) {
    return {
      'title': meetup.title,
      'description': meetup.description,
      'location': meetup.location,
      'dateTime': Timestamp.fromDate(meetup.dateTime),
      'category': meetup.category.name, // Storing as string name
      'maxParticipants': meetup.maxParticipants,
      'hostId': meetup.host.id,
      'hostName': meetup.host.name,
      'hostAvatar': meetup.host.avatarUrl,
      'participantIds': meetup.participantIds,
      'imageUrl': meetup.imageUrl,
    };
  }

  // --- Posts (Feed) ---

  Stream<List<Post>> getPosts() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Post(
              id: doc.id,
              authorId: data['authorId'] ?? '',
              authorName: data['authorName'] ?? 'Unknown',
              content: data['content'] ?? '',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              likes: data['likes'] ?? 0,
              comments: data['comments'] ?? 0,
            );
          }).toList();
        });
  }

  Future<void> addPost(
    String content,
    String authorId,
    String authorName,
  ) async {
    await _db.collection('posts').add({
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'comments': 0,
    });
  }

  // --- Questions (QnA) ---

  Stream<List<Question>> getQuestions() {
    return _db
        .collection('questions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Question(
              id: doc.id,
              title: data['title'] ?? '',
              content: data['content'] ?? '',
              authorId: data['authorId'] ?? '',
              authorName: data['authorName'] ?? 'Unknown',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              answersCount: data['answersCount'] ?? 0,
            );
          }).toList();
        });
  }

  Future<void> addQuestion(
    String title,
    String content,
    String authorId,
    String authorName,
  ) async {
    await _db.collection('questions').add({
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'timestamp': FieldValue.serverTimestamp(),
      'answersCount': 0,
    });
  }
}
