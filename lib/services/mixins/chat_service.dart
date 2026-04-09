import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart' as app_models;
import '../../models/message_model.dart';
import '../../models/conversation_model.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';

abstract mixin class ChatDependencies {
  Future<app_models.User?> getCurrentUser();
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  });
}

mixin ChatService on ChangeNotifier implements ChatDependencies {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<List<Message>> getMeetupMessages(String meetupId) {
    // With 1:1 matching, the meetupId is the conversationId
    return getChatMessages(meetupId);
  }

  Future<void> sendMeetupMessage(
    String meetupId,
    String content, {
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToMessageSender,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await getCurrentUser();

    try {
      final convRef = _db.collection('conversations').doc(meetupId);
      final doc = await convRef.get();

      if (!doc.exists) {
        // Create if missing
        final mDoc = await _db.collection('meetups').doc(meetupId).get();
        final meetupData = mDoc.data() ?? {};
        final title = meetupData['title'] ?? 'Meetup Group';
        final participants = List<String>.from(
          meetupData['participantIds'] ?? [],
        );

        if (!participants.contains(user.uid)) {
          participants.add(user.uid);
        }

        final unreadCounts = <String, int>{};
        for (final pid in participants) {
          unreadCounts[pid] = 0;
        }

        await convRef.set({
          'participantIds': participants,
          'lastMessage': content,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'meetupId': meetupId,
          'isGroup': true,
          'groupName': title,
          'unreadCounts': unreadCounts,
        });
      }

      // Add message with batch for immediate local cache update
      final batch = _db.batch();
      final messageRef = convRef.collection('messages').doc();
      batch.set(messageRef, {
        'senderId': user.uid,
        'senderName': userData?.name ?? 'Unknown',
        'senderAvatar': userData?.avatarUrl ?? '',
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'replyToMessageId': replyToMessageId,
        'replyToMessageText': replyToMessageText,
        'replyToMessageSender': replyToMessageSender,
      });

      // Update conversation
      final docToUpdate = await convRef.get();
      final participantsList = docToUpdate.exists
          ? List<String>.from(docToUpdate.data()?['participantIds'] ?? [])
          : <String>[];
      final updates = <String, dynamic>{
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
      };
      for (final pid in participantsList) {
        if (pid != user.uid) {
          updates['unreadCounts.$pid'] = FieldValue.increment(1);
        }
      }
      batch.update(convRef, updates);
      await batch.commit();
    } catch (e) {
      debugPrint("??Error sending meetup message: $e");
      rethrow;
    }
  }

  Stream<List<Conversation>> getConversations() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map((doc) => Conversation.fromFirestore(doc))
              .toList();

          // Client-side sort to avoid composite index requirement
          conversations.sort(
            (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
          );
          return conversations;
        });
  }

  Stream<int> getTotalUnreadMessageCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final unreads = data['unreadCounts'];
            if (unreads != null && unreads is Map) {
              final count = unreads[uid];
              if (count is num) {
                total += count.toInt();
              }
            }
          }
          return total;
        });
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('conversations').doc(conversationId).update({
        'unreadCounts.$uid': 0,
      });
    } catch (e) {
      debugPrint("Error marking conversation as read: $e");
    }
  }

  Future<String> getOrCreateConversation(String otherUserId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    // Look for an existing conversation
    final querySnapshot = await _db
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .get();

    for (var doc in querySnapshot.docs) {
      final participants = List<String>.from(
        doc.data()['participantIds'] ?? [],
      );
      final isGroup = doc.data()['isGroup'] == true;
      final meetupId = doc.data()['meetupId'];

      if (!isGroup &&
          meetupId == null &&
          participants.length == 2 &&
          participants.contains(otherUserId)) {
        return doc.id; // Existing 1:1 conversation found
      }
    }

    // Create a new conversation
    final newDoc = await _db.collection('conversations').add({
      'participantIds': [uid, otherUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts': {uid: 0, otherUserId: 0},
      'isGroup': false,
    });

    return newDoc.id;
  }

  Future<void> leaveConversation(String conversationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = _db.collection('conversations').doc(conversationId);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        final participants = List<String>.from(data['participantIds'] ?? []);
        if (participants.contains(uid)) {
          participants.remove(uid);
          // If no participants left, maybe delete?
          // For now just keep it or let a cleanup job handle it.

          transaction.update(docRef, {
            'participantIds': participants,
            'unreadCounts.$uid': FieldValue.delete(),
          });
        }
      });
    } catch (e) {
      debugPrint("Error leaving conversation: $e");
      rethrow;
    }
  }

  Stream<List<Message>> getChatMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> sendDirectMessage(
    String conversationId,
    String content, {
    String? sharedPostId,
    String? sharedPostType,
    String? sharedPostTitle,
    String? sharedPostDescription,
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToMessageSender,
  }) async {
    final user = await getCurrentUser();
    if (user == null || content.trim().isEmpty) return;

    final messageId = const Uuid().v4();
    final messageData = {
      'id': messageId,
      'senderId': user.id,
      'senderName': user.name,
      'senderAvatar': user.avatarUrl,
      'content': content.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'sharedPostId': sharedPostId,
      'sharedPostType': sharedPostType,
      'sharedPostTitle': sharedPostTitle,
      'sharedPostDescription': sharedPostDescription,
      'replyToMessageId': replyToMessageId,
      'replyToMessageText': replyToMessageText,
      'replyToMessageSender': replyToMessageSender,
    };

    try {
      final conversationRef = _db.collection('conversations').doc(conversationId);
      final snapshot = await conversationRef.get();
      final participants = snapshot.exists
          ? List<String>.from(snapshot.data()?['participantIds'] ?? [])
          : <String>[];

      final batch = _db.batch();
      final messageRef = conversationRef.collection('messages').doc(messageId);

      final updates = <String, dynamic>{
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
      };

      for (final pid in participants) {
        if (pid != user.id) {
          updates['unreadCounts.$pid'] = FieldValue.increment(1);
        }
      }

      batch.set(messageRef, messageData);
      batch.update(conversationRef, updates);
      await batch.commit();

      // Send notification to other participants
      final convDoc = await _db
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (convDoc.exists) {
        final participants = List<String>.from(
          convDoc.data()?['participantIds'] ?? [],
        );
        for (final pid in participants) {
          if (pid != user.id) {
            await sendNotification(
              userId: pid,
              title: 'New Message ?',
              body: '${user.name}: $content',
              type: 'message',
              relatedId: conversationId,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error sending DM: $e");
      rethrow;
    }
  }

  Future<void> toggleMessageReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final messageRef = _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(messageRef);
        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        final reactions = data['reactions'] != null
            ? Map<String, dynamic>.from(data['reactions'])
            : <String, dynamic>{};

        if (reactions[uid] == emoji) {
          // If the user taps the same emoji again, remove it
          reactions.remove(uid);
        } else {
          // Add or replace user's reaction
          reactions[uid] = emoji;
        }

        transaction.update(messageRef, {'reactions': reactions});
      });
    } catch (e) {
      debugPrint("Error toggling message reaction: $e");
    }
  }

  Future<String> startConversation(String otherUserId) async {
    return getOrCreateConversation(otherUserId);
  }
}
