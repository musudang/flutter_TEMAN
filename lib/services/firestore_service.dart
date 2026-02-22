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
import 'package:rxdart/rxdart.dart';

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
          ? (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
          : null,
      age: data['age'] as int?,
      personalInfo: data['personalInfo'] ?? '',
      instagramId: data['instagramId'] ?? '',
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
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
      debugPrint("Error fetching user by ID: $e");
    }
    return null;
  }

  Stream<app_models.User?> getUserStream(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return _userFromData(doc.data()!, userId);
      }
      return null;
    });
  }

  Future<void> updateUserProfile({
    required String name,
    required String bio,
    required String nationality,
    String? avatarUrl,
    int? age,
    String? personalInfo,
    String? instagramId,
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
    if (instagramId != null) data['instagramId'] = instagramId;

    await _db.collection('users').doc(uid).update(data);
  }

  Future<bool> isAdmin() async {
    final user = await getCurrentUser();
    return user?.isAdmin ?? false;
  }

  Future<void> followUser(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;
    if (uid == targetUserId) return;

    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(uid);
    final targetUserRef = _db.collection('users').doc(targetUserId);

    batch.update(currentUserRef, {
      'following': FieldValue.arrayUnion([targetUserId]),
    });
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayUnion([uid]),
    });

    await batch.commit();

    // Notify target user
    await sendNotification(
      userId: targetUserId,
      title: 'New Follower 👤',
      body: 'Someone started following you!',
      type: 'follow',
      relatedId: uid,
    );
  }

  Future<void> unfollowUser(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(uid);
    final targetUserRef = _db.collection('users').doc(targetUserId);

    batch.update(currentUserRef, {
      'following': FieldValue.arrayRemove([targetUserId]),
    });
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayRemove([uid]),
    });

    await batch.commit();
  }

  Stream<List<app_models.User>> getFollowers(String userId) {
    return _db
        .collection('users')
        .where('following', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _userFromData(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<List<app_models.User>> getFollowing(String userId) {
    return _db
        .collection('users')
        .where('followers', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _userFromData(doc.data(), doc.id))
              .toList();
        });
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
      debugPrint("Meetup saved successfully!");

      // Create Group Chat for this Meetup
      // actually we can't get the ID if we used .add().
      // But wait, the code says:
      // if (meetup.id.isEmpty) await _db.collection('meetups').add(...)
      // We need the ID.

      DocumentReference docRef;
      if (meetup.id.isEmpty) {
        docRef = await _db.collection('meetups').add(_toDocument(meetup));
      } else {
        docRef = _db.collection('meetups').doc(meetup.id);
        await docRef.set(_toDocument(meetup));
      }

      // Create Group Chat
      await _db.collection('conversations').add({
        'participantIds': [meetup.host.id],
        'lastMessage': 'Meetup created! 👋',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': {meetup.host.id: 0},
        'isGroup': true,
        'groupName': meetup.title,
        'meetupId': docRef.id,
      });
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

        return true;
      });
    } catch (e) {
      debugPrint("Error joining meetup: $e");
      return false;
    } finally {
      // Add to group chat immediately (outside transaction)
      // We need meetup title. We can get it from the doc we fetched or assume we have it.
      // For safety, let's fetch it or just pass empty if we can't.
      // Actually, joinMeetup doesn't return the title easily.
      // We can just rely on _addUserToMeetupChat finding existing chat by ID.
      // If chat doesn't exist, title is needed.
      // Let's optimisticly assume it exists or fetch it.
      // Simpler: Just resolve the title inside _addUser.. if needed or pass "Meetup Chat".

      final doc = await _db.collection('meetups').doc(meetupId).get();
      if (doc.exists) {
        final data = doc.data();
        final title = data?['title'] ?? 'Meetup Chat';
        final hostId = data?['hostId'];
        await _addUserToMeetupChat(meetupId, title, uid);

        // Notify host
        if (hostId != null && hostId != uid) {
          final currentUserData = await getCurrentUser();
          await sendNotification(
            userId: hostId,
            title: 'New Member 🥳',
            body: '${currentUserData?.name ?? 'Someone'} joined your meetup!',
            type: 'meetup_join',
            relatedId: meetupId,
          );
        }
      }
    }
  }

  Future<void> _addUserToMeetupChat(
    String meetupId,
    String meetupTitle,
    String userId,
  ) async {
    try {
      final query = await _db
          .collection('conversations')
          .where('meetupId', isEqualTo: meetupId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        // Chat exists, add user
        final doc = query.docs.first;
        final participants = List<String>.from(doc['participantIds'] ?? []);
        if (!participants.contains(userId)) {
          participants.add(userId);
          await _db.collection('conversations').doc(doc.id).update({
            'participantIds': participants,
            'unreadCounts.$userId': 0,
          });
        }
      } else {
        // Chat doesn't exist, create it
        // We need to fetch the hostId if we want to include them definedly,
        // but often the host is already in participantIds of the meetup.
        // For simplicity, we create a new chat with the current joining user.
        // ideally we should add the host too if they are not the joiner.

        // Fetch meetup to get Host ID
        final meetupDoc = await _db.collection('meetups').doc(meetupId).get();
        final hostId = meetupDoc.data()?['hostId'];

        final newParticipants = <String>{userId};
        if (hostId != null) newParticipants.add(hostId);

        await _db.collection('conversations').add({
          'participantIds': newParticipants.toList(),
          'lastMessage': 'Chat created for $meetupTitle',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'meetupId': meetupId,
          'isGroup': true,
          'groupName': meetupTitle,
          'unreadCounts': {userId: 0},
        });
      }
    } catch (e) {
      debugPrint("Error adding user to meetup chat: $e");
    }
  }

  Future<void> leaveMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);

    try {
      // Find the conversation related to this meetup outside the transaction
      // Add 'participantIds' filter to comply with possible Firestore Security Rules
      // requiring the user to be a participant to read the conversation.
      final conversationQuery = await _db
          .collection('conversations')
          .where('meetupId', isEqualTo: meetupId)
          .where('participantIds', arrayContains: uid)
          .limit(1)
          .get();

      DocumentReference? convRef;
      if (conversationQuery.docs.isNotEmpty) {
        convRef = conversationQuery.docs.first.reference;
      }

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Meetup does not exist!");

        final meetup = _fromDocument(snapshot);
        if (!meetup.participantIds.contains(uid)) {
          return;
        }

        // ALL reads must happen before any writes in a transaction
        DocumentSnapshot? convSnapshot;
        if (convRef != null) {
          convSnapshot = await transaction.get(convRef);
        }

        // Now perform writes
        final updatedParticipants = List<String>.from(meetup.participantIds)
          ..remove(uid);
        transaction.update(docRef, {'participantIds': updatedParticipants});

        if (convSnapshot != null && convSnapshot.exists) {
          final data = convSnapshot.data() as Map<String, dynamic>?;
          if (data != null) {
            final currentParticipants = List<String>.from(
              data['participantIds'] ?? [],
            );
            if (currentParticipants.contains(uid)) {
              currentParticipants.remove(uid);
              transaction.update(convRef!, {
                'participantIds': currentParticipants,
              });
            }
          }
        }
      });
    } catch (e) {
      debugPrint("Error leaving meetup: $e");
    }
  }

  Future<void> deleteMeetup(String meetupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final docSnapshot = await _db.collection('meetups').doc(meetupId).get();
      if (!docSnapshot.exists) return;

      final data = docSnapshot.data();
      if (data != null && data['hostId'] == uid) {
        // Delete the meetup
        await _db.collection('meetups').doc(meetupId).delete();

        // Also try to find and delete the associated conversation
        final query = await _db
            .collection('conversations')
            .where('meetupId', isEqualTo: meetupId)
            .where('participantIds', arrayContains: uid)
            .get();

        for (var doc in query.docs) {
          await _db.collection('conversations').doc(doc.id).delete();
        }
      } else {
        throw Exception('Only the host can delete this meetup');
      }
    } catch (e) {
      debugPrint("Error deleting meetup: $e");
      rethrow;
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
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      scrappedBy: List<String>.from(data['scrappedBy'] ?? []),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
          : DateTime(
              2025,
              1,
              1,
            ), // Fallback to past date to avoid pinning old meetups
    );
  }

  Map<String, dynamic> _toDocument(Meetup meetup) {
    return {
      'title': meetup.title,
      'description': meetup.description,
      'location': meetup.location,
      'dateTime': Timestamp.fromDate(meetup.dateTime),
      'createdAt': Timestamp.fromDate(meetup.createdAt), // [NEW]
      'category': meetup.category.name,
      'maxParticipants': meetup.maxParticipants,
      'hostId': meetup.host.id,
      'hostName': meetup.host.name,
      'hostAvatar': meetup.host.avatarUrl,
      'participantIds': meetup.participantIds,
      'imageUrl': meetup.imageUrl,
      'likes': meetup.likes,
      'comments': meetup.comments,
      'likedBy': meetup.likedBy,
      'scrappedBy': meetup.scrappedBy,
    };
  }

  // ===================== MEETUP LIKES & COMMENTS =====================

  Future<void> toggleLikeMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final likedBy = List<String>.from(data['likedBy'] ?? []);

        if (likedBy.contains(uid)) {
          likedBy.remove(uid);
        } else {
          likedBy.add(uid);
        }

        transaction.update(docRef, {
          'likedBy': likedBy,
          'likes': likedBy.length,
        });
      });
    } catch (e) {
      debugPrint("Error toggling meetup like: $e");
    }
  }

  Stream<List<Comment>> getMeetupComments(String meetupId) {
    return _db
        .collection('meetups')
        .doc(meetupId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Comment(
              id: doc.id,
              postId: meetupId, // Using postId field for meetupId as well
              content: data['content'] ?? '',
              authorId: data['authorId'] ?? '',
              authorName: data['authorName'] ?? 'Unknown',
              authorAvatar: data['authorAvatar'] ?? '',
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList();
        });
  }

  Future<void> addMeetupComment(String meetupId, String content) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to comment');

    final userData = await getCurrentUser();

    try {
      await _db.runTransaction((transaction) async {
        final meetupRef = _db.collection('meetups').doc(meetupId);
        final commentRef = meetupRef.collection('comments').doc();

        transaction.set(commentRef, {
          'content': content,
          'authorId': user.uid,
          'authorName': userData?.name ?? 'Unknown',
          'authorAvatar': userData?.avatarUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });

        transaction.update(meetupRef, {'comments': FieldValue.increment(1)});
      });

      // Notify host
      final meetupDoc = await _db.collection('meetups').doc(meetupId).get();
      if (meetupDoc.exists) {
        final hostId = meetupDoc.data()?['hostId'] ?? '';
        if (hostId.isNotEmpty && hostId != user.uid) {
          await sendNotification(
            userId: hostId,
            title: 'New Meetup Comment 💬',
            body: '${userData?.name ?? "Someone"} commented on your meetup.',
            type: 'comment',
            relatedId: meetupId,
          );
        }
      }
    } catch (e) {
      debugPrint("Error adding meetup comment: $e");
      rethrow;
    }
  }

  // ===================== POSTS =====================

  Future<void> toggleScrapMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final scrappedBy = List<String>.from(data['scrappedBy'] ?? []);

        if (scrappedBy.contains(uid)) {
          scrappedBy.remove(uid);
        } else {
          scrappedBy.add(uid);
        }

        transaction.update(docRef, {'scrappedBy': scrappedBy});
      });
    } catch (e) {
      debugPrint("Error toggling meetup scrap: $e");
    }
  }

  Stream<List<Meetup>> getScrappedMeetups(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _db
        .collection('meetups')
        .where('scrappedBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final meetups = snapshot.docs
              .map((doc) => _meetupFromDocument(doc))
              .toList();
          // Client-side sort
          meetups.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return meetups;
        })
        .handleError((e) {
          debugPrint("Error fetching scrapped meetups: $e");
          return <Meetup>[];
        });
  }

  Stream<List<dynamic>> getScrappedFeed(String userId) {
    final controller = StreamController<List<dynamic>>();
    final postsStream = getScrappedPosts(userId);
    final meetupsStream = getScrappedMeetups(userId);

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

  Stream<List<dynamic>> getFeed() {
    return Rx.combineLatest5<
          List<Post>,
          List<Meetup>,
          List<Job>,
          List<MarketplaceItem>,
          List<Question>,
          List<dynamic>
        >(
          getPosts().onErrorReturnWith((error, stackTrace) {
            debugPrint('Error fetching posts: $error');
            return [];
          }),
          getMeetups().onErrorReturnWith((error, stackTrace) {
            debugPrint('Error fetching meetups: $error');
            return [];
          }),
          getJobs().onErrorReturnWith((error, stackTrace) {
            debugPrint('Error fetching jobs: $error');
            return [];
          }),
          getMarketplaceItems().onErrorReturnWith((error, stackTrace) {
            debugPrint('Error fetching marketplace: $error');
            return [];
          }),
          getQuestions().onErrorReturnWith((error, stackTrace) {
            debugPrint('Error fetching questions: $error');
            return [];
          }),
          (posts, meetups, jobs, marketItems, questions) {
            final List<dynamic> allItems = [
              ...posts,
              ...meetups,
              ...jobs,
              ...marketItems,
              ...questions,
            ];

            allItems.sort((a, b) {
              // Sort descending (newest first)
              DateTime timeA;
              if (a is Post) {
                timeA = a.timestamp;
              } else if (a is Meetup) {
                timeA = a.createdAt;
              } else if (a is Job) {
                timeA = a.postedDate;
              } else if (a is MarketplaceItem) {
                timeA = a.postedDate;
              } else if (a is Question) {
                timeA = a.timestamp;
              } else {
                timeA = DateTime.now();
              }

              DateTime timeB;
              if (b is Post) {
                timeB = b.timestamp;
              } else if (b is Meetup) {
                timeB = b.createdAt;
              } else if (b is Job) {
                timeB = b.postedDate;
              } else if (b is MarketplaceItem) {
                timeB = b.postedDate;
              } else if (b is Question) {
                timeB = b.timestamp;
              } else {
                timeB = DateTime.now();
              }

              return timeB.compareTo(timeA);
            });

            return allItems;
          },
        )
        .handleError((error) {
          debugPrint("Error in feed stream: $error");
          return [];
        });
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
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => _postFromDocument(doc))
              .toList();
          // Client-side sort
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return posts;
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
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? 'general',
      scrappedBy: List<String>.from(data['scrappedBy'] ?? []),
      authorAvatar: data['authorAvatar'] ?? '',
    );
  }

  Future<void> addPost(
    String title,
    String content,
    String authorId,
    String authorName, {
    String? imageUrl,
    String category = 'general',
    String authorAvatar = '',
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
        'authorAvatar': authorAvatar,
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

  Future<void> toggleScrapPost(String postId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('posts').doc(postId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final scrappedBy = List<String>.from(data['scrappedBy'] ?? []);

        if (scrappedBy.contains(uid)) {
          scrappedBy.remove(uid);
        } else {
          scrappedBy.add(uid);
        }

        transaction.update(docRef, {'scrappedBy': scrappedBy});
      });
    } catch (e) {
      debugPrint("Error toggling scrap: $e");
    }
  }

  Stream<List<Post>> getScrappedPosts(String userId) {
    return _db
        .collection('posts')
        .where('scrappedBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => _postFromDocument(doc))
              .toList();
          // Client-side sort
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return posts;
        });
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
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
    // Return a stream that switches to the conversation stream once identified
    final controller = StreamController<List<Message>>();
    StreamSubscription? subscription;

    final conversationStream = _db
        .collection('conversations')
        .where('meetupId', isEqualTo: meetupId)
        .limit(1)
        .snapshots();

    final convSub = conversationStream.listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final convId = snapshot.docs.first.id;
        // Switch to the messages stream
        subscription?.cancel();
        subscription = getChatMessages(convId).listen((messages) {
          controller.add(messages);
        });
      } else {
        controller.add([]);
      }
    });

    controller.onCancel = () {
      convSub.cancel();
      subscription?.cancel();
    };
    return controller.stream;
  }

  Future<void> sendMeetupMessage(String meetupId, String content) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await getCurrentUser();

    // Find conversation
    final query = await _db
        .collection('conversations')
        .where('meetupId', isEqualTo: meetupId)
        .limit(1)
        .get();

    String convId;
    if (query.docs.isNotEmpty) {
      convId = query.docs.first.id;
    } else {
      // Create if missing
      final mDoc = await _db.collection('meetups').doc(meetupId).get();
      final meetupData = mDoc.data() ?? {};
      final title = meetupData['title'] ?? 'Meetup Group';
      final participants = List<String>.from(
        meetupData['participantIds'] ?? [],
      );

      // Ensure current user is in participants (safeguard)
      if (!participants.contains(user.uid)) {
        participants.add(user.uid);
      }

      // Initialize unread counts for all participants
      final unreadCounts = <String, int>{};
      for (final pid in participants) {
        unreadCounts[pid] = 0;
      }

      final docRef = await _db.collection('conversations').add({
        'participantIds': participants,
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'meetupId': meetupId,
        'isGroup': true,
        'groupName': title,
        'unreadCounts': unreadCounts,
      });
      convId = docRef.id;
      // But let's stick to the message sending for now.
    }

    // Add message
    await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .add({
          'senderId': user.uid,
          'senderName': userData?.name ?? 'Unknown',
          'senderAvatar': userData?.avatarUrl ?? '',
          'content': content,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Update conversation
    await _db.collection('conversations').doc(convId).update({
      'lastMessage': content,
      'lastMessageTime': FieldValue.serverTimestamp(),
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
      postedDate: (data['postedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deadline: data['deadline'] != null
          ? (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now()
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
      postedDate: (data['postedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs.map((doc) {
            final data = doc.data();
            return Conversation(
              id: doc.id,
              participantIds: List<String>.from(data['participantIds'] ?? []),
              lastMessage: data['lastMessage'] ?? '',
              lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
              unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
              isGroup: data['isGroup'] ?? false,
              groupName: data['groupName'],
              meetupId: data['meetupId'],
            );
          }).toList();

          // Client-side sort to avoid composite index requirement
          conversations.sort(
            (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
          );
          return conversations;
        });
  }

  Future<void> leaveConversation(String conversationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = _db.collection('conversations').doc(conversationId);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        final participants = List<String>.from(data['participantIds'] ?? []);
        if (participants.contains(uid)) {
          participants.remove(uid);
          // If no participants left, maybe delete?
          // For now just keep it or let a cleanup job handle it.

          transaction.update(docRef, {
            'participantIds': participants,
            'unreadCounts.$uid': FieldValue.delete(),
          });
        }
      });
    } catch (e) {
      debugPrint("Error leaving conversation: $e");
      rethrow;
    }
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
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'groupName': null,
      'meetupId': null,
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
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
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

  Future<void> deleteNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
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
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'userId': userId,
            'title': title,
            'body': body,
            'type': type,
            'relatedId': relatedId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
    } catch (e) {
      debugPrint(
        "❌ Error sending notification to $userId. Please check Firebase Security Rules. $e",
      );
    }
  }

  // ===================== JOINED MEETUPS =====================

  Stream<List<Meetup>> getJoinedMeetups(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _db
        .collection('meetups')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final meetups = snapshot.docs
              .map((doc) => _meetupFromDocument(doc))
              .toList();
          meetups.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return meetups;
        })
        .handleError((e) {
          debugPrint("Error fetching joined meetups: $e");
          return <Meetup>[];
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

  // ===================== RESET DATA =====================

  Future<void> resetAppData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Only allow this if user confirms (UI side)
    // We will delete all collections
    // NOTE: In a real production app, you'd use a cloud function for this.
    // Here we will do best-effort client-side deletion.

    final collections = [
      'posts',
      'meetups',
      'jobs',
      'marketplace',
      'questions',
      'conversations',
      'users', // Delete users last or carefully
    ];

    for (final col in collections) {
      final snapshot = await _db.collection(col).get();
      for (final doc in snapshot.docs) {
        // Don't delete self auth record if you want to keep login, but
        // request said "metadata reset... account delete".
        // If we really want to delete EVERYTHING including accounts, we should also delete auth user.
        // But client SDK cannot delete OTHER users.
        // So we will just delete documents.
        await doc.reference.delete();
      }
    }

    debugPrint("App data reset complete.");
  }
}
