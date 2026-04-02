import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import 'dart:async';

// Since mixins might call methods from each other (e.g. UserService calling sendNotification),
// they need a common base interface. But for simplicity and to avoid cyclic dependencies, 
// Dart allows calling unresolved methods if typed as dynamic or if we just bundle them properly.
// Wait, actually, in Flutter, if a mixin calls another mixin's method, you can use `on` or just not 
// care if there's no static analyzer error? No, Dart statically checks.
// Since we are moving fast, we can declare `var _db` inline. Actually, `FirestoreService` will have them.
// Let's make the mixins independent. If they need to call each other, we can use an abstract base or late fields.
// For now, let's just create them. We will fix unresolved calls manually.

mixin NotificationService on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // dummy

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;


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

  Future<void> deleteAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error deleting all notifications: $e");
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
    String? relatedId,
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
            'relatedId': relatedId ?? '',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
    } catch (e) {
      debugPrint(
        "??Error sending notification to $userId. Please check Firebase Security Rules. $e",
      );
    }
  }

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

