import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_constants.dart';
import '../../models/meetup_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart' as app_models;
import '../../models/question_model.dart';
import '../../models/job_model.dart';
import '../../models/marketplace_model.dart';
import '../../models/comment_model.dart';
import 'dart:async';

mixin PostService on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Meetup>> getMeetups({
    int limit = 20,
    List<String> hiddenUsers = const [],
  });
  Stream<List<Job>> getJobs({
    int limit = 20,
    List<String> hiddenUsers = const [],
  });
  Stream<List<MarketplaceItem>> getMarketplaceItems({
    int limit = 20,
    List<String> hiddenUsers = const [],
  });
  Stream<List<Question>> getQuestions({
    int limit = 20,
    List<String> hiddenUsers = const [],
  });
  Future<app_models.User?> getCurrentUser();
  Future<bool> isAdmin();
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  });

  Future<void> toggleScrapMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection(AppConstants.meetupsCollection).doc(meetupId);

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
        .collection(AppConstants.meetupsCollection)
        .where('scrappedBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final meetups = snapshot.docs
              .map((doc) => Meetup.fromFirestore(doc))
              .toList();
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

  Future<List<dynamic>> fetchFeedPage({
    DateTime? lastTimestamp,
    int limit = 10,
    List<String> hiddenUsers = const [],
  }) async {
    final queries = <Future<List<dynamic>>>[];

    // Posts
    Query postsQ = _db
        .collection(AppConstants.postsCollection)
        .orderBy('timestamp', descending: true);
    if (lastTimestamp != null) {
      postsQ = postsQ.where(
        'timestamp',
        isLessThan: Timestamp.fromDate(lastTimestamp),
      );
    }
    queries.add(
      postsQ
          .limit(limit)
          .get()
          .then(
            (snap) => snap.docs
                .map((d) => Post.fromFirestore(d))
                .where((p) => !hiddenUsers.contains(p.authorId))
                .toList(),
          ),
    );

    // Meetups
    Query meetupsQ = _db
        .collection(AppConstants.meetupsCollection)
        .orderBy('createdAt', descending: true);
    if (lastTimestamp != null) {
      meetupsQ = meetupsQ.where(
        'createdAt',
        isLessThan: Timestamp.fromDate(lastTimestamp),
      );
    }
    queries.add(
      meetupsQ
          .limit(limit)
          .get()
          .then(
            (snap) => snap.docs
                .map((d) => Meetup.fromFirestore(d))
                .where((m) => !hiddenUsers.contains(m.host.id))
                .toList(),
          ),
    );

    // Jobs
    Query jobsQ = _db
        .collection(AppConstants.jobsCollection)
        .orderBy('postedDate', descending: true);
    if (lastTimestamp != null) {
      jobsQ = jobsQ.where(
        'postedDate',
        isLessThan: Timestamp.fromDate(lastTimestamp),
      );
    }
    queries.add(
      jobsQ
          .limit(limit)
          .get()
          .then(
            (snap) => snap.docs
                .map((d) => Job.fromFirestore(d))
                .where((j) => !hiddenUsers.contains(j.authorId))
                .toList(),
          ),
    );

    // Market
    Query marketQ = _db
        .collection(AppConstants.marketplaceCollection)
        .orderBy('postedDate', descending: true);
    if (lastTimestamp != null) {
      marketQ = marketQ.where(
        'postedDate',
        isLessThan: Timestamp.fromDate(lastTimestamp),
      );
    }
    queries.add(
      marketQ
          .limit(limit)
          .get()
          .then(
            (snap) => snap.docs
                .map((d) => MarketplaceItem.fromFirestore(d))
                .where((m) => !hiddenUsers.contains(m.sellerId))
                .toList(),
          ),
    );

    // Questions
    Query questionsQ = _db
        .collection(AppConstants.questionsCollection)
        .orderBy('timestamp', descending: true);
    if (lastTimestamp != null) {
      questionsQ = questionsQ.where(
        'timestamp',
        isLessThan: Timestamp.fromDate(lastTimestamp),
      );
    }
    queries.add(
      questionsQ
          .limit(limit)
          .get()
          .then(
            (snap) => snap.docs
                .map((d) => Question.fromFirestore(d))
                .where((q) => !hiddenUsers.contains(q.authorId))
                .toList(),
          ),
    );

    final results = await Future.wait(queries);
    final allItems = results.expand((i) => i).toList();

    allItems.sort((a, b) {
      DateTime timeA = a is Post
          ? a.timestamp
          : a is Meetup
          ? a.createdAt
          : a is Job
          ? a.postedDate
          : a is MarketplaceItem
          ? a.postedDate
          : (a as Question).timestamp;
      DateTime timeB = b is Post
          ? b.timestamp
          : b is Meetup
          ? b.createdAt
          : b is Job
          ? b.postedDate
          : b is MarketplaceItem
          ? b.postedDate
          : (b as Question).timestamp;
      return timeB.compareTo(timeA);
    });

    return allItems.take(limit).toList();
  }

  Stream<List<Post>> getPosts({
    int limit = 20,
    List<String> hiddenUsers = const [],
  }) {
    return _db
        .collection(AppConstants.postsCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => Post.fromFirestore(doc))
              .toList();
          if (hiddenUsers.isEmpty) return posts;
          return posts.where((p) => !hiddenUsers.contains(p.authorId)).toList();
        });
  }

  Stream<Post?> getPostStream(String postId) {
    return _db
        .collection(AppConstants.postsCollection)
        .doc(postId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return Post.fromFirestore(doc);
        });
  }

  Stream<List<Post>> getUserPosts(String userId) {
    return _db
        .collection(AppConstants.postsCollection)
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => Post.fromFirestore(doc))
              .toList();
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return posts;
        });
  }

  Future<void> addPost(
    String title,
    String content,
    String authorId,
    String authorName, {
    String? imageUrl,
    String category = 'general',
    String authorAvatar = '',
    String? subCategory,
    DateTime? eventDate,
  }) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to post');
    }

    try {
      final docData = <String, dynamic>{
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
      };

      if (subCategory != null) {
        docData['subCategory'] = subCategory;
      }
      if (eventDate != null) {
        docData['eventDate'] = Timestamp.fromDate(eventDate);
      }

      await _db.collection(AppConstants.postsCollection).add(docData);
    } catch (e) {
      debugPrint("Error saving post: $e");
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db
        .collection(AppConstants.postsCollection)
        .doc(postId)
        .get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final authorId = data['authorId'] ?? '';
    final admin = await isAdmin();

    if (authorId == uid || admin) {
      final now = DateTime.now();
      await _db.collection('admin_deleted_posts').doc(postId).set({
        ...data,
        'originalPostId': postId,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': uid,
        'scheduledPermanentDeleteAt': Timestamp.fromDate(
          now.add(const Duration(days: 4)),
        ),
      });
      await _db.collection(AppConstants.postsCollection).doc(postId).delete();
    } else {
      throw Exception('Permission denied');
    }
  }

  Future<void> reportPost(
    String postId, {
    String reason = 'Inappropriate content',
    String details = '',
    String type = 'post',
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final reportRef = _db
        .collection(AppConstants.reportsCollection)
        .doc('${postId}_$uid');

    // For posts, we also update the post's report count
    if (type == 'post') {
      final postRef = _db.collection(AppConstants.postsCollection).doc(postId);
      await _db.runTransaction((transaction) async {
        final reportSnapshot = await transaction.get(reportRef);
        if (reportSnapshot.exists) {
          throw Exception("You have already reported this post.");
        }

        final postSnapshot = await transaction.get(postRef);
        if (!postSnapshot.exists) {
          throw Exception("Post does not exist!");
        }

        final postData = postSnapshot.data()!;
        final int currentReports = (postData['reportCount'] ?? 0) as int;
        final bool isRestricted = (postData['isRestricted'] ?? false) as bool;

        transaction.set(reportRef, {
          'postId': postId,
          'reportedBy': uid,
          'reason': reason,
          'details': details,
          'type': type,
          'reportedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        final newReportCount = currentReports + 1;

        if (!isRestricted && newReportCount >= 6) {
          final restrictedPostRef = _db
              .collection('admin_restricted_posts')
              .doc('post_$postId');
          transaction.set(restrictedPostRef, {
            ...postData,
            'originalPostId': postId,
            'restrictedAt': FieldValue.serverTimestamp(),
            'reportCount': newReportCount,
            'status': 'Under Review',
          });

          final restrictionLogRef = _db.collection('user_restrictions').doc();
          transaction.set(restrictionLogRef, {
            'userId': postData['authorId'],
            'postId': postId,
            'postTitle': postData['title'] ?? 'Unknown Title',
            'status': 'Reviewing',
            'createdAt': FieldValue.serverTimestamp(),
            'reason': 'Automatically restricted due to multiple reports.',
          });

          transaction.delete(postRef);
        } else {
          transaction.update(postRef, {'reportCount': newReportCount});
        }
      });
    } else {
      // For meetup, job, marketplace — just submit the report
      final reportSnapshot = await reportRef.get();
      if (reportSnapshot.exists) {
        throw Exception("You have already reported this content.");
      }

      await reportRef.set({
        'postId': postId,
        'reportedBy': uid,
        'reason': reason,
        'details': details,
        'type': type,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    }
  }

  Future<void> restorePost(String postId) async {
    final admin = await isAdmin();
    if (!admin) throw Exception('Permission denied');

    final restrictedPostRef = _db
        .collection('admin_restricted_posts')
        .doc('post_$postId');
    final postRef = _db.collection(AppConstants.postsCollection).doc(postId);

    await _db.runTransaction((transaction) async {
      final restrictedSnapshot = await transaction.get(restrictedPostRef);
      if (!restrictedSnapshot.exists) {
        throw Exception("Post does not exist in restricted list!");
      }

      final postData = restrictedSnapshot.data()!;

      // Remove restriction metadata
      postData.remove('originalPostId');
      postData.remove('restrictedAt');
      postData.remove('status');

      // Reset report count and restriction status
      postData['reportCount'] = 0;
      postData['isRestricted'] = false;

      // Restore to public posts collection
      transaction.set(postRef, postData);

      // Remove from restricted collection
      transaction.delete(restrictedPostRef);
    });
  }

  Future<void> submitContactInquiry({
    required String email,
    required String userId,
    required String school,
    required String content,
  }) async {
    await _db.collection('admin_contact_inquiries').add({
      'email': email,
      'userId': userId,
      'school': school,
      'content': content,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db
        .collection(AppConstants.postsCollection)
        .doc(postId)
        .get();
    if (!doc.exists) return;

    final postData = doc.data()!;
    if (postData['authorId'] == uid) {
      await _db
          .collection(AppConstants.postsCollection)
          .doc(postId)
          .update(data);
    } else {
      throw Exception('Permission denied');
    }
  }

  Future<void> toggleLikePost(String postId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection(AppConstants.postsCollection).doc(postId);

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

    final docRef = _db.collection(AppConstants.postsCollection).doc(postId);

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
        .collection(AppConstants.postsCollection)
        .where('scrappedBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => Post.fromFirestore(doc))
              .toList();
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return posts;
        });
  }

  Stream<List<Comment>> getComments(String postId) {
    return _db
        .collection(AppConstants.postsCollection)
        .doc(postId)
        .collection(AppConstants.commentsCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Comment.fromFirestore(doc, defaultPostId: postId))
              .toList();
        });
  }

  Future<void> addComment(
    String postId,
    String content, {
    String? replyToCommentId,
    String? replyToCommentText,
    String? replyToCommentAuthor,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to comment');

    final userData = await getCurrentUser();

    try {
      await _db.runTransaction((transaction) async {
        final postRef = _db
            .collection(AppConstants.postsCollection)
            .doc(postId);
        final commentRef = postRef
            .collection(AppConstants.commentsCollection)
            .doc();

        final docData = <String, dynamic>{
          'content': content,
          'authorId': user.uid,
          'authorName': userData?.name ?? 'Unknown',
          'authorAvatar': userData?.avatarUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'reactions': {},
        };

        if (replyToCommentId != null) {
          docData['replyToCommentId'] = replyToCommentId;
        }
        if (replyToCommentText != null) {
          docData['replyToCommentText'] = replyToCommentText;
        }
        if (replyToCommentAuthor != null) {
          docData['replyToCommentAuthor'] = replyToCommentAuthor;
        }

        transaction.set(commentRef, docData);
        transaction.update(postRef, {'comments': FieldValue.increment(1)});
      });

      final postDoc = await _db
          .collection(AppConstants.postsCollection)
          .doc(postId)
          .get();
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

  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to delete a comment');

    try {
      await _db.runTransaction((transaction) async {
        final commentRef = _db
            .collection(AppConstants.postsCollection)
            .doc(postId)
            .collection(AppConstants.commentsCollection)
            .doc(commentId);

        final snapshot = await transaction.get(commentRef);
        if (!snapshot.exists) throw Exception('Comment not found');

        final data = snapshot.data();
        if (data?['authorId'] != user.uid) {
          throw Exception('Not authorized to delete this comment');
        }

        final postRef = _db
            .collection(AppConstants.postsCollection)
            .doc(postId);

        transaction.delete(commentRef);
        transaction.update(postRef, {'comments': FieldValue.increment(-1)});
      });
    } catch (e) {
      debugPrint("Error deleting comment: $e");
      rethrow;
    }
  }

  Future<void> toggleCommentReaction({
    required String postId,
    required String commentId,
    required String emoji,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db
        .collection(AppConstants.postsCollection)
        .doc(postId)
        .collection(AppConstants.commentsCollection)
        .doc(commentId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final reactions = Map<String, String>.from(
          data['reactions'] as Map<dynamic, dynamic>? ?? {},
        );

        if (reactions[uid] == emoji) {
          reactions.remove(uid);
        } else {
          reactions[uid] = emoji;
        }

        transaction.update(docRef, {'reactions': reactions});
      });
    } catch (e) {
      debugPrint("Error toggling comment reaction: $e");
    }
  }
}
