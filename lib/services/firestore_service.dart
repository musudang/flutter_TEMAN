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
import '../models/comment_model.dart';

import 'dart:async';

class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===================== USER =====================

  Future<app_models.User?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          return _userFromData(data, user.uid);
        }
      } else {
        debugPrint("User doc missing. Auto-creating for ${user.uid}");
        final newUser = app_models.User(
          id: user.uid,
          name: user.displayName ?? 'User',
          avatarUrl: user.photoURL ?? '',
          nationality: 'Global 🌍',
          email: user.email ?? '',
        );

        await _db.collection('users').doc(user.uid).set({
          'id': newUser.id,
          'name': newUser.name,
          'email': user.email ?? '',
          'avatarUrl': newUser.avatarUrl,
          'nationality': newUser.nationality,
          'bio': '',
          'role': 'user',
          'age': null,
          'personalInfo': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return newUser;
      }
    } catch (e) {
      debugPrint("Error fetching/creating user from Firestore: $e");
    }

    return app_models.User(
      id: user.uid,
      name: user.displayName ?? 'User',
      avatarUrl: user.photoURL ?? '',
      nationality: 'Global 🌍',
      email: user.email ?? '',
    );
  }

  app_models.User _userFromData(Map<String, dynamic> data, String fallbackId) {
    return app_models.User(
      id: data['id'] ?? fallbackId,
      name: data['name'] ?? 'User',
      avatarUrl: data['avatarUrl'] ?? '',
      nationality: data['nationality'] ?? 'Global 🌍',
      email: data['email'] ?? '',
      bio: data['bio'] ?? '',
      role: data['role'] ?? 'user',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      age: data['age'] as int?,
      personalInfo: data['personalInfo'] ?? '',
    );
  }

  String? get currentUserId => _auth.currentUser?.uid;

  Future<app_models.User?> getUserById(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return _userFromData(doc.data()!, userId);
      }
    } catch (e) {
      debugPrint("Error fetching user $userId: $e");
    }
    return null;
  }

  Future<void> updateUserProfile({
    required String name,
    required String bio,
    required String nationality,
    String? avatarUrl,
    int? age,
    String? personalInfo,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final Map<String, dynamic> data = {
      'name': name,
      'bio': bio,
      'nationality': nationality,
    };
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    if (age != null) data['age'] = age;
    if (personalInfo != null) data['personalInfo'] = personalInfo;

    await _db.collection('users').doc(uid).update(data);
  }

  Future<bool> isAdmin() async {
    final user = await getCurrentUser();
    return user?.isAdmin ?? false;
  }

  // ===================== MEETUPS =====================

  Stream<List<Meetup>> getMeetups() {
    return _db.collection('meetups').orderBy('dateTime').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => _fromDocument(doc)).toList();
    });
  }

  Stream<Meetup> getMeetup(String id) {
    return _db.collection('meetups').doc(id).snapshots().map((doc) {
      if (!doc.exists) throw Exception("Meetup not found");
      return _fromDocument(doc);
    });
  }

  Future<void> addMeetup(Meetup meetup) async {
    if (_auth.currentUser == null) {
      debugPrint('Error: User must be logged in to write to Firestore');
      throw Exception('User must be logged in to create a meetup');
    }

    debugPrint("Attempting to save meetup... Title: ${meetup.title}");
    try {
      // Use .add() to auto-generate ID (meetup.id is '' from CreatePostScreen)
      if (meetup.id.isEmpty) {
        await _db.collection('meetups').add(_toDocument(meetup));
      } else {
        await _db.collection('meetups').doc(meetup.id).set(_toDocument(meetup));
      }
      debugPrint("Meetup saved successfully!");
    } catch (e) {
      debugPrint("Error saving meetup: $e");
      rethrow;
    }
  }

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
          return false;
        }

        if (meetup.participantIds.length >= meetup.maxParticipants) {
          debugPrint(
            "Meetup is full! (${meetup.participantIds.length}/${meetup.maxParticipants})",
          );
          return false;
        }

        final updatedParticipants = List<String>.from(meetup.participantIds)
          ..add(uid);

        transaction.update(docRef, {'participantIds': updatedParticipants});
        debugPrint("Successfully joined meetup!");

        // Auto-create group chat when meetup is full
        if (updatedParticipants.length >= meetup.maxParticipants) {
          // We can't do async calls inside a transaction, so we schedule it
          Future.microtask(
            () => _createGroupChatForMeetup(
              meetupId,
              meetup.title,
              updatedParticipants,
            ),
          );
        }

        return true;
      });
    } catch (e) {
      debugPrint("Error joining meetup: $e");
      return false;
    }
  }

  Future<void> _createGroupChatForMeetup(
    String meetupId,
    String meetupTitle,
    List<String> participantIds,
  ) async {
    try {
      // Check if group chat already exists for this meetup
      final existing = await _db
          .collection('conversations')
          .where('meetupId', isEqualTo: meetupId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        debugPrint("Group chat already exists for meetup $meetupId");
        return;
      }

      final docRef = await _db.collection('conversations').add({
        'participantIds': participantIds,
        'lastMessage': '🎉 Meetup group created! Everyone is here.',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'meetupId': meetupId,
        'isGroup': true,
        'groupName': meetupTitle,
        'unreadCounts': {for (var id in participantIds) id: 0},
      });

      // Notify all participants
      for (final pid in participantIds) {
        await sendNotification(
          userId: pid,
          title: 'Group Chat Created! 🎉',
          body: 'Meetup "$meetupTitle" is full! A group chat has been created.',
          type: 'meetup_join',
          relatedId: docRef.id,
        );
      }

      debugPrint("Group chat created for meetup $meetupId");
    } catch (e) {
      debugPrint("Error creating group chat: $e");
    }
  }

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
          return;
        }

        final updatedParticipants = List<String>.from(meetup.participantIds)
          ..remove(uid);
        transaction.update(docRef, {'participantIds': updatedParticipants});
      });
    } catch (e) {
      debugPrint("Error leaving meetup: $e");
    }
  }

  Meetup _meetupFromDocument(DocumentSnapshot doc) {
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

  Map<String, dynamic> _toDocument(Meetup meetup) {
    return {
      'title': meetup.title,
      'description': meetup.description,
      'location': meetup.location,
      'dateTime': Timestamp.fromDate(meetup.dateTime),
      'category': meetup.category.name,
      'maxParticipants': meetup.maxParticipants,
      'hostId': meetup.host.id,
      'hostName': meetup.host.name,
      'hostAvatar': meetup.host.avatarUrl,
      'participantIds': meetup.participantIds,
      'imageUrl': meetup.imageUrl,
    };
  }

  // ===================== POSTS =====================

  Stream<List<dynamic>> getFeed() {
    final controller = StreamController<List<dynamic>>();
    final postsStream = getPosts();
    final meetupsStream = getMeetups();

    List<Post>? posts;
    List<Meetup>? meetups;

    StreamSubscription? postsSub;
    StreamSubscription? meetupsSub;

    void emit() {
      final currentPosts = posts ?? [];
      final currentMeetups = meetups ?? [];

      final allItems = <dynamic>[...currentPosts, ...currentMeetups];
      allItems.sort((a, b) {
        final DateTime timeA = a is Post ? a.timestamp : (a as Meetup).dateTime;
        final DateTime timeB = b is Post ? b.timestamp : (b as Meetup).dateTime;
        return timeB.compareTo(timeA);
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

  Stream<List<Post>> getUserPosts(String userId) {
    return _db
        .collection('posts')
        .where('authorId', isEqualTo: userId)
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
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? 'general',
    );
  }

  Future<void> addPost(
    String title,
    String content,
    String authorId,
    String authorName, {
    String? imageUrl,
    String category = 'general',
  }) async {
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
        'likedBy': [],
        'imageUrl': imageUrl ?? '',
        'category': category,
      });
      debugPrint("Post saved successfully!");
    } catch (e) {
      debugPrint("Error saving post: $e");
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final authorId = data['authorId'] ?? '';
    final admin = await isAdmin();

    if (authorId == uid || admin) {
      await _db.collection('posts').doc(postId).delete();
      debugPrint("Post $postId deleted.");
    } else {
      debugPrint("Permission denied: cannot delete post $postId");
    }
  }

  Future<void> toggleLikePost(String postId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('posts').doc(postId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        final authorId = data['authorId'] ?? '';

        if (likedBy.contains(uid)) {
          likedBy.remove(uid);
        } else {
          likedBy.add(uid);
          // Send notification to post author (don't notify self)
          if (authorId != uid) {
            Future.microtask(
              () => sendNotification(
                userId: authorId,
                title: 'New Like ❤️',
                body: 'Someone liked your post!',
                type: 'like',
                relatedId: postId,
              ),
            );
          }
        }

        transaction.update(docRef, {
          'likedBy': likedBy,
          'likes': likedBy.length,
        });
      });
    } catch (e) {
      debugPrint("Error toggling like: $e");
    }
  }

  // ===================== COMMENTS =====================

  Stream<List<Comment>> getComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Comment(
              id: doc.id,
              postId: postId,
              content: data['content'] ?? '',
              authorId: data['authorId'] ?? '',
              authorName: data['authorName'] ?? 'Unknown',
              authorAvatar: data['authorAvatar'] ?? '',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
            );
          }).toList();
        });
  }

  Future<void> addComment(String postId, String content) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to comment');

    final userData = await getCurrentUser();

    try {
      await _db.runTransaction((transaction) async {
        final postRef = _db.collection('posts').doc(postId);
        final commentRef = postRef.collection('comments').doc();

        transaction.set(commentRef, {
          'content': content,
          'authorId': user.uid,
          'authorName': userData?.name ?? 'Unknown',
          'authorAvatar': userData?.avatarUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });

        transaction.update(postRef, {'comments': FieldValue.increment(1)});
      });

      // Send notification to post author
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final authorId = postDoc.data()?['authorId'] ?? '';
        if (authorId.isNotEmpty && authorId != user.uid) {
          await sendNotification(
            userId: authorId,
            title: 'New Comment 💬',
            body: '${userData?.name ?? "Someone"} commented on your post.',
            type: 'comment',
            relatedId: postId,
          );
        }
      }
    } catch (e) {
      debugPrint("Error adding comment: $e");
      rethrow;
    }
  }

  // ===================== QUESTIONS (QnA) =====================

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

  // ===================== ANSWERS =====================

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

  // ===================== MEETUP CHAT =====================

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

  // ===================== JOBS =====================

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

  // ===================== MARKETPLACE =====================

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

  // ===================== DIRECT MESSAGING =====================

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
        });
      });

      // Send notification to other participants
      final convDoc = await _db
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (convDoc.exists) {
        final participants = List<String>.from(
          convDoc.data()?['participantIds'] ?? [],
        );
        for (final pid in participants) {
          if (pid != user.uid) {
            await sendNotification(
              userId: pid,
              title: 'New Message 💬',
              body: '${userData?.name ?? "Someone"}: $content',
              type: 'message',
              relatedId: conversationId,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error sending DM: $e");
      rethrow;
    }
  }

  Future<String> startConversation(String otherUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final query = await _db
        .collection('conversations')
        .where('participantIds', arrayContains: user.uid)
        .get();

    for (var doc in query.docs) {
      final List<dynamic> participants = doc['participantIds'];
      if (participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    final docRef = await _db.collection('conversations').add({
      'participantIds': [user.uid, otherUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts': {user.uid: 0, otherUserId: 0},
      'isGroup': false,
    });

    return docRef.id;
  }

  // ===================== SEARCH =====================

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

  Stream<List<Question>> searchQuestions(String query) {
    return _db
        .collection('questions')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
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

  // ===================== NOTIFICATIONS =====================

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
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ===================== JOINED MEETUPS =====================

  Stream<List<Meetup>> getJoinedMeetups(String userId) {
    return _db
        .collection('meetups')
        .where('participantIds', arrayContains: userId)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => _meetupFromDocument(doc)).toList();
        });
  }

  // ===================== UNREAD NOTIFICATION COUNT =====================

  Stream<int> getUnreadNotificationCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
