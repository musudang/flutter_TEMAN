import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart' as app_models;
import 'dart:async';
import 'package:geolocator/geolocator.dart';

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
          final appUser = _userFromData(data, user.uid);
          _cachedIsAdmin = appUser.isAdmin;
          return appUser;
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
      universityId: data['universityId'] ?? '',
      major: data['major'] ?? '',
      classOf: data['classOf'] ?? '',
      showClassOf: data['showClassOf'] ?? false,
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      locationSharingEnabled: data['locationSharingEnabled'] ?? true,
      hideLocationFromFriends: data['hideLocationFromFriends'] ?? false,
      mapFriends: List<String>.from(data['mapFriends'] ?? []),
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

  Future<void> ensureLocationSharingField() async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && !data.containsKey('locationSharingEnabled')) {
          await _db.collection('users').doc(uid).update({
            'locationSharingEnabled': true,
          });
        }
      }
    } catch (e) {
      debugPrint('Error ensuring locationSharingEnabled field: $e');
    }
  }

  Future<void> updateUserLocation(double lat, double lng) async {
    final uid = currentUserId;
    if (uid == null) return;
    
    try {
      await _db.collection('users').doc(uid).update({
        'latitude': lat,
        'longitude': lng,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating user location: $e');
    }
  }

  Future<void> toggleLocationSharing(bool enabled) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final updateData = <String, dynamic>{
        'locationSharingEnabled': enabled,
      };
      // When disabling, clear location so others can't see it
      if (!enabled) {
        updateData['latitude'] = null;
        updateData['longitude'] = null;
      }
      await _db.collection('users').doc(uid).update(updateData);
    } catch (e) {
      debugPrint('Error toggling location sharing: $e');
    }
  }

  Future<void> toggleHideLocationFromFriends(bool hidden) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'hideLocationFromFriends': hidden,
      });
    } catch (e) {
      debugPrint('Error toggling hide location from friends: $e');
    }
  }

  /// Presence threshold: a user counts as "online / live" only if their
  /// `locationUpdatedAt` heartbeat is within this many seconds.
  /// Map heartbeat timer is 30s, so 3 min = 6 missed pings before they
  /// disappear from the map.
  static const int _presenceFreshnessSeconds = 180;

  /// Returns true when the user document's `locationUpdatedAt` is recent
  /// enough to be considered online. Missing/null timestamp ⇒ offline.
  bool _isUserPresent(Map<String, dynamic> data) {
    final ts = data['locationUpdatedAt'];
    if (ts is! Timestamp) return false;
    final updated = ts.toDate();
    final ageSeconds = DateTime.now().difference(updated).inSeconds;
    return ageSeconds <= _presenceFreshnessSeconds;
  }

  Future<List<app_models.User>> getNearbyFriends(double lat, double lng, {double radiusInMeters = 3000}) async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) return [];

    // If current user disabled sharing, return empty
    if (!currentUser.locationSharingEnabled) return [];

    // MUTUAL INVISIBILITY: if current user has hidden from friends,
    // they should not see any friends (and friends won't see them either
    // because the reverse check also applies when those friends fetch).
    if (currentUser.hideLocationFromFriends) return [];

    // Only mutual followers may show on the map at all. Then we apply a
    // SECOND opt-in filter: `mapFriends`. A sees B on the map only when
    // BOTH A.mapFriends.contains(B) AND B.mapFriends.contains(A).
    // (Instagram close-friends model.)
    final mutualFriends = currentUser.following
        .where((id) => currentUser.followers.contains(id))
        .toList();
    if (mutualFriends.isEmpty) return [];

    // First gate: I must have added them to my mapFriends.
    final myMapFriends = currentUser.mapFriends.toSet();
    final candidates =
        mutualFriends.where(myMapFriends.contains).toList();
    if (candidates.isEmpty) return [];

    List<app_models.User> nearbyFriends = [];

    // Process in batches of 10 for whereIn query
    for (int i = 0; i < candidates.length; i += 10) {
      final end = (i + 10 < candidates.length) ? i + 10 : candidates.length;
      final batch = candidates.sublist(i, end);

      final snapshot = await _db.collection('users').where('id', whereIn: batch).get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Skip friends who disabled location sharing
        if (data['locationSharingEnabled'] == false) continue;
        // MUTUAL INVISIBILITY: Skip friends who chose to hide their location from friends
        // (if they hide from us, we also hide from them)
        if (data['hideLocationFromFriends'] == true) continue;
        // BILATERAL MAP-FRIEND GATE: the other side must ALSO have added
        // me to their mapFriends. If not, no pin.
        final theirMapFriends =
            List<String>.from(data['mapFriends'] ?? []);
        if (!theirMapFriends.contains(currentUser.id)) continue;
        // PRESENCE: Skip friends who haven't pinged the server recently
        // (offline / app closed / no signal). They shouldn't appear stale.
        if (!_isUserPresent(data)) continue;

        final friendLat = data['latitude']?.toDouble();
        final friendLng = data['longitude']?.toDouble();
        if (friendLat != null && friendLng != null) {
          // Return all mutual friends who have shared their location
          nearbyFriends.add(_userFromData(data, doc.id));
        }
      }
    }

    return nearbyFriends;
  }

  /// Returns every mutual follower (both `following` and `followers`),
  /// independent of distance, location-sharing, or `mapFriends` opt-in.
  /// Used by the Map Friends tab so users can choose who to add to their
  /// map opt-in list.
  Future<List<app_models.User>> getMutualFollowerUsers() async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) return [];
    final mutualIds = currentUser.following
        .where((id) => currentUser.followers.contains(id))
        .toList();
    if (mutualIds.isEmpty) return [];

    final result = <app_models.User>[];
    for (int i = 0; i < mutualIds.length; i += 10) {
      final end =
          (i + 10 < mutualIds.length) ? i + 10 : mutualIds.length;
      final batch = mutualIds.sublist(i, end);
      final snap = await _db
          .collection('users')
          .where('id', whereIn: batch)
          .get();
      for (var doc in snap.docs) {
        result.add(_userFromData(doc.data(), doc.id));
      }
    }
    return result;
  }

  /// Toggle a single user in / out of my `mapFriends` array. This is
  /// one-sided — the other user must also call this for full visibility
  /// (see `getNearbyFriends` bilateral gate).
  Future<void> toggleMapFriend(String otherUserId) async {
    final uid = currentUserId;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final list = List<String>.from(data['mapFriends'] ?? []);
        if (list.contains(otherUserId)) {
          list.remove(otherUserId);
        } else {
          list.add(otherUserId);
        }
        tx.update(ref, {'mapFriends': list});
      });
    } catch (e) {
      debugPrint('Error toggling map friend: $e');
      rethrow;
    }
  }

  /// Discover ALL TEMAN users within [radiusInMeters] (default 1km).
  /// Excludes the current user and blocked users.
  Future<Map<String, dynamic>> getNearbyUsersWithDebug(double lat, double lng, {double radiusInMeters = 1000}) async {
    final debug = <String, dynamic>{
      'myLat': lat,
      'myLng': lng,
      'radius': radiusInMeters,
      'queryCount': 0,
      'afterExclude': 0,
      'afterMutual': 0,
      'afterPresence': 0,
      'afterLatLng': 0,
      'afterDistance': 0,
      'earlyExit': '',
    };

    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      debug['earlyExit'] = 'currentUser null';
      return {'users': <app_models.User>[], 'debug': debug};
    }
    debug['myLocationSharing'] = currentUser.locationSharingEnabled;
    debug['myPhoneVerified'] = currentUser.isPhoneVerified;
    if (!currentUser.locationSharingEnabled) {
      debug['earlyExit'] = 'locationSharingEnabled=false';
      return {'users': <app_models.User>[], 'debug': debug};
    }

    final excludeIds = <String>{
      currentUser.id,
      ...currentUser.blockedUsers,
      ...currentUser.blockedBy,
    };

    List<app_models.User> nearbyUsers = [];

    final snapshot = await _db
        .collection('users')
        .where('locationSharingEnabled', isEqualTo: true)
        .get();

    debug['queryCount'] = snapshot.docs.length;
    int afterExclude = 0, afterMutual = 0, afterPresence = 0, afterLatLng = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['id'] ?? doc.id;

      if (excludeIds.contains(userId)) continue;
      afterExclude++;

      final isMutualFriend = currentUser.following.contains(userId) &&
          currentUser.followers.contains(userId);
      if (isMutualFriend) continue;
      afterMutual++;

      if (!_isUserPresent(data)) continue;
      afterPresence++;

      final userLat = data['latitude']?.toDouble();
      final userLng = data['longitude']?.toDouble();
      if (userLat == null || userLng == null) continue;
      afterLatLng++;

      final distance = Geolocator.distanceBetween(lat, lng, userLat, userLng);
      if (distance <= radiusInMeters) {
        nearbyUsers.add(_userFromData(data, doc.id));
      }
    }

    debug['afterExclude'] = afterExclude;
    debug['afterMutual'] = afterMutual;
    debug['afterPresence'] = afterPresence;
    debug['afterLatLng'] = afterLatLng;
    debug['afterDistance'] = nearbyUsers.length;

    return {'users': nearbyUsers, 'debug': debug};
  }

  Future<List<app_models.User>> getNearbyUsers(double lat, double lng, {double radiusInMeters = 1000}) async {
    final result = await getNearbyUsersWithDebug(lat, lng, radiusInMeters: radiusInMeters);
    return result['users'] as List<app_models.User>;
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
    String? universityId,
    String? major,
    String? classOf,
    bool? showClassOf,
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
    if (universityId != null) data['universityId'] = universityId;
    if (major != null) data['major'] = major;
    if (classOf != null) data['classOf'] = classOf;
    if (showClassOf != null) data['showClassOf'] = showClassOf;

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
    final result = user?.isAdmin ?? false;
    _cachedIsAdmin = result;
    return result;
  }

  bool _cachedIsAdmin = false;

  bool get isAdminCached => _cachedIsAdmin;

  void refreshAdminStatus() {
    isAdmin();
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
      title: 'New Follower',
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
