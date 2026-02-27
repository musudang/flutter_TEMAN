import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../models/user_model.dart' as app_models;
import '../services/firestore_service.dart';
import 'user_profile_screen.dart';
import 'share_content_sheet.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Post', style: TextStyle(color: Color(0xFF1A1F36))),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF1A1F36)),
      ),
      body: StreamBuilder<Post?>(
        stream: firestoreService.getPostStream(postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final post = snapshot.data;
          if (post == null) {
            return const Center(child: Text('Post not found.'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPostContent(context, post, firestoreService),
                _buildCommentsSection(context, post, firestoreService),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostContent(
    BuildContext context,
    Post post,
    FirestoreService fs,
  ) {
    String categoryLabel = 'General';
    Color categoryColor = const Color(0xFFE8F5E9);
    Color categoryTextColor = const Color(0xFF2E7D32);

    switch (post.category) {
      case 'qna':
        categoryLabel = 'Q&A';
        categoryColor = const Color(0xFFE3F2FD);
        categoryTextColor = const Color(0xFF1565C0);
        break;
      case 'events':
        categoryLabel = 'Events';
        categoryColor = const Color(0xFFFFF3E0);
        categoryTextColor = const Color(0xFFEF6C00);
        break;
      case 'jobs':
        categoryLabel = 'Jobs';
        categoryColor = const Color(0xFFEDE7F6);
        categoryTextColor = const Color(0xFF4527A0);
        break;
      case 'market':
        categoryLabel = 'Market';
        categoryColor = const Color(0xFFE8F5E9);
        categoryTextColor = const Color(0xFF2E7D32);
        break;
      case 'meetups':
        categoryLabel = 'Meetups';
        categoryColor = const Color(0xFFFFF8E1);
        categoryTextColor = const Color(0xFFFF8F00);
        break;
      default:
        categoryLabel = 'General';
        categoryColor = const Color(0xFFF3E5F5);
        categoryTextColor = const Color(0xFF7B1FA2);
    }

    final uid = fs.currentUserId ?? '';
    final isLiked = post.likedBy.contains(uid);
    final isScrapped = post.scrappedBy.contains(uid);
    final isOwner = post.authorId == uid;

    final now = DateTime.now();
    final difference = now.difference(post.timestamp);
    String timeAgo = '';
    if (difference.inDays > 0) {
      timeAgo = '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      timeAgo = '${difference.inMinutes}m ago';
    } else {
      timeAgo = 'Just now';
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Info
          StreamBuilder<app_models.User?>(
            stream: fs.getUserStream(post.authorId),
            builder: (ctx, userSnap) {
              final user = userSnap.data;
              final authorName = user?.name ?? post.authorName;
              final authorAvatar = user?.avatarUrl ?? '';

              return Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfileScreen(userId: post.authorId),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.teal[50],
                      backgroundImage: authorAvatar.isNotEmpty
                          ? NetworkImage(authorAvatar)
                          : null,
                      child: authorAvatar.isEmpty
                          ? Text(
                              authorName.isNotEmpty
                                  ? authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.teal[700],
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserProfileScreen(userId: post.authorId),
                              ),
                            );
                          },
                          child: Text(
                            authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(top: 4, right: 6),
                              decoration: BoxDecoration(
                                color: categoryColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoryLabel,
                                style: TextStyle(
                                  color: categoryTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              timeAgo,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.grey,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Post?'),
                            content: const Text(
                              'This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await fs.deletePost(post.id);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (post.title.isNotEmpty) ...[
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1F36),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 16),
          if (post.imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                post.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButtons(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${post.likes}',
                  color: isLiked ? Colors.red : Colors.grey[600]!,
                  onTap: () => fs.toggleLikePost(post.id),
                ),
                _buildActionButtons(
                  icon: Icons.chat_bubble_outline,
                  label: '${post.comments}',
                  color: Colors.grey[600]!,
                  onTap: () {
                    // Scroll to comments ?
                  },
                ),
                _buildActionButtons(
                  icon: isScrapped ? Icons.bookmark : Icons.bookmark_border,
                  label: 'Scrap',
                  color: isScrapped ? Colors.teal : Colors.grey[600]!,
                  onTap: () => fs.toggleScrapPost(post.id),
                ),
                _buildActionButtons(
                  icon: Icons.ios_share,
                  label: 'Share',
                  color: Colors.grey[600]!,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) => ShareContentSheet(
                        itemId: post.id,
                        itemType: 'post',
                        itemTitle: post.title.isNotEmpty
                            ? post.title
                            : 'Post by ${post.authorName}',
                        itemDescription: post.content,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(
    BuildContext context,
    Post post,
    FirestoreService fs,
  ) {
    final commentController = TextEditingController();
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1F36),
              ),
            ),
          ),
          StreamBuilder(
            stream: fs.getComments(post.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final comments = snapshot.data as List;
              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Be the first to comment!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: comments.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final c = comments[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.teal[50],
                      child: Text(
                        c.authorName[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.teal[700],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      c.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        c.content,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.teal,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        if (commentController.text.trim().isNotEmpty) {
                          fs.addComment(post.id, commentController.text.trim());
                          commentController.clear();
                        }
                      },
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
