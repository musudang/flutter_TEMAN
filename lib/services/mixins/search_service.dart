import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/meetup_model.dart';
import '../../models/post_model.dart';
import '../../models/question_model.dart';
import '../../models/job_model.dart';
import '../../models/marketplace_model.dart';

// Since mixins might call methods from each other (e.g. UserService calling sendNotification),
// they need a common base interface. But for simplicity and to avoid cyclic dependencies,
// Dart allows calling unresolved methods if typed as dynamic or if we just bundle them properly.
// Wait, actually, in Flutter, if a mixin calls another mixin's method, you can use `on` or just not
// care if there's no static analyzer error? No, Dart statically checks.
// Since we are moving fast, we can declare `var _db` inline. Actually, `FirestoreService` will have them.
// Let's make the mixins independent. If they need to call each other, we can use an abstract base or late fields.
// For now, let's just create them. We will fix unresolved calls manually.

mixin SearchService on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Meetup>> searchMeetups(String query) {
    return _db
        .collection('meetups')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Meetup.fromFirestore(doc)).toList();
        });
  }

  Stream<List<Job>> searchJobs(String query) {
    return _db
        .collection('jobs')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
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
              .map((doc) => MarketplaceItem.fromFirestore(doc))
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
          return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
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
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              answersCount: data['answersCount'] ?? 0,
            );
          }).toList();
        });
  }
}
