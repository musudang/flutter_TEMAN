import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart' as app_models;
import '../services/firestore_service.dart';
import 'user_profile_screen.dart';
import 'profile_screen.dart';
import 'share_content_sheet.dart';
import 'create_post_screen.dart';
import '../widgets/report_dialog.dart';

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
                PostCommentsSection(post: post, fs: firestoreService),
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
                      if (post.authorId == uid) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UserProfileScreen(userId: post.authorId),
                          ),
                        );
                      }
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
                            if (post.authorId == uid) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserProfileScreen(userId: post.authorId),
                                ),
                              );
                            }
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
                                post.subCategory != null &&
                                        post.subCategory != 'ALL'
                                    ? '$categoryLabel \u2022 ${post.subCategory}'
                                    : categoryLabel,
                                style: TextStyle(
                                  color: categoryTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if ((post.category == 'events' ||
                                    post.category == 'event') &&
                                post.eventDate != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(top: 4, right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${post.eventDate!.month}/${post.eventDate!.day}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreatePostScreen(editingPost: post),
                            ),
                          );
                        } else if (value == 'delete') {
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
                            try {
                              await fs.deletePost(post.id);
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete post: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Post'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete Post',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  if (!isOwner)
                    IconButton(
                      icon: const Icon(
                        Icons.flag_outlined,
                        color: Colors.orange,
                      ),
                      tooltip: 'Report Post',
                      onPressed: () {
                        showReportPostDialog(context, post.id);
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
}

class PostCommentsSection extends StatefulWidget {
  final Post post;
  final FirestoreService fs;

  const PostCommentsSection({super.key, required this.post, required this.fs});

  @override
  State<PostCommentsSection> createState() => _PostCommentsSectionState();
}

class _PostCommentsSectionState extends State<PostCommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _replyToCommentId;
  String? _replyToCommentText;
  String? _replyToCommentAuthor;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToCommentText = null;
      _replyToCommentAuthor = null;
    });
  }

  void _handleReply(String id, String text, String author) {
    setState(() {
      _replyToCommentId = id;
      _replyToCommentText = text;
      _replyToCommentAuthor = author;
    });
    _focusNode.requestFocus();
  }

  void _showReactionReplySheet(Comment comment) {
    final bool isMyComment = comment.authorId == widget.fs.currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emojis
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      widget.fs.toggleCommentReaction(
                        postId: widget.post.id,
                        commentId: comment.id,
                        emoji: emoji,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _handleReply(comment.id, comment.content, comment.authorName);
                },
              ),
              if (isMyComment)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await widget.fs.deleteComment(widget.post.id, comment.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Comment deleted')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to delete: $e')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(Comment c, {bool isReply = false}) {
    bool hasReactions = c.reactions != null && c.reactions!.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _showReactionReplySheet(c),
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(
          left: isReply ? 56 : 16,
          right: 16,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 14 : 18,
              backgroundColor: Colors.teal[50],
              child: Text(
                c.authorName[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.teal[700],
                  fontSize: isReply ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isReply ? 13 : 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCommentTime(c.timestamp),
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                  if (c.replyToCommentId != null && !isReply) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          left: BorderSide(
                            color: Colors.teal.shade300,
                            width: 3,
                          ),
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Replying to ${c.replyToCommentAuthor}: ${c.replyToCommentText}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                  if (isReply && c.replyToCommentAuthor != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '@${c.replyToCommentAuthor} ',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.only(
                      top: (isReply && c.replyToCommentAuthor != null)
                          ? 2.0
                          : 4.0,
                    ),
                    child: Text(
                      c.content,
                      style: TextStyle(
                        color: const Color(0xFF4B5563),
                        fontSize: isReply ? 13 : 14,
                      ),
                    ),
                  ),
                  if (hasReactions)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 4,
                        children: _buildReactionsWidgets(c.reactions!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            stream: widget.fs.getComments(widget.post.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final commentsList = snapshot.data as List;
              if (commentsList.isEmpty) {
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

              final List<Comment> comments = commentsList.cast<Comment>();
              final Map<String, Comment> commentLookup = {
                for (var c in comments) c.id: c,
              };

              String getRootId(String commentId) {
                var currentId = commentId;
                var current = commentLookup[currentId];
                for (int i = 0; i < 10; i++) {
                  if (current == null || current.replyToCommentId == null) {
                    break;
                  }
                  if (commentLookup.containsKey(current.replyToCommentId)) {
                    currentId = current.replyToCommentId!;
                    current = commentLookup[currentId];
                  } else {
                    break; // Parent might be deleted, so this becomes a root
                  }
                }
                return currentId;
              }

              final List<Comment> rootComments = [];
              final Map<String, List<Comment>> repliesMap = {};

              for (var c in comments) {
                final rId = getRootId(c.id);
                if (rId == c.id) {
                  rootComments.add(c);
                } else {
                  repliesMap.putIfAbsent(rId, () => []).add(c);
                }
              }

              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: rootComments.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final root = rootComments[index];
                  final replies = repliesMap[root.id] ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCommentItem(root, isReply: false),
                      if (replies.isNotEmpty)
                        ...replies.map(
                          (reply) => _buildCommentItem(reply, isReply: true),
                        ),
                    ],
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_replyToCommentId != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 16, color: Colors.teal[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Replying to $_replyToCommentAuthor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.teal[700],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _cancelReply,
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
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
                            if (_commentController.text.trim().isNotEmpty) {
                              widget.fs.addComment(
                                widget.post.id,
                                _commentController.text.trim(),
                                replyToCommentId: _replyToCommentId,
                                replyToCommentText: _replyToCommentText,
                                replyToCommentAuthor: _replyToCommentAuthor,
                              );
                              _commentController.clear();
                              _cancelReply();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCommentTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  List<Widget> _buildReactionsWidgets(Map<String, String> reactionsMap) {
    final counts = <String, int>{};
    for (var emoji in reactionsMap.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts.entries.map((e) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.key, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              e.value.toString(),
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }).toList();
  }
}
