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
        automaticallyImplyLeading: false,
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
          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final currentUserId = firestoreService.currentUserId;

              // Determine if this is a group chat
              final isGroup = conversation.participantIds.length > 2;

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
                  final partnerName = userSnapshot.data?.name ?? 'Chat Partner';
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
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    trailing: Text(
                      DateFormat(
                        'MM/dd HH:mm',
                      ).format(conversation.lastMessageTime),
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: conversation.id,
                            chatTitle: partnerName,
                          ),
                        ),
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
    // Group chats stored with a groupName field; we read it from unreadCounts
    // as a workaround since Conversation model doesn't have groupName.
    // We'll show a group icon and generic name based on participant count.
    final memberCount = conversation.participantIds.length;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blue[50],
        child: Icon(Icons.groups, color: Colors.blue[700]),
      ),
      title: Text(
        'Group Chat ($memberCount)',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      ),
      trailing: Text(
        DateFormat('MM/dd HH:mm').format(conversation.lastMessageTime),
        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              chatTitle: 'Group Chat ($memberCount)',
            ),
          ),
        );
      },
    );
  }
}
