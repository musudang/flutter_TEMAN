import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/meetup_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart' as app_models;
import '../../models/question_model.dart';
import '../../models/job_model.dart';
import '../../models/marketplace_model.dart';
import '../../models/comment_model.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

mixin PostService on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Meetup>> getMeetups();
  Stream<List<Job>> getJobs();
  Stream<List<MarketplaceItem>> getMarketplaceItems();
  Stream<List<Question>> getQuestions();
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
          return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
        });
  }

  Stream<Post?> getPostStream(String postId) {
    return _db.collection('posts').doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Post.fromFirestore(doc);
    });
  }

  Stream<List<Post>> getUserPosts(String userId) {
    return _db
        .collection('posts')
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

      await _db.collection('posts').add(docData);
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
      await _db.collection('posts').doc(postId).delete();
    } else {
      throw Exception('Permission denied');
    }
  }

  Future<void> reportPost(String postId, {String reason = 'Inappropriate content', String details = ''}) async {
    final uid = currentUserId;
    if (uid == null) return;

    final postRef = _db.collection('posts').doc(postId);
    final reportRef = _db.collection('admin_reports').doc('${postId}_$uid');

    await _db.runTransaction((transaction) async {
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
        'type': 'post',
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      final newReportCount = currentReports + 1;
      
      if (!isRestricted && newReportCount >= 6) {
        final restrictedPostRef = _db.collection('admin_restricted_posts').doc('post_$postId');
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
        transaction.update(postRef, {
          'reportCount': newReportCount,
        });
      }
    });
  }

  Future<void> restorePost(String postId) async {
    final admin = await isAdmin();
    if (!admin) throw Exception('Permission denied');

    final restrictedPostRef = _db.collection('admin_restricted_posts').doc('post_$postId');
    final postRef = _db.collection('posts').doc(postId);

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

    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) return;

    final postData = doc.data()!;
    if (postData['authorId'] == uid) {
      await _db.collection('posts').doc(postId).update(data);
    } else {
      throw Exception('Permission denied');
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
              .map((doc) => Post.fromFirestore(doc))
              .toList();
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return posts;
        });
  }

  Stream<List<Comment>> getComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Comment.fromFirestore(doc, defaultPostId: postId)).toList();
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
        final postRef = _db.collection('posts').doc(postId);
        final commentRef = postRef.collection('comments').doc();

        final docData = <String, dynamic>{
          'content': content,
          'authorId': user.uid,
          'authorName': userData?.name ?? 'Unknown',
          'authorAvatar': userData?.avatarUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'reactions': {},
        };

        if (replyToCommentId != null) docData['replyToCommentId'] = replyToCommentId;
        if (replyToCommentText != null) docData['replyToCommentText'] = replyToCommentText;
        if (replyToCommentAuthor != null) docData['replyToCommentAuthor'] = replyToCommentAuthor;

        transaction.set(commentRef, docData);
        transaction.update(postRef, {'comments': FieldValue.increment(1)});
      });

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

  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to delete a comment');

    try {
      await _db.runTransaction((transaction) async {
        final commentRef = _db
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(commentId);

        final snapshot = await transaction.get(commentRef);
        if (!snapshot.exists) throw Exception('Comment not found');

        final data = snapshot.data();
        if (data?['authorId'] != user.uid) {
          throw Exception('Not authorized to delete this comment');
        }

        final postRef = _db.collection('posts').doc(postId);

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
        .collection('posts')
        .doc(postId)
        .collection('comments')
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
