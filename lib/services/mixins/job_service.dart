import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/job_model.dart';
import 'dart:async';

mixin JobService on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // dummy

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Job>> getJobs({
    int limit = 20,
    List<String> hiddenUsers = const [],
  }) {
    return _db
        .collection('jobs')
        .orderBy('postedDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => Job.fromFirestore(doc))
              .toList();
          if (hiddenUsers.isEmpty) return jobs;
          return jobs.where((j) => !hiddenUsers.contains(j.authorId)).toList();
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

  Future<void> updateJob(String jobId, Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db.collection('jobs').doc(jobId).get();
    if (!doc.exists) return;

    final docData = doc.data()!;
    if (docData['authorId'] == uid) {
      await _db.collection('jobs').doc(jobId).update(data);
    } else {
      throw Exception('Permission denied');
    }
  }

  Future<void> deleteJob(String jobId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db.collection('jobs').doc(jobId).get();
    if (!doc.exists) return;

    final docData = doc.data()!;
    if (docData['authorId'] == uid) {
      await _db.collection('jobs').doc(jobId).delete();
    } else {
      throw Exception('Permission denied');
    }
  }

  Stream<List<Job>> getUserJobs(String userId) {
    return _db
        .collection('jobs')
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
        });
  }
}
