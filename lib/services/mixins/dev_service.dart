import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// Since mixins might call methods from each other (e.g. UserService calling sendNotification),
// they need a common base interface. But for simplicity and to avoid cyclic dependencies,
// Dart allows calling unresolved methods if typed as dynamic or if we just bundle them properly.
// Wait, actually, in Flutter, if a mixin calls another mixin's method, you can use `on` or just not
// care if there's no static analyzer error? No, Dart statically checks.
// Since we are moving fast, we can declare `var _db` inline. Actually, `FirestoreService` will have them.
// Let's make the mixins independent. If they need to call each other, we can use an abstract base or late fields.
// For now, let's just create them. We will fix unresolved calls manually.

mixin DevService on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // dummy

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

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
