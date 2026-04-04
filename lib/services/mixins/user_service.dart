import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart' as app_models;
import 'dart:async';

// Since mixins might call methods from each other (e.g. UserService calling sendNotification),
// they need a common base interface. But for simplicity and to avoid cyclic dependencies,
// Dart allows calling unresolved methods if typed as dynamic or if we just bundle them properly.
// Wait, actually, in Flutter, if a mixin calls another mixin's method, you can use `on` or just not
// care if there's no static analyzer error? No, Dart statically checks.
// Since we are moving fast, we can declare `var _db` inline. Actually, `FirestoreService` will have them.
// Let's make the mixins independent. If they need to call each other, we can use an abstract base or late fields.
// For now, let's just create them. We will fix unresolved calls manually.

abstract mixin class UserDependencies {
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  });
}

mixin UserService on ChangeNotifier implements UserDependencies {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // dummy

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<app_models.User?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          return _userFromData(data, user.uid);
        }
      } else {
        debugPrint("User doc missing. Auto-creating for ${user.uid}");
        final newUser = app_models.User(
          id: user.uid,
          name: user.displayName ?? 'User',
          avatarUrl: user.photoURL ?? '',
          nationality: 'Global ?��',
          email: user.email ?? '',
        );

        await _db.collection('users').doc(user.uid).set({
          'id': newUser.id,
          'name': newUser.name,
          'email': user.email ?? '',
          'avatarUrl': newUser.avatarUrl,
          'nationality': newUser.nationality,
          'bio': '',
          'role': 'user',
          'age': null,
          'personalInfo': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return newUser;
      }
    } catch (e) {
      debugPrint("Error fetching/creating user from Firestore: $e");
    }

    return app_models.User(
      id: user.uid,
      name: user.displayName ?? 'User',
      avatarUrl: user.photoURL ?? '',
      nationality: 'Global ?��',
      email: user.email ?? '',
    );
  }

  app_models.User _userFromData(Map<String, dynamic> data, String fallbackId) {
    return app_models.User(
      id: data['id'] ?? fallbackId,
      name: data['name'] ?? 'User',
      avatarUrl: data['avatarUrl'] ?? '',
      nationality: data['nationality'] ?? 'Global ?��',
      email: data['email'] ?? '',
      bio: data['bio'] ?? '',
      role:
          (data['isAdmin'] == true ||
              data['isAdmin'] == 'true' ||
              data['role'] == 'admin')
          ? 'admin'
          : (data['role'] ?? 'user'),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
          : null,
      age: data['age'] as int?,
      personalInfo: data['personalInfo'] ?? '',
      nickname: data['nickname'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      instagramId: data['instagramId'] ?? '',
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      blockedBy: List<String>.from(data['blockedBy'] ?? []),
    );
  }

  // String? get currentUserId => _auth.currentUser?.uid;

  Future<app_models.User?> getUserById(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return _userFromData(doc.data()!, userId);
      }
    } catch (e) {
      debugPrint("Error fetching user by ID: $e");
    }
    return null;
  }

  Stream<app_models.User?> getUserStream(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return _userFromData(doc.data()!, userId);
      }
      return null;
    });
  }

  Future<void> updateUserProfile({
    required String name,
    required String bio,
    required String nationality,
    String? avatarUrl,
    int? age,
    String? personalInfo,
    String? instagramId,
    String? nickname,
    String? phoneNumber,
    String? email,
    List<String>? interests,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final Map<String, dynamic> data = {
      'name': name,
      'bio': bio,
      'nationality': nationality,
    };
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    if (age != null) data['age'] = age;
    if (personalInfo != null) data['personalInfo'] = personalInfo;
    if (instagramId != null) data['instagramId'] = instagramId;
    if (nickname != null) data['nickname'] = nickname;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (email != null) data['email'] = email;
    if (interests != null) data['interests'] = interests;

    // We use a WriteBatch to update the user profile AND propagate changes to their posts
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(uid);
    batch.update(userRef, data);

    // Prepare shared data for propagation
    final Map<String, dynamic> postUpdateData = {'authorName': name};
    if (avatarUrl != null) postUpdateData['authorAvatar'] = avatarUrl;

    final Map<String, dynamic> jobUpdateData = {'employerName': name};
    if (avatarUrl != null) jobUpdateData['employerAvatar'] = avatarUrl;

    final Map<String, dynamic> marketplaceUpdateData = {'sellerName': name};
    if (avatarUrl != null) marketplaceUpdateData['sellerAvatar'] = avatarUrl;

    try {
      // 1. Update Posts
      try {
        final postsSnap = await _db
            .collection('posts')
            .where('authorId', isEqualTo: uid)
            .get();
        for (var doc in postsSnap.docs) {
          batch.update(doc.reference, postUpdateData);
        }
      } catch (e) {
        debugPrint('Error updating posts profile: $e');
      }

      // 2. Update Meetups
      try {
        final meetupsSnap = await _db
            .collection('meetups')
            .where('hostId', isEqualTo: uid)
            .get();
        for (var doc in meetupsSnap.docs) {
          final Map<String, dynamic> hostUpdateData = {'hostName': name};
          if (avatarUrl != null) hostUpdateData['hostAvatar'] = avatarUrl;
          batch.update(doc.reference, hostUpdateData);
        }
      } catch (e) {
        debugPrint('Error updating meetups profile: $e');
      }

      // 3. Update Jobs
      try {
        final jobsSnap = await _db
            .collection('jobs')
            .where('authorId', isEqualTo: uid)
            .get();
        for (var doc in jobsSnap.docs) {
          batch.update(doc.reference, jobUpdateData);
        }
      } catch (e) {
        debugPrint('Error updating jobs profile: $e');
      }

      // 4. Update Marketplace
      try {
        final marketSnap = await _db
            .collection('marketplace')
            .where('sellerId', isEqualTo: uid)
            .get();
        for (var doc in marketSnap.docs) {
          batch.update(doc.reference, marketplaceUpdateData);
        }
      } catch (e) {
        debugPrint('Error updating marketplace profile: $e');
      }

      // 5. Update QnA Questions
      try {
        final qnaSnap = await _db
            .collection('questions')
            .where('authorId', isEqualTo: uid)
            .get();
        for (var doc in qnaSnap.docs) {
          batch.update(doc.reference, postUpdateData);
        }
      } catch (e) {
        debugPrint('Error updating questions profile: $e');
      }

      // 6. Update Comments (Collection Group)
      try {
        final commentsSnap = await _db
            .collectionGroup('comments')
            .where('authorId', isEqualTo: uid)
            .get();
        for (var doc in commentsSnap.docs) {
          batch.update(doc.reference, postUpdateData);
        }
      } catch (e) {
        debugPrint('Error updating comments profile (might need index): $e');
      }

      // 7. Update QNA Answers (Collection Group)
      try {
        final answersSnap = await _db
            .collectionGroup('answers')
            .where('authorId', isEqualTo: uid)
            .get();
        for (var doc in answersSnap.docs) {
          batch.update(doc.reference, postUpdateData);
        }
      } catch (e) {
        debugPrint('Error updating answers profile (might need index): $e');
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error during final batch commit: $e');
    } finally {
      // Even if propagating fails, we still want to ensure the user doc tries to update
      try {
        await userRef.update(data);
      } catch (e) {
        debugPrint('Error updating main user doc: $e');
      }
    }
  }

  Future<bool> isAdmin() async {
    final user = await getCurrentUser();
    return user?.isAdmin ?? false;
  }

  Future<void> followUser(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;
    if (uid == targetUserId) return;

    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(uid);
    final targetUserRef = _db.collection('users').doc(targetUserId);

    batch.update(currentUserRef, {
      'following': FieldValue.arrayUnion([targetUserId]),
    });
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayUnion([uid]),
    });

    await batch.commit();

    // Notify target user
    final currentUserData = await getCurrentUser();
    final followerName = currentUserData?.name ?? 'Someone';

    await sendNotification(
      userId: targetUserId,
      title: 'New Follower ?��',
      body: '$followerName started following you!',
      type: 'follow',
      relatedId: uid,
    );
  }

  Future<void> unfollowUser(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(uid);
    final targetUserRef = _db.collection('users').doc(targetUserId);

    batch.update(currentUserRef, {
      'following': FieldValue.arrayRemove([targetUserId]),
    });
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayRemove([uid]),
    });

    await batch.commit();
  }

  Stream<List<app_models.User>> getFollowers(String userId) {
    return _db
        .collection('users')
        .where('following', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _userFromData(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<List<app_models.User>> getFollowing(String userId) {
    return _db
        .collection('users')
        .where('followers', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _userFromData(doc.data(), doc.id))
              .toList();
        });
  }

  Future<String?> getUserEmailByName(String name) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        return data['email'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching user email by name: $e");
    }
    return null;
  }

  Future<String?> getUserNicknameByEmail(String email) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        return data['nickname'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching user nickname by email: $e");
    }
    return null;
  }

  Future<void> blockUser(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(uid);
    final targetUserRef = _db.collection('users').doc(targetUserId);

    batch.update(currentUserRef, {
      'blockedUsers': FieldValue.arrayUnion([targetUserId]),
      'following': FieldValue.arrayRemove([targetUserId]),
      'followers': FieldValue.arrayRemove([targetUserId]),
    });
    batch.update(targetUserRef, {
      'blockedBy': FieldValue.arrayUnion([uid]),
      'followers': FieldValue.arrayRemove([uid]),
      'following': FieldValue.arrayRemove([uid]),
    });

    try {
      await batch.commit();
    } catch (e) {
      debugPrint("Error blocking user: $e");
      rethrow;
    }
  }

  Future<void> unblockUser(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(uid);
    final targetUserRef = _db.collection('users').doc(targetUserId);

    batch.update(currentUserRef, {
      'blockedUsers': FieldValue.arrayRemove([targetUserId]),
    });
    batch.update(targetUserRef, {
      'blockedBy': FieldValue.arrayRemove([uid]),
    });

    try {
      await batch.commit();
    } catch (e) {
      debugPrint("Error unblocking user: $e");
      rethrow;
    }
  }
}
