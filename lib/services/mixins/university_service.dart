import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart' as app_models;
import '../../constants/app_constants.dart';

/// Service mixin for university-specific boards.
///
/// Each university has three boards:
///   • General  – stored in `universities/{uniId}/posts` with category='general'
///   • News     – stored in `universities/{uniId}/posts` with category='news'
///   • Q&A      – stored in `universities/{uniId}/questions`
///
/// General and Q&A follow the same logic as the main boards.
/// News is a new board for sharing university-specific news/events.

abstract mixin class UniversityDependencies {
  Future<app_models.User?> getCurrentUser();
}

mixin UniversityService on ChangeNotifier implements UniversityDependencies {
  final FirebaseFirestore _uniDb = FirebaseFirestore.instance;
  final FirebaseAuth _uniAuth = FirebaseAuth.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<bool> _isAdminCheck() async {
    final user = await getCurrentUser();
    return user?.isAdmin ?? false;
  }

  // ──────────────────────────────────────────────
  // University Posts (General + News)
  // ──────────────────────────────────────────────

  /// Stream of university posts, optionally filtered by category.
  Stream<List<Post>> getUniversityPosts(
    String uniId, {
    String? category,
    int limit = 30,
    List<String> hiddenUsers = const [],
  }) {
    Query query = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      final posts =
          snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      if (hiddenUsers.isEmpty) return posts;
      return posts.where((p) => !hiddenUsers.contains(p.authorId)).toList();
    });
  }

  /// Get specific user's university posts from a known university
  Stream<List<Post>> getUniversityPostsByUser(String uniId, String userId) {
    return _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    });
  }

  /// Add a post to a university board (general or news).
  Future<void> addUniversityPost(
    String uniId, {
    required String title,
    required String content,
    required String authorId,
    required String authorName,
    String authorAvatar = '',
    List<String> imageUrls = const [],
    String category = 'general', // 'general' or 'news'
    bool isAnonymous = false,
  }) async {
    if (_uniAuth.currentUser == null) {
      throw Exception('User must be logged in to post');
    }

    final userData = await getCurrentUser();

    await _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .add({
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'title': title,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'comments': 0,
      'likedBy': [],
      'scrappedBy': [],
      'imageUrls': imageUrls,
      'category': category,
      'isAnonymous': isAnonymous,
      'authorUniversityId': userData?.universityId,
    });
  }

  /// Delete a university post.
  Future<void> deleteUniversityPost(String uniId, String postId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId)
        .get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final admin = await _isAdminCheck();
    if (data['authorId'] == uid || admin) {
      await _uniDb
          .collection('universities')
          .doc(uniId)
          .collection('posts')
          .doc(postId)
          .delete();
    } else {
      throw Exception('Permission denied');
    }
  }

  /// Toggle like on a university post.
  Future<void> toggleLikeUniversityPost(String uniId, String postId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId);

    try {
      String? postAuthorId;
      bool wasLiked = false;

      await _uniDb.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        postAuthorId = data['authorId'] as String?;

        if (likedBy.contains(uid)) {
          likedBy.remove(uid);
          wasLiked = false;
        } else {
          likedBy.add(uid);
          wasLiked = true;
        }

        transaction.update(docRef, {
          'likedBy': likedBy,
          'likes': likedBy.length,
        });
      });

      if (wasLiked && postAuthorId != null && postAuthorId != uid) {
        final userData = await getCurrentUser();
        final likerName = userData?.name ?? 'Someone';
        final notifDb = FirebaseFirestore.instance;
        await notifDb
            .collection('users')
            .doc(postAuthorId)
            .collection('notifications')
            .add({
          'userId': postAuthorId,
          'title': 'New Like',
          'body': '$likerName liked your university post!',
          'type': 'uni_like',
          'relatedId': postId,
          'uniId': uniId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    } catch (e) {
      debugPrint("Error toggling university post like: $e");
    }
  }

  /// Toggle scrap (bookmark) on a university post.
  Future<void> toggleScrapUniversityPost(String uniId, String postId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId);

    try {
      await _uniDb.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final scrappedBy = List<String>.from(data['scrappedBy'] ?? []);
        
        if (scrappedBy.contains(uid)) {
          scrappedBy.remove(uid);
        } else {
          scrappedBy.add(uid);
        }
        
        transaction.update(docRef, {
          'scrappedBy': scrappedBy,
          'scrapCount': scrappedBy.length,
        });
      });
    } catch (e) {
      debugPrint("Error toggling university post scrap: $e");
    }
  }

  /// Get user's scrapped university posts
  Stream<List<Post>> getScrappedUniversityPosts(String uniId, String userId) {
    if (uniId.isEmpty || userId.isEmpty) return Stream.value([]);
    return _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .where('scrappedBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    });
  }

  /// Get user's scrapped university questions
  Stream<List<Question>> getScrappedUniversityQuestions(String uniId, String userId) {
    if (uniId.isEmpty || userId.isEmpty) return Stream.value([]);
    return _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .where('scrappedBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final questions = snapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
      questions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return questions;
    });
  }

  /// Increment share count for a university post.
  Future<void> incrementShareUniversityPost(String uniId, String postId) async {
    final docRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId);
    try {
      await docRef.update({
        'shareCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint("Error incrementing university post share count: $e");
    }
  }

  // ──────────────────────────────────────────────
  // University Post Comments (with reply + anonymous)
  //
  // Mirrors the main-board comment system:
  //   universities/{uniId}/posts/{postId}/comments/{commentId}
  // Supports `replyToCommentId` for nested replies and `isAnonymous` /
  // `anonymousIndex` for thread-scoped anonymous numbering.
  // ──────────────────────────────────────────────

  Stream<List<Comment>> getUniversityPostComments(String uniId, String postId) {
    return _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Comment.fromFirestore(doc, defaultPostId: postId))
          .toList();
    });
  }

  Future<void> addUniversityPostComment(
    String uniId,
    String postId,
    String content, {
    String? replyToCommentId,
    String? replyToCommentText,
    String? replyToCommentAuthor,
    bool isAnonymous = false,
  }) async {
    final user = _uniAuth.currentUser;
    if (user == null) throw Exception('Must be logged in to comment');

    final userData = await getCurrentUser();

    final commentsRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId)
        .collection('comments');

    try {
      // Compute thread-scoped anonymous index (reuse same number for the
      // same author across the thread, like main posts).
      int? anonymousIndex;
      if (isAnonymous) {
        final anonSnapshot =
            await commentsRef.where('isAnonymous', isEqualTo: true).get();
        final Map<String, int> authorIndexMap = {};
        int maxIndex = 0;
        for (var doc in anonSnapshot.docs) {
          final data = doc.data();
          final aId = data['authorId'] as String? ?? '';
          final aIdx = data['anonymousIndex'] as int?;
          if (aId.isNotEmpty && aIdx != null) {
            authorIndexMap[aId] = aIdx;
            if (aIdx > maxIndex) maxIndex = aIdx;
          }
        }
        anonymousIndex =
            authorIndexMap[user.uid] ?? (maxIndex + 1);
      }

      final postRef = _uniDb
          .collection('universities')
          .doc(uniId)
          .collection('posts')
          .doc(postId);

      await _uniDb.runTransaction((transaction) async {
        final commentRef = commentsRef.doc();
        final docData = <String, dynamic>{
          'content': content,
          'authorId': user.uid,
          'authorName': userData?.name ?? 'Unknown',
          'authorAvatar': userData?.avatarUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'reactions': {},
          'authorUniversityId': userData?.universityId,
          'isAnonymous': isAnonymous,
        };
        if (isAnonymous && anonymousIndex != null) {
          docData['anonymousIndex'] = anonymousIndex;
        }
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

      // Notifications — main `users/{uid}/notifications` subcollection
      // is on the primary FirebaseFirestore instance (`_db` is not
      // accessible from this mixin, so use FirebaseFirestore.instance).
      final notifDb = FirebaseFirestore.instance;

      // 1) Notify post author when someone (else) comments
      try {
        final postSnap = await postRef.get();
        final postAuthorId = postSnap.data()?['authorId'] ?? '';
        if (postAuthorId.isNotEmpty && postAuthorId != user.uid) {
          await notifDb
              .collection('users')
              .doc(postAuthorId)
              .collection('notifications')
              .add({
            'userId': postAuthorId,
            'title': 'New Comment',
            'body': isAnonymous
                ? 'Someone commented anonymously on your university post.'
                : '${userData?.name ?? "Someone"} commented on your university post.',
            'type': 'uni_comment',
            'relatedId': postId,
            'uniId': uniId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }

        // 2) Reply notification — also notify parent comment author.
        if (replyToCommentId != null) {
          final parentSnap = await commentsRef.doc(replyToCommentId).get();
          final parentAuthorId = parentSnap.data()?['authorId'] ?? '';
          if (parentAuthorId.isNotEmpty &&
              parentAuthorId != user.uid &&
              parentAuthorId != postAuthorId) {
            await notifDb
                .collection('users')
                .doc(parentAuthorId)
                .collection('notifications')
                .add({
              'userId': parentAuthorId,
              'title': 'New Reply',
              'body': isAnonymous
                  ? 'Someone replied to your comment anonymously.'
                  : '${userData?.name ?? "Someone"} replied to your comment.',
              'type': 'uni_reply',
              'relatedId': postId,
              'uniId': uniId,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        }
      } catch (e) {
        debugPrint('University comment notification skipped: $e');
      }
    } catch (e) {
      debugPrint("Error adding university post comment: $e");
      rethrow;
    }
  }

  Future<void> deleteUniversityPostComment(
    String uniId,
    String postId,
    String commentId,
  ) async {
    final user = _uniAuth.currentUser;
    if (user == null) return;

    final commentsRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId)
        .collection('comments');
    final postRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId);

    try {
      // Soft-delete if any replies exist; otherwise hard-delete.
      final replies = await commentsRef
          .where('replyToCommentId', isEqualTo: commentId)
          .limit(1)
          .get();
      final hasReplies = replies.docs.isNotEmpty;

      final admin = await _isAdminCheck();
      await _uniDb.runTransaction((transaction) async {
        final commentRef = commentsRef.doc(commentId);
        final snap = await transaction.get(commentRef);
        if (!snap.exists) return;
        final data = snap.data();
        if (data?['authorId'] != user.uid && !admin) {
          throw Exception('Only the comment author can delete');
        }

        if (hasReplies) {
          transaction.update(commentRef, {
            'isDeleted': true,
            'content': '',
            'authorAvatar': '',
          });
        } else {
          transaction.delete(commentRef);
          transaction.update(postRef, {'comments': FieldValue.increment(-1)});
        }
      });
    } catch (e) {
      debugPrint("Error deleting university comment: $e");
      rethrow;
    }
  }

  /// Toggle an emoji reaction on a university post comment.
  /// Mirrors `PostService.toggleCommentReaction` for the main board so
  /// the comment UX is identical across both feeds.
  Future<void> toggleUniversityCommentReaction({
    required String uniId,
    required String postId,
    required String commentId,
    required String emoji,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final commentRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    try {
      await _uniDb.runTransaction((transaction) async {
        final snap = await transaction.get(commentRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
        // Toggle: same emoji again clears it; otherwise overwrite.
        if (reactions[uid] == emoji) {
          reactions.remove(uid);
        } else {
          reactions[uid] = emoji;
        }
        transaction.update(commentRef, {'reactions': reactions});
      });
    } catch (e) {
      debugPrint("Error toggling university comment reaction: $e");
    }
  }



  /// Edit own university post — owner-only.
  Future<void> updateUniversityPost(
    String uniId,
    String postId, {
    String? title,
    String? content,
    List<String>? imageUrls,
    bool? isAnonymous,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Must be logged in');

    final docRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId);

    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Post not found');
    if (snap.data()?['authorId'] != uid) {
      throw Exception('Not authorized to edit this post');
    }

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (imageUrls != null) updates['imageUrls'] = imageUrls;
    if (isAnonymous != null) updates['isAnonymous'] = isAnonymous;
    if (updates.isEmpty) return;
    await docRef.update(updates);
  }

  // ──────────────────────────────────────────────
  // University Reports
  // ──────────────────────────────────────────────

  /// Report a university post. If reports >= 5, remove it automatically.
  Future<void> reportUniversityPost(String uniId, String postId, {required String reason, required String details}) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Must be logged in to report');

    final reportRef = _uniDb
        .collection(AppConstants.reportsCollection)
        .doc('${postId}_$uid');

    final postRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('posts')
        .doc(postId);

    await _uniDb.runTransaction((transaction) async {
      final reportSnapshot = await transaction.get(reportRef);
      if (reportSnapshot.exists) {
        throw Exception("You have already reported this post.");
      }

      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) {
        throw Exception("Post does not exist!");
      }

      final postData = postSnapshot.data()!;
      final int currentReports = (postData['reportCount'] as num?)?.toInt() ?? 0;
      final bool isRestricted = (postData['isRestricted'] as bool?) ?? false;

      transaction.set(reportRef, {
        'postId': postId,
        'reportedBy': uid,
        'reason': reason,
        'details': details,
        'type': 'university_post',
        'uniId': uniId,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      final newReportCount = currentReports + 1;

      if (!isRestricted && newReportCount >= 5) {
        final restrictedPostRef = _uniDb
            .collection('admin_restricted_posts')
            .doc('unipost_$postId');
        transaction.set(restrictedPostRef, {
          ...postData,
          'originalPostId': postId,
          'uniId': uniId,
          'restrictedAt': FieldValue.serverTimestamp(),
          'reportCount': newReportCount,
          'status': 'Under Review',
        });

        final restrictionLogRef = _uniDb.collection('user_restrictions').doc();
        transaction.set(restrictionLogRef, {
          'userId': postData['authorId'],
          'postId': postId,
          'postTitle': postData['title'] ?? 'Unknown Title',
          'uniId': uniId,
          'status': 'Reviewing',
          'createdAt': FieldValue.serverTimestamp(),
          'reason': 'Automatically restricted due to multiple reports.',
        });

        transaction.delete(postRef);
      } else {
        transaction.update(postRef, {'reportCount': newReportCount});
      }
    });
  }

  /// Report a university question. If reports >= 5, remove it automatically.
  Future<void> reportUniversityQuestion(String uniId, String questionId, {required String reason, required String details}) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Must be logged in to report');

    final reportRef = _uniDb
        .collection(AppConstants.reportsCollection)
        .doc('${questionId}_$uid');

    final qRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .doc(questionId);

    await _uniDb.runTransaction((transaction) async {
      final reportSnapshot = await transaction.get(reportRef);
      if (reportSnapshot.exists) {
        throw Exception("You have already reported this question.");
      }

      final qSnapshot = await transaction.get(qRef);
      if (!qSnapshot.exists) {
        throw Exception("Question does not exist!");
      }

      final qData = qSnapshot.data()!;
      final int currentReports = (qData['reportCount'] as num?)?.toInt() ?? 0;
      final bool isRestricted = (qData['isRestricted'] as bool?) ?? false;

      transaction.set(reportRef, {
        'postId': questionId,
        'reportedBy': uid,
        'reason': reason,
        'details': details,
        'type': 'university_question',
        'uniId': uniId,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      final newReportCount = currentReports + 1;

      if (!isRestricted && newReportCount >= 5) {
        final restrictedRef = _uniDb
            .collection('admin_restricted_posts')
            .doc('uniqna_$questionId');
        transaction.set(restrictedRef, {
          ...qData,
          'originalPostId': questionId,
          'uniId': uniId,
          'restrictedAt': FieldValue.serverTimestamp(),
          'reportCount': newReportCount,
          'status': 'Under Review',
        });

        final restrictionLogRef = _uniDb.collection('user_restrictions').doc();
        transaction.set(restrictionLogRef, {
          'userId': qData['authorId'],
          'postId': questionId,
          'postTitle': qData['title'] ?? 'Unknown Title',
          'uniId': uniId,
          'status': 'Reviewing',
          'createdAt': FieldValue.serverTimestamp(),
          'reason': 'Automatically restricted due to multiple reports.',
        });

        transaction.delete(qRef);
      } else {
        transaction.update(qRef, {'reportCount': newReportCount});
      }
    });
  }

  // ──────────────────────────────────────────────
  // University Q&A
  // ──────────────────────────────────────────────

  /// Stream of university questions.
  Stream<List<Question>> getUniversityQuestions(
    String uniId, {
    int limit = 30,
    List<String> hiddenUsers = const [],
  }) {
    final query = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .orderBy('timestamp', descending: true)
        .limit(limit);
    return query.snapshots().map((snapshot) {
      final questions =
          snapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
      if (hiddenUsers.isEmpty) return questions;
      return questions.where((q) => !hiddenUsers.contains(q.authorId)).toList();
    });
  }

  /// Get specific user's university questions from a known university
  Stream<List<Question>> getUniversityQuestionsByUser(String uniId, String userId) {
    return _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final questions = snapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
      questions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return questions;
    });
  }

  /// Add a question to a university board.
  Future<void> addUniversityQuestion(
    String uniId, {
    required String title,
    required String content,
    required String authorId,
    required String authorName,
    String authorAvatar = '',
    List<String> imageUrls = const [],
    bool isAnonymous = false,
  }) async {
    if (_uniAuth.currentUser == null) {
      throw Exception('User must be logged in to ask a question');
    }

    final userData = await getCurrentUser();

    await _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .add({
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'timestamp': FieldValue.serverTimestamp(),
      'answersCount': 0,
      'imageUrls': imageUrls,
      'isAnonymous': isAnonymous,
      'authorUniversityId': userData?.universityId,
    });
  }

  /// Delete a university question.
  Future<void> deleteUniversityQuestion(
      String uniId, String questionId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .doc(questionId)
        .get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final admin = await _isAdminCheck();
    if (data['authorId'] == uid || admin) {
      await _uniDb
          .collection('universities')
          .doc(uniId)
          .collection('questions')
          .doc(questionId)
          .delete();
    } else {
      throw Exception('Permission denied');
    }
  }

  /// Get answers for a university question.
  Stream<List<Map<String, dynamic>>> getUniversityAnswers(
    String uniId,
    String questionId,
  ) {
    return _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .doc(questionId)
        .collection('answers')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Stream of university posts scrapped (bookmarked) by [userId],
  /// across ALL university subcollections (not just their own).
  /// Uses a collectionGroup query — requires a COLLECTION_GROUP-scoped
  /// index on `scrappedBy` (see `firestore.indexes.json`).
  ///
  /// Distinct from `getScrappedUniversityPosts(uniId, userId)` above,
  /// which is scoped to a single university subcollection.
  Stream<List<Post>> getAllScrappedUniversityPosts(String userId) {
    return _uniDb
        .collectionGroup('posts')
        .where('scrappedBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final posts = <Post>[];
      for (var doc in snapshot.docs) {
        // Restrict to docs under universities/{uniId}/posts/{postId}
        // so the query doesn't accidentally pull in main-feed posts too.
        final segs = doc.reference.path.split('/');
        if (segs.length >= 4 && segs[0] == 'universities') {
          try {
            posts.add(Post.fromFirestore(doc));
          } catch (_) {}
        }
      }
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    });
  }

  /// Stream of all university posts authored by a specific user.
  /// Uses a collectionGroup query to search across all university post subcollections.
  Stream<List<Post>> getUserUniversityPosts(String userId) {
    return _uniDb
        .collectionGroup('posts')
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final posts = <Post>[];
      for (var doc in snapshot.docs) {
        // Only include docs from university subcollections (path: universities/{uniId}/posts/{postId})
        final pathSegments = doc.reference.path.split('/');
        if (pathSegments.length >= 4 && pathSegments[0] == 'universities') {
          try {
            final post = Post.fromFirestore(doc);
            posts.add(post);
          } catch (_) {}
        }
      }
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    });
  }

  /// Add an answer to a university question.
  Future<void> addUniversityAnswer(
    String uniId,
    String questionId,
    String content, {
    bool isAnonymous = false,
  }) async {
    final user = _uniAuth.currentUser;
    if (user == null) throw Exception('Must be logged in to answer');

    final userData = await getCurrentUser();
    final answersRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .doc(questionId)
        .collection('answers');

    // Compute thread-scoped anonymous index (same logic as comments).
    int? anonymousIndex;
    if (isAnonymous) {
      final anonSnap =
          await answersRef.where('isAnonymous', isEqualTo: true).get();
      final Map<String, int> idxMap = {};
      int maxIdx = 0;
      for (var doc in anonSnap.docs) {
        final data = doc.data();
        final aId = data['authorId'] as String? ?? '';
        final aIdx = data['anonymousIndex'] as int?;
        if (aId.isNotEmpty && aIdx != null) {
          idxMap[aId] = aIdx;
          if (aIdx > maxIdx) maxIdx = aIdx;
        }
      }
      anonymousIndex = idxMap[user.uid] ?? (maxIdx + 1);
    }

    await _uniDb.runTransaction((transaction) async {
      final questionRef = _uniDb
          .collection('universities')
          .doc(uniId)
          .collection('questions')
          .doc(questionId);
      final answerRef = answersRef.doc();

      final docData = <String, dynamic>{
        'content': content,
        'authorId': user.uid,
        'authorName': userData?.name ?? 'Unknown',
        'authorAvatar': userData?.avatarUrl ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'authorUniversityId': userData?.universityId,
        'isAnonymous': isAnonymous,
      };
      if (isAnonymous && anonymousIndex != null) {
        docData['anonymousIndex'] = anonymousIndex;
      }
      transaction.set(answerRef, docData);

      transaction.update(questionRef, {
        'answersCount': FieldValue.increment(1),
      });
    });
  }

  /// Delete own university answer (hard delete — answers don't have
  /// nested replies so soft-delete isn't needed).
  Future<void> deleteUniversityAnswer(
    String uniId,
    String questionId,
    String answerId,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    final answerRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .doc(questionId)
        .collection('answers')
        .doc(answerId);
    final questionRef = _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .doc(questionId);

    try {
      final admin = await _isAdminCheck();
      await _uniDb.runTransaction((transaction) async {
        final snap = await transaction.get(answerRef);
        if (!snap.exists) return;
        if (snap.data()?['authorId'] != uid && !admin) {
          throw Exception('Only the answer author can delete');
        }
        transaction.delete(answerRef);
        transaction.update(questionRef, {
          'answersCount': FieldValue.increment(-1),
        });
      });
    } catch (e) {
      debugPrint("Error deleting university answer: $e");
      rethrow;
    }
  }
}
