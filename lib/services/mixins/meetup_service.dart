import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/meetup_model.dart';
import '../../models/user_model.dart' as app_models;
import '../../models/comment_model.dart';

mixin MeetupService on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<List<Meetup>> getMeetups({
    int limit = 20,
    List<String> hiddenUsers = const [],
  }) {
    return _db
        .collection('meetups')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          var meetups = snapshot.docs
              .map((doc) => _fromDocument(doc))
              // Hide meetups whose start time has already elapsed —
              // they live on as records in the host's / participants'
              // profile only. Active and future meetups stay visible.
              .where((m) => m.dateTime.isAfter(now))
              .toList();
          if (hiddenUsers.isNotEmpty) {
            meetups = meetups
                .where((m) => !hiddenUsers.contains(m.host.id))
                .toList();
          }
          return meetups;
        });
  }

  Stream<Meetup> getMeetup(String id) {
    return _db.collection('meetups').doc(id).snapshots().map((doc) {
      if (!doc.exists) throw Exception("Meetup not found");
      return _fromDocument(doc);
    });
  }

  Future<void> addMeetup(Meetup meetup) async {
    if (_auth.currentUser == null) {
      debugPrint('Error: User must be logged in to write to Firestore');
      throw Exception('User must be logged in to create a meetup');
    }

    final uid = _auth.currentUser!.uid;
    if (meetup.id.isEmpty) {
      // Only ACTIVE (future-dated) meetups count toward the 1-active
      // limit — past meetups are records and should not block creating
      // a new one.
      final existingHostedQuery = await _db
          .collection('meetups')
          .where('hostId', isEqualTo: uid)
          .get();

      final now = DateTime.now();
      final activeHosted = existingHostedQuery.docs.where((doc) {
        final dt = (doc.data()['dateTime'] as Timestamp?)?.toDate();
        return dt != null && dt.isAfter(now);
      }).toList();

      if (activeHosted.isNotEmpty) {
        throw Exception('You can only have one active meetup created at a time.');
      }
    }

    debugPrint("Attempting to save meetup... Title: ${meetup.title}");
    try {
      debugPrint("Meetup saved successfully!");

      DocumentReference docRef;
      if (meetup.id.isEmpty) {
        docRef = await _db.collection('meetups').add(_toDocument(meetup));
      } else {
        docRef = _db.collection('meetups').doc(meetup.id);
        await docRef.set(_toDocument(meetup));
      }

      // Create Group Chat — use the meetup doc ID as the conversation ID
      // so that sendMeetupMessage / _addUserToMeetupChat can find it via doc(meetupId).
      await _db.collection('conversations').doc(docRef.id).set({
        'participantIds': [meetup.host.id],
        'lastMessage': 'Meetup created! 🎉',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': {meetup.host.id: 0},
        'isGroup': true,
        'groupName': meetup.title,
        'meetupId': docRef.id,
      });
    } catch (e) {
      debugPrint("Error saving meetup: $e");
      rethrow;
    }
  }

  Future<bool> joinMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) {
      debugPrint("Error: User not logged in trying to join meetup.");
      return false;
    }

    // Check if user is already participating in another ACTIVE meetup.
    // Past meetups are records only and should not block joining a new one.
    final existingJoinedQuery = await _db
        .collection('meetups')
        .where('participantIds', arrayContains: uid)
        .get();

    final nowJoin = DateTime.now();
    // Filter out meetups where they are the host, the same meetup, or
    // any meetup whose start time has elapsed.
    final joinedAsParticipant = existingJoinedQuery.docs.where((doc) {
      final data = doc.data();
      if (data['hostId'] == uid) return false;
      if (doc.id == meetupId) return false;
      final dt = (data['dateTime'] as Timestamp?)?.toDate();
      if (dt == null) return false;
      return dt.isAfter(nowJoin);
    }).toList();

    if (joinedAsParticipant.isNotEmpty) {
      throw Exception('You can only participate in one meetup at a time.');
    }

    final docRef = _db.collection('meetups').doc(meetupId);

    // Use main user doc to avoid Firebase subcollection rule crashes
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('cooldowns')) {
          final cooldowns = data['cooldowns'] as Map<String, dynamic>;
          if (cooldowns.containsKey(meetupId)) {
            final leftAt = (cooldowns[meetupId] as Timestamp?)?.toDate();
            if (leftAt != null) {
              final difference = DateTime.now().difference(leftAt);
              if (difference.inHours < 1) {
                // exact message expected by UI
                throw Exception('Try join this group 1 hour later.');
              }
            }
          }
        }
      }
    } catch (e) {
      if (e.toString().contains('1 hour later')) {
        rethrow;
      }
      debugPrint("Warning: Could not fetch user cooldowns: $e");
    }

    bool joinedSuccess = false;

    try {
      joinedSuccess = await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          debugPrint("Error: Meetup $meetupId does not exist!");
          throw Exception("Meetup does not exist!");
        }

        final meetup = _fromDocument(snapshot);

        if (meetup.participantIds.contains(uid)) {
          debugPrint("User already joined.");
          return false;
        }

        if (meetup.participantIds.length >= meetup.maxParticipants) {
          debugPrint(
            "Meetup is full! (${meetup.participantIds.length}/${meetup.maxParticipants})",
          );
          return false;
        }

        final updatedParticipants = List<String>.from(meetup.participantIds)
          ..add(uid);

        transaction.update(docRef, {'participantIds': updatedParticipants});
        debugPrint("Successfully joined meetup!");

        return true;
      });
    } catch (e) {
      debugPrint("Error joining meetup: $e");
      rethrow;
    }

    if (joinedSuccess) {
      // Add to group chat immediately
      final doc = await _db.collection('meetups').doc(meetupId).get();
      if (doc.exists) {
        final data = doc.data();
        final title = data?['title'] ?? 'Meetup Chat';
        final hostId = data?['hostId'];
        await _addUserToMeetupChat(meetupId, title, uid);

        // Notify host
        if (hostId != null && hostId != uid) {
          final userDoc = await _db.collection('users').doc(uid).get();
          final userName = userDoc.data()?['name'] ?? 'Someone';

          await _db
              .collection('users')
              .doc(hostId)
              .collection('notifications')
              .add({
                'userId': hostId,
                'title': 'New Member ?��',
                'body': '$userName joined your meetup!',
                'type': 'meetup_join',
                'relatedId': meetupId,
                'timestamp': FieldValue.serverTimestamp(),
                'isRead': false,
              });
        }

        // Clear cooldown since they successfully joined
        try {
          await _db.collection('users').doc(uid).update({
            'cooldowns.$meetupId': FieldValue.delete(),
          });
        } catch (e) {
          debugPrint("Warning: Could not clear cooldown: $e");
        }
      }
    }
    return joinedSuccess;
  }

  Future<void> _addUserToMeetupChat(
    String meetupId,
    String meetupTitle,
    String userId,
  ) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final userName = userDoc.data()?['name'] ?? 'Someone';

      final convRef = _db.collection('conversations').doc(meetupId);

      // Retry update with exponential backoff for eventual consistency.
      // The meetup.participantIds was just updated; firestore.rules evaluates
      // get(.../meetups/...) on the server which may briefly see a stale
      // value, causing permission-denied. Retrying gives propagation time.
      bool updated = false;
      Object? lastError;
      for (int attempt = 0; attempt < 4; attempt++) {
        try {
          await convRef.update({
            'participantIds': FieldValue.arrayUnion([userId]),
            'unreadCounts.$userId': 0,
            'lastMessage': '$userName has joined the group.',
            'lastMessageTime': FieldValue.serverTimestamp(),
          });
          updated = true;
          break;
        } catch (e) {
          lastError = e;
          // not-found: doc missing → create branch below
          if (e is FirebaseException && e.code == 'not-found') break;
          // Other errors (incl. permission-denied): wait and retry
          await Future.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
        }
      }

      if (!updated) {
        // Document missing (legacy meetups created before conversation auto-create).
        try {
          final meetupDoc = await _db.collection('meetups').doc(meetupId).get();
          final hostId = meetupDoc.data()?['hostId'];

          final newParticipants = <String>{userId};
          if (hostId != null) newParticipants.add(hostId);

          await convRef.set({
            'participantIds': newParticipants.toList(),
            'lastMessage': '$userName has joined the group.',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'meetupId': meetupId,
            'isGroup': true,
            'groupName': meetupTitle,
            'unreadCounts': {
              for (final id in newParticipants) id: 0,
            },
          });
        } catch (e) {
          debugPrint(
            "Failed to create meetup conversation. lastUpdateError=$lastError, createError=$e",
          );
          return;
        }
      }

      // Add System Join Message
      await convRef.collection('messages').add({
        'senderId': 'system', // Distinguish as a system message
        'senderName': 'System',
        'senderAvatar': '',
        'content': '$userName has joined the group.',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error adding user to meetup chat: $e");
    }
  }

  Future<void> kickMeetupParticipant(
    String meetupId,
    String participantId,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Meetup not found');

        final data = snapshot.data() as Map<String, dynamic>;
        if (data['hostId'] != uid) throw Exception('Only host can kick');

        final participants = List<String>.from(data['participantIds'] ?? []);
        if (participants.contains(participantId)) {
          participants.remove(participantId);
          transaction.update(docRef, {'participantIds': participants});
        }
      });

      // Update chat
      final convRef = _db.collection('conversations').doc(meetupId);
      try {
        await convRef.update({
          'participantIds': FieldValue.arrayRemove([participantId]),
          'unreadCounts.$participantId': FieldValue.delete(),
        });

        // Add System Leave Message
        await convRef.collection('messages').add({
          'senderId': 'system',
          'senderName': 'System',
          'senderAvatar': '',
          'content': 'A participant was removed from the group.',
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Could not strictly update conversation for kick: $e");
      }
    } catch (e) {
      debugPrint("Error kicking participant: $e");
      rethrow;
    }
  }

  Future<void> acceptMeetupParticipant(
    String meetupId,
    String participantId,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Meetup not found');

        final data = snapshot.data() as Map<String, dynamic>;
        if (data['hostId'] != uid) throw Exception('Only host can accept');

        final pending = List<String>.from(data['pendingParticipantIds'] ?? []);
        final participants = List<String>.from(data['participantIds'] ?? []);

        if (pending.contains(participantId)) {
          pending.remove(participantId);
          if (!participants.contains(participantId)) {
            participants.add(participantId);
          }
          transaction.update(docRef, {
            'pendingParticipantIds': pending,
            'participantIds': participants,
          });
        }
      });
      // Update chat
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final title = data['title'] ?? 'Meetup';
        await _addUserToMeetupChat(meetupId, title, participantId);
      }
    } catch (e) {
      debugPrint("Error accepting participant: $e");
      rethrow;
    }
  }

  Future<void> declineMeetupParticipant(
    String meetupId,
    String participantId,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return; // Silent return if not found

        final data = snapshot.data() as Map<String, dynamic>;
        // A user can decline themselves (cancel request), or the host can decline them.
        if (data['hostId'] != uid && participantId != uid) {
          throw Exception('Unauthorized to decline');
        }

        final pending = List<String>.from(data['pendingParticipantIds'] ?? []);
        if (pending.contains(participantId)) {
          pending.remove(participantId);
          transaction.update(docRef, {'pendingParticipantIds': pending});
        }
      });
    } catch (e) {
      debugPrint("Error declining participant: $e");
      rethrow;
    }
  }

  Future<void> leaveMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);

    try {
      bool isHost = false;
      String? newHostId;
      bool shouldDeleteMeetup = false;

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Meetup does not exist!");

        final meetup = _fromDocument(snapshot);
        if (!meetup.participantIds.contains(uid)) {
          return;
        }

        isHost = meetup.host.id == uid;
        final updatedParticipants = List<String>.from(meetup.participantIds)
          ..remove(uid);

        if (isHost) {
          if (updatedParticipants.isEmpty) {
            // No participants left — mark for deletion
            shouldDeleteMeetup = true;
            transaction.delete(docRef);
          } else {
            // Transfer host to the next participant
            newHostId = updatedParticipants.first;
            transaction.update(docRef, {
              'participantIds': updatedParticipants,
              'hostId': newHostId,
            });
          }
        } else {
          transaction.update(docRef, {'participantIds': updatedParticipants});
        }
      });

      // If host was transferred, update host name/avatar from user doc
      if (isHost && newHostId != null && !shouldDeleteMeetup) {
        try {
          final newHostDoc =
              await _db.collection('users').doc(newHostId).get();
          if (newHostDoc.exists) {
            final newHostData = newHostDoc.data();
            await docRef.update({
              'hostName': newHostData?['name'] ?? 'Unknown',
              'hostAvatar': newHostData?['avatarUrl'] ?? '',
            });
          }
        } catch (e) {
          debugPrint("Warning: Could not update new host info: $e");
        }
      }

      // Update conversation
      final convRef = _db.collection('conversations').doc(meetupId);
      try {
        if (shouldDeleteMeetup) {
          // Delete the conversation entirely
          await convRef.delete();
        } else {
          await convRef.update({
            'participantIds': FieldValue.arrayRemove([uid]),
            'unreadCounts.$uid': FieldValue.delete(),
          });

          // Add System Leave Message
          final userDoc = await _db.collection('users').doc(uid).get();
          final userName = userDoc.data()?['name'] ?? 'Someone';

          await convRef.collection('messages').add({
            'senderId': 'system',
            'senderName': 'System',
            'senderAvatar': '',
            'content': '$userName has left the group.',
            'timestamp': FieldValue.serverTimestamp(),
          });

          // If host was transferred, add a system message about new host
          if (isHost && newHostId != null) {
            final newHostDoc =
                await _db.collection('users').doc(newHostId).get();
            final newHostName = newHostDoc.data()?['name'] ?? 'Someone';

            await convRef.collection('messages').add({
              'senderId': 'system',
              'senderName': 'System',
              'senderAvatar': '',
              'content': '$newHostName is now the host.',
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        debugPrint("Could not strictly update conversation for leave: $e");
      }

      // Record Cooldown to the main user document
      if (!shouldDeleteMeetup) {
        try {
          await _db.collection('users').doc(uid).update({
            'cooldowns.$meetupId': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint("Warning: Could not save cooldown timestamp: $e");
        }
      }
    } catch (e) {
      debugPrint("Error leaving meetup: $e");
    }
  }

  Future<void> deleteMeetup(String meetupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final docSnapshot = await _db.collection('meetups').doc(meetupId).get();
      if (!docSnapshot.exists) return;

      final data = docSnapshot.data();
      if (data != null && data['hostId'] == uid) {
        // Delete the meetup
        await _db.collection('meetups').doc(meetupId).delete();

        // Also try to find and delete the associated conversation.
        // Best-effort: if rules deny (legacy conversation without
        // meetupId, race with host change, …) we swallow the error so
        // the meetup itself still deletes cleanly.
        try {
          final query = await _db
              .collection('conversations')
              .where('meetupId', isEqualTo: meetupId)
              .where('participantIds', arrayContains: uid)
              .get();

          for (var doc in query.docs) {
            try {
              await _db.collection('conversations').doc(doc.id).delete();
            } catch (e) {
              debugPrint(
                  "Warning: could not delete conversation ${doc.id}: $e");
            }
          }
        } catch (e) {
          debugPrint("Warning: could not enumerate conversations: $e");
        }
      } else {
        throw Exception('Only the host can delete this meetup');
      }
    } catch (e) {
      debugPrint("Error deleting meetup: $e");
      rethrow;
    }
  }

  Future<void> updateMeetup(String meetupId, Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docSnapshot = await _db.collection('meetups').doc(meetupId).get();
    if (!docSnapshot.exists) return;

    final meetupData = docSnapshot.data();
    if (meetupData != null && meetupData['hostId'] == uid) {
      await _db.collection('meetups').doc(meetupId).update(data);
    } else {
      throw Exception('Only the host can update this meetup');
    }
  }

  Meetup _fromDocument(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      throw Exception("Meetup document does not exist");
    }

    final data = doc.data() as Map<String, dynamic>;
    return Meetup(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: MeetupCategory.values.firstWhere(
        (e) => e.toString() == 'MeetupCategory.${data['category']}',
        orElse: () => MeetupCategory.other,
      ),
      maxParticipants: data['maxParticipants'] ?? 0,
      host: app_models.User(
        id: data['hostId'] ?? '',
        name: data['hostName'] ?? 'Unknown',
        avatarUrl: data['hostAvatar'] ?? '',
      ),
      participantIds: List<String>.from(data['participantIds'] ?? []),
      imageUrls: List<String>.from(data['imageUrls'] ?? (data['imageUrl'] != null ? [data['imageUrl']] : [])),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      scrappedBy: List<String>.from(data['scrappedBy'] ?? []),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
          : DateTime(
              2025,
              1,
              1,
            ), // Fallback to past date to avoid pinning old meetups
    );
  }

  Map<String, dynamic> _toDocument(Meetup meetup) {
    return {
      'title': meetup.title,
      'description': meetup.description,
      'location': meetup.location,
      'dateTime': Timestamp.fromDate(meetup.dateTime),
      'createdAt': Timestamp.fromDate(meetup.createdAt), // [NEW]
      'category': meetup.category.name,
      'maxParticipants': meetup.maxParticipants,
      'hostId': meetup.host.id,
      'hostName': meetup.host.name,
      'hostAvatar': meetup.host.avatarUrl,
      'participantIds': meetup.participantIds,
      'imageUrls': meetup.imageUrls,
      'likes': meetup.likes,
      'comments': meetup.comments,
      'likedBy': meetup.likedBy,
      'scrappedBy': meetup.scrappedBy,
    };
  }

  Future<void> toggleLikeMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);

    try {
      await _db.runTransaction((transaction) async {
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
      debugPrint("Error toggling meetup like: $e");
    }
  }

  Stream<List<Comment>> getMeetupComments(String meetupId) {
    return _db
        .collection('meetups')
        .doc(meetupId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Comment(
              id: doc.id,
              postId: meetupId, // Using postId field for meetupId as well
              content: data['content'] ?? '',
              authorId: data['authorId'] ?? '',
              authorName: data['authorName'] ?? 'Unknown',
              authorAvatar: data['authorAvatar'] ?? '',
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList();
        });
  }

  Future<void> addMeetupComment(
    String meetupId,
    String content, {
    String? replyToCommentId,
    String? replyToCommentText,
    String? replyToCommentAuthor,
    bool isAnonymous = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to comment');

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    final commentsRef =
        _db.collection('meetups').doc(meetupId).collection('comments');

    try {
      // Compute thread-scoped anonymous index (reuse same number for the
      // same author across the thread, mirrors main-board behavior).
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
        anonymousIndex = authorIndexMap[user.uid] ?? (maxIndex + 1);
      }

      await _db.runTransaction((transaction) async {
        final meetupRef = _db.collection('meetups').doc(meetupId);
        final commentRef = commentsRef.doc();

        final docData = <String, dynamic>{
          'content': content,
          'authorId': user.uid,
          'authorName': userData?['name'] ?? 'Unknown',
          'authorAvatar': userData?['avatarUrl'] ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'authorUniversityId': userData?['universityId'],
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

        transaction.update(meetupRef, {'comments': FieldValue.increment(1)});
      });

      // Notify host directly using _db
      final meetupDoc = await _db.collection('meetups').doc(meetupId).get();
      String hostId = '';
      if (meetupDoc.exists) {
        hostId = meetupDoc.data()?['hostId'] ?? '';
        if (hostId.isNotEmpty && hostId != user.uid) {
          await _db
              .collection('users')
              .doc(hostId)
              .collection('notifications')
              .add({
                'userId': hostId,
                'title': 'New Meetup Comment ?��',
                'body':
                    '${userData?['name'] ?? "Someone"} commented on your meetup.',
                'type': 'comment',
                'relatedId': meetupId,
                'timestamp': FieldValue.serverTimestamp(),
                'isRead': false,
              });
        }
      }

      // Reply notification: notify parent comment's author too.
      if (replyToCommentId != null) {
        try {
          final parentSnap = await _db
              .collection('meetups')
              .doc(meetupId)
              .collection('comments')
              .doc(replyToCommentId)
              .get();
          final parentAuthorId = parentSnap.data()?['authorId'] ?? '';
          if (parentAuthorId.isNotEmpty &&
              parentAuthorId != user.uid &&
              parentAuthorId != hostId) {
            await _db
                .collection('users')
                .doc(parentAuthorId)
                .collection('notifications')
                .add({
              'userId': parentAuthorId,
              'title': 'New Reply 💬',
              'body':
                  '${userData?['name'] ?? "Someone"} replied to your comment.',
              'type': 'reply',
              'relatedId': meetupId,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        } catch (e) {
          debugPrint('Meetup reply notification skipped: $e');
        }
      }
    } catch (e) {
      debugPrint("Error adding meetup comment: $e");
      rethrow;
    }
  }

  /// Delete own meetup comment.
  /// Soft-delete (mark `isDeleted: true`, clear content) when the comment
  /// already has replies, hard-delete otherwise.
  Future<void> deleteMeetupComment(String meetupId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to delete a comment');

    final commentsRef =
        _db.collection('meetups').doc(meetupId).collection('comments');

    try {
      final replies = await commentsRef
          .where('replyToCommentId', isEqualTo: commentId)
          .limit(1)
          .get();
      final hasReplies = replies.docs.isNotEmpty;

      await _db.runTransaction((transaction) async {
        final commentRef = commentsRef.doc(commentId);
        final snap = await transaction.get(commentRef);
        if (!snap.exists) return;
        final data = snap.data();
        if (data?['authorId'] != user.uid) {
          throw Exception('Not authorized to delete this comment');
        }

        final meetupRef = _db.collection('meetups').doc(meetupId);
        if (hasReplies) {
          transaction.update(commentRef, {
            'isDeleted': true,
            'content': '',
            'authorAvatar': '',
          });
        } else {
          transaction.delete(commentRef);
          transaction.update(meetupRef, {'comments': FieldValue.increment(-1)});
        }
      });
    } catch (e) {
      debugPrint("Error deleting meetup comment: $e");
      rethrow;
    }
  }

  Future<void> toggleScrapMeetup(String meetupId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('meetups').doc(meetupId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final scrappedBy = List<String>.from(data['scrappedBy'] ?? []);

        if (scrappedBy.contains(uid)) {
          scrappedBy.remove(uid);
        } else {
          scrappedBy.add(uid);
        }

        transaction.update(docRef, {'scrappedBy': scrappedBy});
      });
    } catch (e) {
      debugPrint("Error toggling meetup scrap: $e");
    }
  }

  Stream<List<Meetup>> getScrappedMeetups(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _db
        .collection('meetups')
        .where('scrappedBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final meetups = snapshot.docs
              .map((doc) => _fromDocument(doc))
              .toList();
          // Client-side sort
          meetups.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return meetups;
        })
        .handleError((e) {
          debugPrint("Error fetching scrapped meetups: $e");
          return <Meetup>[];
        });
  }

  Stream<List<Meetup>> getJoinedMeetups(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _db
        .collection('meetups')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final meetups = snapshot.docs
              .map((doc) => _fromDocument(doc))
              .toList();
          meetups.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return meetups;
        })
        .handleError((e) {
          debugPrint("Error fetching joined meetups: $e");
          return <Meetup>[];
        });
  }
}
