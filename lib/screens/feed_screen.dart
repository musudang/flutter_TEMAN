import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';
import '../models/meetup_model.dart';
import '../models/question_model.dart';
import '../models/user_model.dart' as app_models;
import 'create_post_screen.dart';
import 'conversation_list_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'meetup_detail_screen.dart';
import 'meetup_list_screen.dart';
import 'jobs_screen.dart';
import 'job_detail_screen.dart';
import 'marketplace_list_screen.dart';
import 'marketplace_detail_screen.dart';
import '../models/job_model.dart';
import '../models/marketplace_model.dart';
import '../widgets/meetup_card.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import 'share_content_sheet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            setState(() {
              _selectedFilter = 'All';
            });
          },
          child: const Text(
            'TEMAN',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: Color(0xFF1A1F36),
              letterSpacing: -0.5,
            ),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1A1F36)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF1A1F36),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConversationListScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF1A1F36),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'All',
                    isSelected: _selectedFilter == 'All',
                    color: const Color(0xFFFF5A5F),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'General',
                    icon: Icons.article_outlined,
                    isSelected: _selectedFilter == 'General',
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Meetups',
                    icon: Icons.groups_outlined,
                    isSelected: _selectedFilter == 'Meetups',
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Events',
                    icon: Icons.calendar_today_outlined,
                    isSelected: _selectedFilter == 'Events',
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Q&A',
                    icon: Icons.help_outline,
                    isSelected: _selectedFilter == 'Q&A',
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Market',
                    icon: Icons.storefront_outlined,
                    isSelected: _selectedFilter == 'Market',
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Jobs',
                    icon: Icons.work_outline,
                    isSelected: _selectedFilter == 'Jobs',
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),

          // Dynamic Feed or Category-specific screen
          Expanded(child: _buildBody(firestoreService)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'post_fab',
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildBody(FirestoreService firestoreService) {
    // Navigate to dedicated screens for Jobs and Market
    if (_selectedFilter == 'Jobs') {
      return const JobsScreen(embedded: true);
    }
    if (_selectedFilter == 'Market') {
      return const MarketplaceListScreen(embedded: true);
    }
    if (_selectedFilter == 'Meetups') {
      return const MeetupListScreen(embedded: true);
    }

    // For All, Q&A, Events, and Meetup Categories – use the feed stream
    return StreamBuilder<List<dynamic>>(
      stream: firestoreService.getFeed(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        final filteredItems = items.where((item) {
          if (_selectedFilter == 'All') return true;
          if (_selectedFilter == 'General') {
            if (item is Post && item.category == 'general') return true;
            return false;
          }
          if (_selectedFilter == 'Q&A') {
            if (item is Post && item.category == 'qna') return true;
            if (item is Question) return true;
            return false;
          }
          if (_selectedFilter == 'Events') {
            // Only show Posts with category 'event' OR 'events'
            // Explicitly exclude Meetups from this tab as per user request
            if (item is Post &&
                (item.category == 'event' || item.category == 'events')) {
              return true;
            }
            return false;
          }

          // If 'All' is selected, it will return true at the beginning.
          return false;
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feed_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: filteredItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            if (item is Post) {
              return _buildPostItem(item, firestoreService);
            } else if (item is Meetup) {
              return MeetupCard(
                meetup: item,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MeetupDetailScreen(meetupId: item.id),
                    ),
                  );
                },
              );
            } else if (item is Job) {
              return _buildJobItem(item);
            } else if (item is MarketplaceItem) {
              return _buildMarketplaceItem(item);
            } else if (item is Question) {
              return _buildQuestionItem(item);
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String value, {
    IconData? icon,
    required bool isSelected,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
            ],
            Text(
              value,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostItem(Post post, FirestoreService firestoreService) {
    // Use stored category instead of content-based heuristic
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

    final uid = firestoreService.currentUserId ?? '';
    final isLiked = post.likedBy.contains(uid);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: post.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live User Data Stream
            StreamBuilder<app_models.User?>(
              stream: firestoreService.getUserStream(post.authorId),
              builder: (context, userSnap) {
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
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1A1F36),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
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
                              const SizedBox(width: 6),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Share Button
                    IconButton(
                      icon: Icon(
                        Icons.ios_share,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      onPressed: () {
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
                    // Scrap Button
                    StreamBuilder<app_models.User?>(
                      stream: firestoreService.getUserStream(
                        firestoreService.currentUserId ?? '',
                      ),
                      builder: (context, userSnap) {
                        final isScrapped = post.scrappedBy.contains(
                          firestoreService.currentUserId,
                        );
                        return IconButton(
                          icon: Icon(
                            isScrapped ? Icons.bookmark : Icons.bookmark_border,
                            color: isScrapped ? Colors.teal : Colors.grey[400],
                            size: 24,
                          ),
                          onPressed: () =>
                              firestoreService.toggleScrapPost(post.id),
                        );
                      },
                    ),
                    // Delete menu for owner / admin
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      onSelected: (value) async {
                        if (value == 'delete') {
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
                            await firestoreService.deletePost(post.id);
                          }
                        }
                      },
                      itemBuilder: (ctx) {
                        final isOwner = post.authorId == uid;
                        return [
                          if (isOwner)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete Post'),
                            ),
                          // Admin check is async; for simplicity we always show if owner.
                          // Admin deletion is handled server-side in deletePost().
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Report / Delete'),
                          ),
                        ];
                      },
                    ),
                  ],
                );
              },
            ),
            if (post.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (post.title.isNotEmpty) ...[
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              post.content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => firestoreService.toggleLikePost(post.id),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isLiked ? Colors.red : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.likes}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () =>
                      _showCommentSheet(context, post.id, firestoreService),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.comments}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentSheet(
    BuildContext context,
    String postId,
    FirestoreService service,
  ) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Comments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 250,
                child: StreamBuilder(
                  stream: service.getComments(postId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
                      return const Center(child: Text('No comments yet'));
                    }
                    final comments = snapshot.data as List;
                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.teal[50],
                            child: Text(
                              c.authorName[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.teal[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            c.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(c.content),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.teal),
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        service.addComment(postId, controller.text.trim());
                        controller.clear();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJobItem(Job job) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE7F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Jobs',
                              style: TextStyle(
                                color: Color(0xFF4527A0),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            job.companyName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  job.location,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  job.salary,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceItem(MarketplaceItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketplaceDetailScreen(item: item),
          ),
        );
      },
      child: Container(
        height: 120, // fixed height for inline market item
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 120,
              height: 120,
              color: Colors.grey[200],
              child: item.imageUrls.isNotEmpty
                  ? Image.network(item.imageUrls.first, fit: BoxFit.cover)
                  : const Icon(Icons.image, color: Colors.grey, size: 40),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Market',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.condition,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₩${item.price.toStringAsFixed(0)}', // Adjust formatter if numberformat is preferred
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: item.sellerAvatar.isNotEmpty
                              ? NetworkImage(item.sellerAvatar)
                              : null,
                          child: item.sellerAvatar.isEmpty
                              ? Text(
                                  item.sellerName.isNotEmpty
                                      ? item.sellerName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.sellerName,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
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
      ),
    );
  }

  Widget _buildQuestionItem(Question question) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3F2FD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Q&A',
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                question.authorName,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF1A1F36),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
