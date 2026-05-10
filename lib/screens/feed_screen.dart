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
import '../models/job_model.dart';
import '../models/marketplace_model.dart';
import '../widgets/meetup_card.dart';
import 'user_profile_screen.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import 'share_content_sheet.dart';
import '../widgets/teman_logo.dart';
import '../widgets/report_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notices_screen.dart';
import '../widgets/university_drawer.dart';
import '../widgets/university_badge.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedFilter = 'All';

  // Pagination state
  final List<dynamic> _feedItems = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DateTime? _lastTimestamp;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Sub-categories removed

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    Future.microtask(() => _loadFeed(refresh: true));
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadFeed();
      }
    }
  }

  Future<void> _loadFeed({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      if (!mounted) return;
      setState(() {
        _hasMore = true;
        _lastTimestamp = null;
      });
    }

    if (!_hasMore) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    try {
      final newItems = await firestoreService.fetchFeedPage(
        limit: 20,
        lastTimestamp: _lastTimestamp,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;

        if (refresh) {
          _feedItems.clear();
        }

        if (newItems.isNotEmpty) {
          _feedItems.addAll(newItems);

          final lastObj = newItems.last;
          if (lastObj is Post) {
            _lastTimestamp = lastObj.timestamp;
          } else if (lastObj is Meetup) {
            _lastTimestamp = lastObj.createdAt;
          } else if (lastObj is Job) {
            _lastTimestamp = lastObj.postedDate;
          } else if (lastObj is MarketplaceItem) {
            _lastTimestamp = lastObj.postedDate;
          } else if (lastObj is Question) {
            _lastTimestamp = lastObj.timestamp;
          }
        } else {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint("Error loading feed: \$e");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const UniversityDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1A1F36)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: GestureDetector(
          onTap: () {
            setState(() {
              _selectedFilter = 'All';
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TemanLogoWidget(size: 28),
              const SizedBox(width: 8),
              const Text(
                'TEMAN',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: Color(0xFF1E56C8),
                  letterSpacing: -0.5,
                ),
              ),
            ],
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
            icon: StreamBuilder<int>(
              stream: firestoreService.getTotalUnreadMessageCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.red,
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: Color(0xFF1A1F36),
                  ),
                );
              },
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
            icon: StreamBuilder<int>(
              stream: firestoreService.getUnreadNotificationCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.red,
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF1A1F36),
                  ),
                );
              },
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
                    'Q&A',
                    icon: Icons.help_outline,
                    isSelected: _selectedFilter == 'Q&A',
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Events',
                    icon: Icons.event,
                    isSelected: _selectedFilter == 'Events',
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
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Meetups',
                    icon: Icons.groups_outlined,
                    isSelected: _selectedFilter == 'Meetups',
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),

          // Dynamic Feed or Category-specific screen
          Expanded(
            child: StreamBuilder<app_models.User?>(
              stream: firestoreService.currentUserId != null
                  ? firestoreService.getUserStream(
                      firestoreService.currentUserId!,
                    )
                  : null,
              builder: (context, userSnap) {
                final hiddenUsers = <String>[
                  ...(userSnap.data?.blockedUsers ?? []),
                  ...(userSnap.data?.blockedBy ?? []),
                ];
                return _buildBody(firestoreService, hiddenUsers: hiddenUsers);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'post_fab',
        elevation: 4,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
          if (result == true && mounted) {
            _loadFeed(refresh: true);
          }
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildBody(
    FirestoreService firestoreService, {
    List<String> hiddenUsers = const [],
  }) {
    // Navigate to dedicated screens for Meetups
    if (_selectedFilter == 'Meetups') {
      return const MeetupListScreen(embedded: true);
    }

    // NOTE: Previously this branch used a StreamBuilder around
    // `getFeedStream` only when (`All` && `_lastTimestamp == null`). That
    // caused two problems:
    //   (a) the StreamBuilder was rebuilt each setState, re-subscribing the
    //       stream and resetting connectionState back to `waiting` →
    //       infinite loader on 'All' / 'General' until the user touched
    //       'Events' (which mutated state in a way that broke the loop).
    //   (b) data flowed only into the StreamBuilder's local `items`, not
    //       into `_feedItems`, so 'General' (which client-side filters
    //       `_feedItems`) appeared empty.
    // Real-time engagement (likes, scraps, share) is now handled per-post
    // via `getPostStream` inside the post card, so we no longer need a
    // global feed stream here. Use a single client-side filter path.

    // Filter items based on hidden users AND selected filter!
    final filteredItems = _feedItems.where((item) {
      // Apply hidden users filter locally
      String authorId = '';
      if (item is Post) {
        authorId = item.authorId;
      } else if (item is Meetup) {
        authorId = item.host.id;
      } else if (item is Job) {
        authorId = item.authorId;
      } else if (item is MarketplaceItem) {
        authorId = item.sellerId;
      } else if (item is Question) {
        authorId = item.authorId;
      }

      if (hiddenUsers.contains(authorId)) return false;

      // Also apply selected filter category
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'General' && item is Post && item.category == 'general') return true;
      if (_selectedFilter == 'Q&A' && item is Post && item.category == 'qna') return true;
      if (_selectedFilter == 'Events' && item is Post && item.category == 'events') return true;
      if (_selectedFilter == 'Market' && item is Post && item.category == 'market') return true;
      if (_selectedFilter == 'Jobs' && item is Post && item.category == 'jobs') return true;
      return false;
    }).toList();

    // Auto-fetch more if filtered is empty but there's more overall
    if (filteredItems.isEmpty &&
        _hasMore &&
        !_isLoading &&
        _feedItems.isNotEmpty) {
      Future.microtask(() => _loadFeed());
    }

    return _buildListView(filteredItems, firestoreService);
  }

  Widget _buildListView(
    List<dynamic> items,
    FirestoreService firestoreService, {
    bool isRealTime = false,
  }) {
    return RefreshIndicator(
      onRefresh: () => _loadFeed(refresh: true),
      child: items.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.feed_outlined,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No posts yet',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              controller: isRealTime ? null : _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              itemCount: items.length + (!isRealTime && _hasMore ? 1 : 0) + (_selectedFilter == 'All' ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                int listIndex = index;
                if (_selectedFilter == 'All') {
                  if (index == 0) return _buildNoticesBanner();
                  listIndex -= 1;
                }
                
                if (!isRealTime && listIndex == items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (listIndex >= items.length || listIndex < 0) return const SizedBox.shrink();

                final item = items[listIndex];
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
                }
                return const SizedBox.shrink();
              },
            ),
    );
  }

  Widget _buildNoticesBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notices')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data!.docs.first;
        final notice = Notice.fromFirestore(doc);

        return Container(
          color: Colors.white,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Color(0xFFEF6C00),
                  size: 20,
                ),
              ),
              title: Text(
                notice.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF1A1F36),
                ),
              ),
              subtitle: const Text(
                'Tap to expand',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    notice.content,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NoticesScreen(isAdmin: false),
                        ),
                      );
                    },
                    child: const Text(
                      'View All Notices →',
                      style: TextStyle(
                        color: Color(0xFF1E56C8),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
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
                final authorName = post.isAnonymous
                    ? 'Anonymous'
                    : (user?.name ?? post.authorName);
                final authorAvatar = post.isAnonymous
                    ? ''
                    : (user?.avatarUrl ?? '');

                return Row(
                  children: [
                    GestureDetector(
                      onTap: post.isAnonymous
                          ? null
                          : () {
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
                            onTap: post.isAnonymous
                                ? null
                                : () {
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
                                          builder: (_) => UserProfileScreen(
                                            userId: post.authorId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF1A1F36),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if ((post.authorUniversityId != null && post.authorUniversityId!.isNotEmpty) || (!post.isAnonymous && user != null && user.universityId.isNotEmpty)) ...[
                                  const SizedBox(width: 6),
                                  UniversityBadge(universityId: post.authorUniversityId?.isNotEmpty == true ? post.authorUniversityId! : user!.universityId),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
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
                                  post.eventDate != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                        // Increment share counter on the post document
                        firestoreService.incrementSharePost(post.id);
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
                    // Scrap Button — listen to the post itself so toggling
                    // updates instantly (was previously listening to user doc,
                    // which caused ~1 min delay before the icon flipped).
                    StreamBuilder<Post?>(
                      stream: firestoreService.getPostStream(post.id),
                      builder: (context, postSnap) {
                        final livePost = postSnap.data ?? post;
                        final isScrapped = livePost.scrappedBy.contains(
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
                    // 3-dot menu: owner → Delete, others → Report
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
                        } else if (value == 'report') {
                          showReportPostDialog(context, post.id);
                        }
                      },
                      itemBuilder: (ctx) {
                        final isOwner = post.authorId == uid;
                        if (isOwner) {
                          return [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete Post',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ];
                        } else {
                          return [
                            const PopupMenuItem(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.flag_outlined,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Report Post'),
                                ],
                              ),
                            ),
                          ];
                        }
                      },
                    ),
                  ],
                );
              },
            ),
            if (post.imageUrls.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrls.first,
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
            if (post.sharedItemId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    if (post.sharedItemImage != null && post.sharedItemImage!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          post.sharedItemImage!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.article, color: Colors.grey, size: 20),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shared ${post.sharedItemType ?? 'Item'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            post.sharedItemTitle ?? 'Untitled',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1F36),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            // Wrap likes/comments row in a post stream so likes/comments
            // counters and the heart fill state update instantly without
            // having to open the post detail screen.
            StreamBuilder<Post?>(
              stream: firestoreService.getPostStream(post.id),
              builder: (context, postSnap) {
                final livePost = postSnap.data ?? post;
                final liveIsLiked = livePost.likedBy.contains(uid);
                return Row(
                  children: [
                    InkWell(
                      onTap: () => firestoreService.toggleLikePost(post.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              liveIsLiked ? Icons.favorite : Icons.favorite_border,
                              size: 20,
                              color: liveIsLiked ? Colors.red : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${livePost.likes}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () =>
                          _showCommentSheet(context, post, firestoreService),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${livePost.comments}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentSheet(
    BuildContext context,
    Post post,
    FirestoreService service,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: PostCommentsSection(post: post, fs: service),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
