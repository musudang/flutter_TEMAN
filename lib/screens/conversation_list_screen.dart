import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart' as app_models;
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class ConversationListScreen extends StatelessWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1F36),
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: firestoreService.getConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data!;
          final currentUserId = firestoreService.currentUserId;
          if (currentUserId == null) return const SizedBox();

          return StreamBuilder<app_models.User?>(
            stream: firestoreService.getUserStream(currentUserId),
            builder: (context, userSnap) {
              final currentUser = userSnap.data;
              final blockedUsers = currentUser?.blockedUsers ?? [];

              // Filter out 1:1 conversations with blocked users
              final visibleConversations = conversations.where((conv) {
                if (conv.isGroup || conv.participantIds.length > 2) return true;
                final otherUserId = conv.participantIds.firstWhere(
                  (id) => id != currentUserId,
                  orElse: () => '',
                );
                return !blockedUsers.contains(otherUserId);
              }).toList();

              if (visibleConversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: visibleConversations.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey[100]),
                itemBuilder: (context, index) {
                  final conversation = visibleConversations[index];

                  // Determine if this is a group chat
                  final isGroup =
                      conversation.isGroup ||
                      conversation.participantIds.length > 2;

                  if (isGroup) {
                    // Group chat – show group name from Firestore data
                    return _buildGroupChatTile(
                      context,
                      conversation,
                      firestoreService,
                    );
                  }

                  // 1:1 DM – find the other user
                  final otherUserId = conversation.participantIds.firstWhere(
                    (id) => id != currentUserId,
                    orElse: () => '',
                  );

                  return FutureBuilder<app_models.User?>(
                    future: otherUserId.isNotEmpty
                        ? firestoreService.getUserById(otherUserId)
                        : null,
                    builder: (context, userSnapshot) {
                      final isDataMissing =
                          userSnapshot.connectionState ==
                              ConnectionState.done &&
                          !userSnapshot.hasData;
                      final partnerName = isDataMissing
                          ? 'Unknown User'
                          : (userSnapshot.data?.name ?? 'Chat Partner');
                      final partnerAvatar = userSnapshot.data?.avatarUrl ?? '';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.teal[50],
                          backgroundImage: partnerAvatar.isNotEmpty
                              ? NetworkImage(partnerAvatar)
                              : null,
                          child: partnerAvatar.isEmpty
                              ? Text(
                                  partnerName.isNotEmpty
                                      ? partnerName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Colors.teal[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          partnerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          conversation.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat(
                                'MM/dd HH:mm',
                              ).format(conversation.lastMessageTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                            if (conversation.unreadCounts[currentUserId] !=
                                    null &&
                                conversation.unreadCounts[currentUserId]! > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                  ),
                                  child: Text(
                                    '${conversation.unreadCounts[currentUserId]}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                conversationId: conversation.id,
                                chatTitle: partnerName,
                                otherUserId: otherUserId,
                              ),
                            ),
                          );
                        },
                        onLongPress: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Leave Chat?'),
                              content: const Text(
                                'Are you sure you want to leave this conversation?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Leave',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await firestoreService.leaveConversation(
                              conversation.id,
                            );
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGroupChatTile(
    BuildContext context,
    Conversation conversation,
    FirestoreService firestoreService,
  ) {
    // Use groupName if available, otherwise fallback to "Group Chat"
    final groupName = conversation.groupName ?? 'Group Chat';
    final memberCount = conversation.participantIds.length;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blue[50],
        child: Icon(Icons.groups, color: Colors.blue[700]),
      ),
      title: Text(
        '$groupName ($memberCount)',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat('MM/dd HH:mm').format(conversation.lastMessageTime),
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          if (conversation.unreadCounts[firestoreService.currentUserId] !=
                  null &&
              conversation.unreadCounts[firestoreService.currentUserId]! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: Text(
                  '${conversation.unreadCounts[firestoreService.currentUserId]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              chatTitle: '$groupName ($memberCount)',
            ),
          ),
        );
      },
    );
  }
}
