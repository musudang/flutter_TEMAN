import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meetup_model.dart';
import '../models/user_model.dart' as app_models;
import '../models/post_model.dart';
import '../models/question_model.dart';
import '../models/answer_model.dart';
import '../models/message_model.dart';
import '../models/job_model.dart';
import '../models/marketplace_model.dart';
import '../models/conversation_model.dart';
import '../models/notification_model.dart';

import 'dart:async';

class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get Current App User (Fetches from Firestore 'users' collection using Auth UID)
  // Get Current App User (Fetches from Firestore 'users' collection using Auth UID)
  // Get Current App User (Fetches from Firestore 'users' collection using Auth UID)
  // Get Current App User (Fetches from Firestore 'users' collection using Auth UID)
  Future<app_models.User?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          return app_models.User(
            id: data['id'] ?? user.uid,
            name: data['name'] ?? user.displayName ?? 'User',
            avatarUrl: data['avatarUrl'] ?? user.photoURL ?? '',
            nationality: data['nationality'] ?? 'Global 🌍',
          );
        }
      } else {
        // Doc doesn't exist, auto-create it
        debugPrint("User doc missing. Auto-creating for ${user.uid}");
        final newUser = app_models.User(
          id: user.uid,
          name: user.displayName ?? 'User',
          avatarUrl: user.photoURL ?? '',
          nationality: 'Global 🌍',
        );

        await _db.collection('users').doc(user.uid).set({
          'id': newUser.id,
          'name': newUser.name,
          'email': user.email,
          'avatarUrl': newUser.avatarUrl,
          'nationality': newUser.nationality,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return newUser;
      }
    } catch (e) {
      debugPrint("Error fetching/creating user from Firestore: $e");
    }

    // Fallback if Firestore doc is missing or error occurs
    return app_models.User(
      id: user.uid,
      name: user.displayName ?? 'User',
      avatarUrl: user.photoURL ?? '',
      nationality: 'Global 🌍',
    );
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
    if (_auth.currentUser == null) {
      debugPrint('Error: User must be logged in to write to Firestore');
      throw Exception('User must be logged in to create a meetup');
    }

    debugPrint("Attempting to save meetup... Title: ${meetup.title}");
    try {
      await _db.collection('meetups').doc(meetup.id).set(_toDocument(meetup));
      debugPrint("Meetup saved successfully!");
    } catch (e) {
      debugPrint("Error saving meetup: $e");
      rethrow;
    }
  }

  // Join Meetup
  Future<bool> joinMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) {
      debugPrint("Error: User not logged in trying to join meetup.");
      return false;
    }

    final docRef = _db.collection('meetups').doc(meetupId);

    try {
      return await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          debugPrint("Error: Meetup $meetupId does not exist!");
          throw Exception("Meetup does not exist!");
        }

        final meetup = _fromDocument(snapshot);

        if (meetup.participantIds.contains(uid)) {
          debugPrint("User already joined.");
          return false; // Already joined
        }

        // Robust Full Check
        if (meetup.participantIds.length >= meetup.maxParticipants) {
          debugPrint(
            "Meetup is full! (${meetup.participantIds.length}/${meetup.maxParticipants})",
          );
          return false; // Full
        }

        final updatedParticipants = List<String>.from(meetup.participantIds)
          ..add(uid);

        transaction.update(docRef, {'participantIds': updatedParticipants});
        debugPrint("Successfully joined meetup!");
        return true;
      });
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
  Meetup _meetupFromDocument(DocumentSnapshot doc) {
    // Reusing existing logic but renaming/wrapping for consistency if needed,
    // or just renaming _fromDocument to _meetupFromDocument
    return _fromDocument(doc);
  }

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

  // --- Posts (Feed) ---

  // --- Posts (Feed) ---

  // Unified Feed (Posts + Meetups)
  Stream<List<dynamic>> getFeed() {
    final controller = StreamController<List<dynamic>>();
    final postsStream = getPosts();
    final meetupsStream = getMeetups();

    List<Post>? posts;
    List<Meetup>? meetups;

    StreamSubscription? postsSub;
    StreamSubscription? meetupsSub;

    void emit() {
      // If either list is available, we can emit (treating null as empty if one loaded and other failed/waiting,
      // but simpler to wait for both initially or just handle nulls)
      // Let's output whatever we have, defaulting to empty list if null
      final currentPosts = posts ?? [];
      final currentMeetups = meetups ?? [];

      final allItems = <dynamic>[...currentPosts, ...currentMeetups];
      allItems.sort((a, b) {
        final DateTime timeA = a is Post ? a.timestamp : (a as Meetup).dateTime;
        final DateTime timeB = b is Post ? b.timestamp : (b as Meetup).dateTime;
        return timeB.compareTo(timeA); // Descending
      });
      controller.add(allItems);
    }

    postsSub = postsStream.listen((data) {
      posts = data;
      emit();
    }, onError: controller.addError);

    meetupsSub = meetupsStream.listen((data) {
      meetups = data;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () {
      postsSub?.cancel();
      meetupsSub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<Post>> getPosts() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => _postFromDocument(doc)).toList();
        });
  }

  Post _postFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      title: data['title'] ?? '', // Added title
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
    );
  }

  Future<void> addPost(
    String title,
    String content,
    String authorId,
    String authorName,
  ) async {
    if (_auth.currentUser == null) {
      debugPrint('Error: User must be logged in to write to Firestore');
      throw Exception('User must be logged in to post');
    }

    debugPrint(
      "Attempting to save post... Title: $title, Content: $content, Author: $authorName",
    );
    try {
      await _db.collection('posts').add({
        'authorId': authorId,
        'authorName': authorName,
        'title': title,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
      });
      debugPrint("Post saved successfully!");
    } catch (e) {
      debugPrint("Error saving post: $e");
      rethrow;
    }
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
    if (_auth.currentUser == null) {
      debugPrint('Error: User must be logged in to write to Firestore');
      throw Exception('User must be logged in to ask a question');
    }
    await _db.collection('questions').add({
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'timestamp': FieldValue.serverTimestamp(),
      'answersCount': 0,
    });
  }

  // --- Answers (QnA) ---

  Stream<List<Answer>> getAnswers(String questionId) {
    return _db
        .collection('questions')
        .doc(questionId)
        .collection('answers')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Answer(
              id: doc.id,
              questionId: questionId,
              content: data['content'] ?? '',
              authorId: data['authorId'] ?? '',
              authorName: data['authorName'] ?? 'Unknown',
              authorAvatar: data['authorAvatar'] ?? '',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
            );
          }).toList();
        });
  }

  Future<void> addAnswer(String questionId, String content) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to answer');
    }

    final userData = await getCurrentUser();

    try {
      await _db.runTransaction((transaction) async {
        final questionRef = _db.collection('questions').doc(questionId);
        final answerRef = questionRef.collection('answers').doc();

        // Check if question exists first? implicit in transaction logic if we read it?
        // We just write to subcollection, but we want to increment counter on parent.

        transaction.set(answerRef, {
          'content': content,
          'authorId': user.uid,
          'authorName': userData?.name ?? 'Unknown',
          'authorAvatar': userData?.avatarUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });

        transaction.update(questionRef, {
          'answersCount': FieldValue.increment(1),
        });
      });
    } catch (e) {
      debugPrint("Error adding answer: $e");
      rethrow;
    }
  }

  // --- Meetup Chat ---

  Stream<List<Message>> getMeetupMessages(String meetupId) {
    return _db
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Message(
              id: doc.id,
              senderId: data['senderId'] ?? '',
              senderName: data['senderName'] ?? 'Unknown',
              senderAvatar: data['senderAvatar'] ?? '',
              content: data['content'] ?? '',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
            );
          }).toList();
        });
  }

  Future<void> sendMeetupMessage(String meetupId, String content) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await getCurrentUser();

    await _db.collection('meetups').doc(meetupId).collection('messages').add({
      'senderId': user.uid,
      'senderName': userData?.name ?? 'Unknown',
      'senderAvatar': userData?.avatarUrl ?? '',
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- Jobs (Il-jari) ---

  Stream<List<Job>> getJobs() {
    return _db
        .collection('jobs')
        .orderBy('postedDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => _jobFromDocument(doc)).toList();
        });
  }

  Future<void> addJob(Job job) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to post a job');
    }

    try {
      await _db.collection('jobs').add({
        'title': job.title,
        'companyName': job.companyName,
        'location': job.location,
        'salary': job.salary,
        'description': job.description,
        'requirements': job.requirements,
        'contactInfo': job.contactInfo,
        'authorId': _auth.currentUser!.uid,
        'postedDate': FieldValue.serverTimestamp(),
        'deadline': job.deadline != null
            ? Timestamp.fromDate(job.deadline!)
            : null,
        'isActive': job.isActive,
      });
    } catch (e) {
      debugPrint("Error adding job: $e");
      rethrow;
    }
  }

  Job _jobFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      title: data['title'] ?? '',
      companyName: data['companyName'] ?? '',
      location: data['location'] ?? '',
      salary: data['salary'] ?? '',
      description: data['description'] ?? '',
      requirements: List<String>.from(data['requirements'] ?? []),
      contactInfo: data['contactInfo'] ?? '',
      authorId: data['authorId'] ?? '',
      postedDate: (data['postedDate'] as Timestamp).toDate(),
      deadline: data['deadline'] != null
          ? (data['deadline'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  // --- Marketplace (Jang-teo) ---

  Stream<List<MarketplaceItem>> getMarketplaceItems() {
    return _db
        .collection('marketplace')
        .orderBy('postedDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _marketplaceItemFromDocument(doc))
              .toList();
        });
  }

  Future<void> addMarketplaceItem(MarketplaceItem item) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to post an item');
    }

    final userData = await getCurrentUser();

    try {
      await _db.collection('marketplace').add({
        'title': item.title,
        'price': item.price,
        'description': item.description,
        'condition': item.condition,
        'category': item.category,
        'imageUrls': item.imageUrls,
        'sellerId': user.uid,
        'sellerName': userData?.name ?? 'Unknown',
        'sellerAvatar': userData?.avatarUrl ?? '',
        'postedDate': FieldValue.serverTimestamp(),
        'isSold': item.isSold,
      });
    } catch (e) {
      debugPrint("Error adding marketplace item: $e");
      rethrow;
    }
  }

  MarketplaceItem _marketplaceItemFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketplaceItem(
      id: doc.id,
      title: data['title'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      condition: data['condition'] ?? 'Used',
      category: data['category'] ?? 'Other',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? 'Unknown',
      sellerAvatar: data['sellerAvatar'] ?? '',
      postedDate: (data['postedDate'] as Timestamp).toDate(),
      isSold: data['isSold'] ?? false,
    );
  }

  // --- Direct Messaging ---

  Stream<List<Conversation>> getConversations() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: user.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Conversation(
              id: doc.id,
              participantIds: List<String>.from(data['participantIds'] ?? []),
              lastMessage: data['lastMessage'] ?? '',
              lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
              unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
            );
          }).toList();
        });
  }

  Stream<List<Message>> getChatMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Message(
              id: doc.id,
              senderId: data['senderId'] ?? '',
              senderName: data['senderName'] ?? 'Unknown',
              senderAvatar: data['senderAvatar'] ?? '',
              content: data['content'] ?? '',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
            );
          }).toList();
        });
  }

  Future<void> logChatMessage(String conversationId, String content) async {
    // Renamed to avoid confusion with Meetup sendMessage.
    // Actually let's use sendDirectMessage
    await sendDirectMessage(conversationId, content);
  }

  Future<void> sendDirectMessage(String conversationId, String content) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await getCurrentUser();

    final messageData = {
      'senderId': user.uid,
      'senderName': userData?.name ?? 'Unknown',
      'senderAvatar': userData?.avatarUrl ?? '',
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _db.runTransaction((transaction) async {
        final conversationRef = _db
            .collection('conversations')
            .doc(conversationId);
        final messageRef = conversationRef.collection('messages').doc();

        transaction.set(messageRef, messageData);
        transaction.update(conversationRef, {
          'lastMessage': content,
          'lastMessageTime': FieldValue.serverTimestamp(),
          // Increment unread count for OTHER participants (logic complex for transaction without read)
          // For simplicity, we won't implement unread count logic perfectly in this transaction without a read.
          // But effectively we'd update map.
        });
      });
    } catch (e) {
      debugPrint("Error sending DM: $e");
      rethrow;
    }
  }

  Future<String> startConversation(String otherUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Check if conversation exists
    final query = await _db
        .collection('conversations')
        .where('participantIds', arrayContains: user.uid)
        .get();

    for (var doc in query.docs) {
      final List<dynamic> participants = doc['participantIds'];
      if (participants.contains(otherUserId)) {
        return doc.id; // Found existing conversation
      }
    }

    // Create new
    final docRef = await _db.collection('conversations').add({
      'participantIds': [user.uid, otherUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts': {user.uid: 0, otherUserId: 0},
    });

    return docRef.id;
  }

  // --- Search Functionality ---

  Stream<List<Meetup>> searchMeetups(String query) {
    return _db
        .collection('meetups')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => _meetupFromDocument(doc)).toList();
        });
  }

  Stream<List<Job>> searchJobs(String query) {
    return _db
        .collection('jobs')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => _jobFromDocument(doc)).toList();
        });
  }

  Stream<List<MarketplaceItem>> searchMarketplace(String query) {
    return _db
        .collection('marketplace')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _marketplaceItemFromDocument(doc))
              .toList();
        });
  }

  Stream<List<Post>> searchPosts(String query) {
    return _db
        .collection('posts')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => _postFromDocument(doc)).toList();
        });
  }

  // --- Notifications ---

  Stream<List<NotificationModel>> getNotifications() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationModel.fromDocument(doc))
              .toList();
        });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String relatedId,
  }) async {
    await _db.collection('users').doc(userId).collection('notifications').add({
      'userId': userId, // Redundant but useful
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
