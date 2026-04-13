import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/job_model.dart';
import 'dart:async';

mixin JobService on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // dummy

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Job>> getJobs({
    int limit = 20,
    List<String> hiddenUsers = const [],
    String? jobType,
  }) {
    Query query = _db.collection('jobs').orderBy('postedDate', descending: true);
    if (jobType != null && jobType != 'All') {
      query = query.where('jobType', isEqualTo: jobType);
    }

    return query.limit(limit).snapshots().map((snapshot) {
      final jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
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
        'location': job.location,
        'salary': job.salary,
        'jobType': job.jobType,
        'description': job.description,
        'requirements': job.requirements,
        'contactInfo': job.contactInfo,
        'authorId': _auth.currentUser!.uid,
        'postedDate': FieldValue.serverTimestamp(),
        'deadline': job.deadline != null
            ? Timestamp.fromDate(job.deadline!)
            : null,
        'isActive': job.isActive,
        'imageUrls': job.imageUrls,
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
      // Delete images from Storage
      final imageUrls = List<String>.from(docData['imageUrls'] ?? []);
      await _deleteStorageFiles(imageUrls);

      await _db.collection('jobs').doc(jobId).delete();
    } else {
      throw Exception('Permission denied');
    }
  }

  // --- Apply Now: Job Applications ---

  /// Check if current user has already applied to a job
  Future<bool> hasAppliedToJob(String jobId) async {
    final uid = currentUserId;
    if (uid == null) return false;

    final doc = await _db
        .collection('job_applications')
        .doc('${jobId}_$uid')
        .get();
    return doc.exists;
  }

  /// Apply to a job with a custom message
  Future<void> applyToJob({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required String message,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    final docId = '${jobId}_$uid';
    final existing = await _db.collection('job_applications').doc(docId).get();
    if (existing.exists) {
      throw Exception('You have already applied to this job.');
    }

    await _db.collection('job_applications').doc(docId).set({
      'jobId': jobId,
      'jobTitle': jobTitle,
      'applicantId': uid,
      'employerId': employerId,
      'message': message,
      'appliedAt': FieldValue.serverTimestamp(),
    });
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

  /// Helper: Delete files from Firebase Storage given their download URLs
  Future<void> _deleteStorageFiles(List<String> urls) async {
    for (final url in urls) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        debugPrint("Warning: Could not delete storage file: $e");
      }
    }
  }
}
