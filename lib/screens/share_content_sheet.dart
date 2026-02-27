import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart' as app_models;
import '../services/firestore_service.dart';
import 'chat_screen.dart';
import 'create_post_screen.dart';

class ShareContentSheet extends StatefulWidget {
  final String itemId;
  final String itemType; // 'meetup' or 'post'
  final String itemTitle;
  final String itemDescription;

  const ShareContentSheet({
    super.key,
    required this.itemId,
    required this.itemType,
    required this.itemTitle,
    required this.itemDescription,
  });

  @override
  State<ShareContentSheet> createState() => _ShareContentSheetState();
}

class _ShareContentSheetState extends State<ShareContentSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _shareToFreeBoard() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          initialPostText:
              'Check out this ${widget.itemType}!\nTitle: ${widget.itemTitle}\nDescription: ${widget.itemDescription}',
        ),
      ),
    );
  }

  Future<void> _sendDMToConversation(
    Conversation conversation,
    String partnerName,
    String partnerAvatar,
  ) async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final messageText = widget.itemType == 'meetup'
        ? 'Check out this meetup: ${widget.itemTitle}'
        : 'Check out this post: ${widget.itemTitle}';

    await firestoreService.sendDirectMessage(
      conversation.id,
      messageText,
      sharedPostId: widget.itemId,
      sharedPostType: widget.itemType,
      sharedPostTitle: widget.itemTitle,
      sharedPostDescription: widget.itemDescription,
    );

    if (!mounted) return;

    Navigator.pop(context); // Close the share sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatScreen(conversationId: conversation.id, chatTitle: partnerName),
      ),
    );
  }

  Widget _buildTargetAvatar({
    required String name,
    String? avatarUrl,
    required bool isGroup,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: isGroup
                  ? Colors.blue.shade50
                  : Colors.grey.shade200,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
              child: isGroup
                  ? const Icon(Icons.groups, color: Colors.blue)
                  : ((avatarUrl == null || avatarUrl.isEmpty)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.black54),
                          )
                        : null),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black87, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final currentUserId = firestoreService.currentUserId;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Share',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            // User/Chat Grid
            Expanded(
              child: currentUserId == null
                  ? const Center(child: Text('Login required.'))
                  : StreamBuilder<List<Conversation>>(
                      stream: firestoreService.getConversations(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final conversations = snapshot.data ?? [];

                        if (conversations.isEmpty) {
                          return const Center(
                            child: Text('No recent chats found.'),
                          );
                        }

                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 16.0,
                          ),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 24,
                            alignment: WrapAlignment.start,
                            children: conversations.map((conversation) {
                              final isGroup =
                                  conversation.isGroup ||
                                  conversation.participantIds.length > 2;

                              if (isGroup) {
                                final groupName =
                                    conversation.groupName ?? 'Group Chat';
                                if (_searchQuery.isNotEmpty &&
                                    !groupName.toLowerCase().contains(
                                      _searchQuery,
                                    )) {
                                  return const SizedBox.shrink();
                                }
                                return _buildTargetAvatar(
                                  name: groupName,
                                  isGroup: true,
                                  onTap: () => _sendDMToConversation(
                                    conversation,
                                    groupName,
                                    '',
                                  ),
                                );
                              }

                              // 1:1 Chat
                              final otherUserId = conversation.participantIds
                                  .firstWhere(
                                    (id) => id != currentUserId,
                                    orElse: () => '',
                                  );

                              return FutureBuilder<app_models.User?>(
                                future: otherUserId.isNotEmpty
                                    ? firestoreService.getUserById(otherUserId)
                                    : null,
                                builder: (context, userSnap) {
                                  if (!userSnap.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  final user = userSnap.data!;

                                  if (_searchQuery.isNotEmpty &&
                                      !user.name.toLowerCase().contains(
                                        _searchQuery,
                                      )) {
                                    return const SizedBox.shrink();
                                  }

                                  return _buildTargetAvatar(
                                    name: user.name,
                                    avatarUrl: user.avatarUrl,
                                    isGroup: false,
                                    onTap: () => _sendDMToConversation(
                                      conversation,
                                      user.name,
                                      user.avatarUrl,
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            // Bottom Actions (Horizontal scroll)
            Container(
              height: 110,
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                children: [
                  _buildShareOption(Icons.link, 'Copy Link', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied.')),
                    );
                    Navigator.pop(context);
                  }),
                  _buildShareOption(
                    Icons.article_outlined,
                    'Free Board',
                    _shareToFreeBoard,
                  ),
                  _buildShareOption(Icons.facebook, 'Facebook', () {}),
                  _buildShareOption(
                    Icons.chat_bubble_outline,
                    'Messenger',
                    () {},
                  ),
                  _buildShareOption(Icons.message_outlined, 'WhatsApp', () {}),
                  _buildShareOption(Icons.email_outlined, 'Email', () {}),
                  _buildShareOption(Icons.alternate_email, 'Threads', () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
