import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post_model.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart' as app_models;

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
    if (data['authorId'] == uid) {
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
      await _uniDb.runTransaction((transaction) async {
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
      debugPrint("Error toggling university post like: $e");
    }
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
    return _uniDb
        .collection('universities')
        .doc(uniId)
        .collection('questions')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final questions =
          snapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
      if (hiddenUsers.isEmpty) return questions;
      return questions.where((q) => !hiddenUsers.contains(q.authorId)).toList();
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
  }) async {
    if (_uniAuth.currentUser == null) {
      throw Exception('User must be logged in to ask a question');
    }

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
    if (data['authorId'] == uid) {
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

  /// Add an answer to a university question.
  Future<void> addUniversityAnswer(
    String uniId,
    String questionId,
    String content,
  ) async {
    final user = _uniAuth.currentUser;
    if (user == null) throw Exception('Must be logged in to answer');

    final userData = await getCurrentUser();

    await _uniDb.runTransaction((transaction) async {
      final questionRef = _uniDb
          .collection('universities')
          .doc(uniId)
          .collection('questions')
          .doc(questionId);
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
  }
}
