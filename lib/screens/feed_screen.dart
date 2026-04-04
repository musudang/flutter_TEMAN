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
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import 'share_content_sheet.dart';
import '../widgets/teman_logo.dart';
import '../widgets/report_dialog.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedFilter = 'All';
  String _selectedEventSubCategory = 'ALL';
  String _selectedQnaSubCategory = 'ALL';

  // Pagination state
  final List<dynamic> _feedItems = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DateTime? _lastTimestamp;

  final ScrollController _scrollController = ScrollController();

  final List<String> _eventSubCategories = [
    'ALL',
    'CONCERT',
    'LOCAL FESTIVAL',
    'ACADEMIC',
    'CAREER',
    'EXPO',
    'EXHIBITION',
    'POP-UP',
    'NETWORKING',
    'OTHERS',
  ];
  final List<String> _qnaSubCategories = [
    'ALL',
    'IMMIGRATION',
    'ACADEMICS',
    'HOUSING',
    'JOBS',
    'DAILY LIFE',
    'LANGUAGE',
    'OTHERS',
  ];

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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
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

          // Sub-category Chips
          if (_selectedFilter == 'Events' || _selectedFilter == 'Q&A')
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      (_selectedFilter == 'Events'
                              ? _eventSubCategories
                              : _qnaSubCategories)
                          .map((sub) {
                            final isSelected = _selectedFilter == 'Events'
                                ? _selectedEventSubCategory == sub
                                : _selectedQnaSubCategory == sub;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(
                                  sub,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      if (_selectedFilter == 'Events') {
                                        _selectedEventSubCategory = sub;
                                      } else {
                                        _selectedQnaSubCategory = sub;
                                      }
                                    });
                                  }
                                },
                                selectedColor: const Color(
                                  0xFFFF5A5F,
                                ).withValues(alpha: 0.15),
                                backgroundColor: Colors.grey[100],
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFFF5A5F)
                                      : Colors.grey[700],
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFFFF5A5F)
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
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

  Widget _buildBody(
    FirestoreService firestoreService, {
    List<String> hiddenUsers = const [],
  }) {
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
      if (_selectedFilter == 'General') {
        if (item is Post && item.category == 'general') return true;
        return false;
      }
      if (_selectedFilter == 'Q&A') {
        if (item is Post && item.category == 'qna') {
          if (_selectedQnaSubCategory != 'ALL' &&
              item.subCategory != _selectedQnaSubCategory) {
            return false;
          }
          return true;
        }
        if (item is Question) {
          return _selectedQnaSubCategory == 'ALL';
        }
        return false;
      }
      if (_selectedFilter == 'Events') {
        // Only show Posts with category 'event' OR 'events'
        if (item is Post &&
            (item.category == 'event' || item.category == 'events')) {
          if (_selectedEventSubCategory != 'ALL' &&
              item.subCategory != _selectedEventSubCategory) {
            return false;
          }
          return true;
        }
        return false;
      }

      return false;
    }).toList();

    // Auto-fetch more if filtered is empty but there's more overall
    if (filteredItems.isEmpty &&
        _hasMore &&
        !_isLoading &&
        _feedItems.isNotEmpty) {
      Future.microtask(() => _loadFeed());
    }

    return RefreshIndicator(
      onRefresh: () => _loadFeed(refresh: true),
      child: _feedItems.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredItems.isEmpty
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
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              itemCount: filteredItems.length + (_hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == filteredItems.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
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
            ),
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
                                    builder: (_) => UserProfileScreen(
                                      userId: post.authorId,
                                    ),
                                  ),
                                );
                              }
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
                                const SizedBox(width: 6),
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
                              ],
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
                      _showCommentSheet(context, post, firestoreService),
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
