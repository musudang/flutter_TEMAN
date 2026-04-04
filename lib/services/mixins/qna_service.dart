import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart' as app_models;
import '../../models/question_model.dart';
import '../../models/answer_model.dart';
import 'dart:async';

abstract mixin class QnaDependencies {
  Future<app_models.User?> getCurrentUser();
}

mixin QnaService on ChangeNotifier implements QnaDependencies {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Question>> getQuestions({
    int limit = 20,
    List<String> hiddenUsers = const [],
  }) {
    return _db
        .collection('questions')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final questions = snapshot.docs
              .map((doc) => Question.fromFirestore(doc))
              .toList();
          if (hiddenUsers.isEmpty) return questions;
          return questions
              .where((q) => !hiddenUsers.contains(q.authorId))
              .toList();
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

  Future<void> updateQuestion(
    String questionId,
    Map<String, dynamic> data,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db.collection('questions').doc(questionId).get();
    if (!doc.exists) return;

    final docData = doc.data()!;
    if (docData['authorId'] == uid) {
      await _db.collection('questions').doc(questionId).update(data);
    } else {
      throw Exception('Permission denied');
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db.collection('questions').doc(questionId).get();
    if (!doc.exists) return;

    final docData = doc.data()!;
    if (docData['authorId'] == uid) {
      await _db.collection('questions').doc(questionId).delete();
    } else {
      throw Exception('Permission denied');
    }
  }

  Stream<List<Answer>> getAnswers(String questionId) {
    return _db
        .collection('questions')
        .doc(questionId)
        .collection('answers')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Answer.fromFirestore(doc, questionId))
              .toList();
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
}
