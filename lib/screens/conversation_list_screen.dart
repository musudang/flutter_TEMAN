import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/conversation_model.dart';
import 'chat_screen.dart'; // We'll create this next
import 'package:intl/intl.dart';

class ConversationListScreen extends StatelessWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
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
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data!;
          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              // In a real app, we'd fetch the OTHER user's name/avatar here.
              // For now, checks conversation.participantIds to find the one that ISN'T current user?
              // Or simpler: Conversation model needs 'otherUserName' / 'otherUserAvatar' which is hard in NoSQL without duplication.
              // We'll rely on a placeholder or fetching user logic.

              // Let's assume for MVP we just show "Chat" or try to get ID.
              final currentUserId = firestoreService.currentUserId;
              // final otherUserId = conversation.participantIds.firstWhere(
              //   (id) => id != currentUserId,
              //   orElse: () => 'Unknown',
              // );

              return FutureBuilder(
                // Fetch other user profile? Or just show ID/Placeholder
                future: firestoreService
                    .getCurrentUser(), // This gets CURRENT user, not other.
                // We need a getUser(id) method. Let's add it or skip for now and show "User".
                builder: (context, userSnapshot) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: const Text('Chat Partner'), // Placeholder
                    subtitle: Text(
                      conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      DateFormat(
                        'MM/dd HH:mm',
                      ).format(conversation.lastMessageTime),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: conversation.id,
                            chatTitle: 'Chat', // Pass name if available
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
}
