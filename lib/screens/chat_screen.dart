import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/message_model.dart';
import 'package:intl/intl.dart';
import 'meetup_detail_screen.dart';
import 'post_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String chatTitle;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? initialMessage;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.chatTitle,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _initialMessageSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _messageController.text = widget.initialMessage!;
      // delay slightly to allow build to finish before sending so context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Need to make sure firestoreService can be used here.
        if (!_initialMessageSent) {
          _sendMessage();
          _initialMessageSent = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    // Clear early for responsiveness
    _messageController.clear();

    String currentConvId = widget.conversationId;

    if (currentConvId.isEmpty && widget.otherUserId != null) {
      // Need to create conversation first or find existing
      currentConvId = await firestoreService.getOrCreateConversation(
        widget.otherUserId!,
      );
    }

    if (currentConvId.isNotEmpty) {
      firestoreService.sendDirectMessage(currentConvId, content);
    }

    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Reversed list, so 0 is bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUserId = firestoreService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'leave') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Leave Chat?'),
                    content: const Text(
                      'You will no longer see this chat or receive messages from it.',
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

                if (confirm == true && context.mounted) {
                  try {
                    await firestoreService.leaveConversation(
                      widget.conversationId,
                    );
                    if (context.mounted) {
                      Navigator.pop(context); // Go back to inbox
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Left chat successfully')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to leave chat: $e')),
                      );
                    }
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'leave',
                child: Text('Leave Chat', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.conversationId.isEmpty
                ? const Center(child: Text('Loading chat...'))
                : StreamBuilder<List<Message>>(
                    stream: firestoreService.getChatMessages(
                      widget.conversationId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('No messages yet. Say hi!'),
                        );
                      }

                      final messages = snapshot.data!;
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Chat style: bottom up
                        itemCount: messages.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == currentUserId;

                          return _buildMessageBubble(message, isMe);
                        },
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    if (message.senderId == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final timeString = DateFormat('h:mm a').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderAvatar.isNotEmpty
                  ? NetworkImage(message.senderAvatar)
                  : null,
              child: message.senderAvatar.isEmpty
                  ? Text(
                      message.senderName.isNotEmpty
                          ? message.senderName[0].toUpperCase()
                          : 'U',
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.teal : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFF1A1F36),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (message.sharedPostId != null &&
                      message.sharedPostTitle != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        if (message.sharedPostType == 'meetup') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetupDetailScreen(
                                meetupId: message.sharedPostId!,
                              ),
                            ),
                          );
                        } else if (message.sharedPostType == 'post') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(
                                postId: message.sharedPostId!,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isMe ? Colors.teal[600] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  message.sharedPostType == 'meetup'
                                      ? Icons.groups
                                      : Icons.article,
                                  size: 16,
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.teal[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  message.sharedPostType == 'meetup'
                                      ? 'Shared Meetup'
                                      : 'Shared Post',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isMe
                                        ? Colors.white70
                                        : Colors.teal[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message.sharedPostTitle!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (message.sharedPostDescription != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                message.sharedPostDescription!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMe ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    timeString,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
