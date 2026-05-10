import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart' as app_models;
import '../models/post_model.dart';
import '../models/meetup_model.dart';
import 'edit_profile_screen.dart';
import 'conversation_list_screen.dart';
import 'meetup_detail_screen.dart';
import 'follow_list_screen.dart';
import 'job_detail_screen.dart';
import 'marketplace_detail_screen.dart';
import '../models/job_model.dart';
import '../models/marketplace_model.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';
import '../widgets/university_badge.dart';
import '../models/question_model.dart';
import 'university_qna_detail_screen.dart';
import 'university_feed_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── My Posts cache ──
  // Each of the four sources (main posts, jobs, marketplace, university
  // posts) was previously a nested StreamBuilder. Whenever the parent
  // rebuilt, all four were re-subscribed and individually flickered
  // through `connectionState == waiting` → `hasData==true`. The
  // university-posts stream emits noticeably later than the others
  // (collectionGroup query), which is why uni posts appeared and then
  // vanished on every rebuild. Holding the latest emission of each
  // stream in state eliminates the flicker.
  String? _myPostsUid;
  StreamSubscription<List<Post>>? _postsSub;
  StreamSubscription<List<Job>>? _jobsSub;
  StreamSubscription<List<MarketplaceItem>>? _marketSub;
  StreamSubscription<List<Post>>? _uniPostsSub;
  StreamSubscription<List<Question>>? _uniQuestionsSub;
  List<Post> _cachedPosts = [];
  List<Job> _cachedJobs = [];
  List<MarketplaceItem> _cachedMarket = [];
  List<Post> _cachedUniPosts = [];
  List<Question> _cachedUniQuestions = [];
  bool _myPostsInitialLoad = true;

  // ── Scrapped Feed cache ──
  String? _scrappedUid;
  StreamSubscription<List<dynamic>>? _scrappedFeedSub;
  StreamSubscription<List<Post>>? _scrappedUniPostsSub;
  StreamSubscription<List<Question>>? _scrappedUniQuestionsSub;
  List<dynamic> _cachedScrappedFeed = [];
  List<Post> _cachedScrappedUniPosts = [];
  List<Question> _cachedScrappedUniQuestions = [];
  bool _scrappedInitialLoad = true;

  void _ensureMyPostsSubscriptions(FirestoreService service, app_models.User user) {
    if (_myPostsUid == user.id) return;
    _myPostsUid = user.id;
    _postsSub?.cancel();
    _jobsSub?.cancel();
    _marketSub?.cancel();
    _uniPostsSub?.cancel();
    _uniQuestionsSub?.cancel();
    _cachedPosts = [];
    _cachedJobs = [];
    _cachedMarket = [];
    _cachedUniPosts = [];
    _cachedUniQuestions = [];
    _myPostsInitialLoad = true;

    _postsSub = service.getUserPosts(user.id).listen((d) {
      if (!mounted) return;
      setState(() {
        _cachedPosts = d;
        _myPostsInitialLoad = false;
      });
    });
    _jobsSub = service.getUserJobs(user.id).listen((d) {
      if (!mounted) return;
      setState(() => _cachedJobs = d);
    });
    _marketSub = service.getUserMarketplaceItems(user.id).listen((d) {
      if (!mounted) return;
      setState(() => _cachedMarket = d);
    });
    
    if (user.universityId.isNotEmpty) {
      _uniPostsSub = service.getUniversityPostsByUser(user.universityId, user.id).listen(
        (d) {
          if (!mounted) return;
          setState(() => _cachedUniPosts = d);
        },
        onError: (e, st) {
          debugPrint('[ProfileScreen] getUserUniversityPosts error: $e');
        },
      );
      _uniQuestionsSub = service.getUniversityQuestionsByUser(user.universityId, user.id).listen(
        (d) {
          if (!mounted) return;
          setState(() => _cachedUniQuestions = d);
        },
        onError: (e, st) {
          debugPrint('[ProfileScreen] getUserUniversityQuestions error: $e');
        },
      );
    }
  }

  void _ensureScrappedSubscriptions(FirestoreService service, app_models.User user) {
    if (_scrappedUid == user.id) return;
    _scrappedUid = user.id;
    _scrappedFeedSub?.cancel();
    _scrappedUniPostsSub?.cancel();
    _scrappedUniQuestionsSub?.cancel();
    _cachedScrappedFeed = [];
    _cachedScrappedUniPosts = [];
    _cachedScrappedUniQuestions = [];
    _scrappedInitialLoad = true;

    _scrappedFeedSub = service.getScrappedFeed(user.id).listen((d) {
      if (!mounted) return;
      setState(() {
        _cachedScrappedFeed = d;
        _scrappedInitialLoad = false;
      });
    });

    if (user.universityId.isNotEmpty) {
      _scrappedUniPostsSub = service.getScrappedUniversityPosts(user.universityId, user.id).listen((d) {
        if (!mounted) return;
        setState(() => _cachedScrappedUniPosts = d);
      });
      _scrappedUniQuestionsSub = service.getScrappedUniversityQuestions(user.universityId, user.id).listen((d) {
        if (!mounted) return;
        setState(() => _cachedScrappedUniQuestions = d);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postsSub?.cancel();
    _jobsSub?.cancel();
    _marketSub?.cancel();
    _uniPostsSub?.cancel();
    _uniQuestionsSub?.cancel();
    _scrappedFeedSub?.cancel();
    _scrappedUniPostsSub?.cancel();
    _scrappedUniQuestionsSub?.cancel();
    super.dispose();
  }

  Future<void> _launchInstagram(String instagramId) async {
    final Uri url;
    if (instagramId.startsWith('http')) {
      url = Uri.parse(instagramId);
    } else {
      url = Uri.parse('https://instagram.com/$instagramId');
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Instagram')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<app_models.User?>(
        stream: firestoreService.getUserStream(firestoreService.currentUserId ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('Unable to load profile'));
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                    child: Column(
                      children: [
                        // Top bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                if (Navigator.canPop(context))
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: BackButton(color: Color(0xFF1A1F36)),
                                  ),
                                const Text(
                                  'Profile',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1F36),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.teal,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditProfileScreen(user: user),
                                      ),
                                    ).then((_) {
                                      setState(() {});
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.settings_outlined,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SettingsScreen(user: user),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Avatar
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.teal[50],
                          backgroundImage: (user.avatarUrl.isNotEmpty)
                              ? NetworkImage(user.avatarUrl)
                              : null,
                          child: user.avatarUrl.isEmpty
                              ? Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[700],
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Name
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1F36),
                          ),
                        ),

                        // Instagram Link
                        if (user.instagramId.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _launchInstagram(user.instagramId),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.link,
                                  size: 16,
                                  color: Colors.pink[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Instagram',
                                  style: TextStyle(
                                    color: Colors.pink[400],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Stats (Followers/Following)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem(
                              context,
                              'Followers',
                              user.followers.length,
                              user.id,
                              user.name,
                              0,
                            ),
                            Container(
                              height: 20,
                              width: 1,
                              color: Colors.grey[300],
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ),
                            _buildStatItem(
                              context,
                              'Following',
                              user.following.length,
                              user.id,
                              user.name,
                              1,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Nationality & Join date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user.nationality,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal[700],
                                ),
                              ),
                            ),
                            if (user.isAdmin) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '⭐ Admin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                            if (user.universityId.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              UniversityBadge(
                                universityId: user.universityId,
                                fontSize: 11,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Bio
                        if (user.bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              user.bio,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Messages button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ConversationListScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            label: const Text('My Messages'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tab Bar
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.teal,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.teal,
                      tabs: const [
                        Tab(text: 'My Posts'),
                        Tab(text: 'Joined Meetups'),
                        Tab(text: 'Scrapped'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildMyPostsList(firestoreService, user),
                _buildJoinedMeetupsList(firestoreService, user.id),
                _buildScrappedPostsList(firestoreService, user),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    int count,
    String userId,
    String userName,
    int tabIndex,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FollowListScreen(
              userId: userId,
              userName: userName,
              initialTabIndex: tabIndex,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1F36),
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildMyPostsList(FirestoreService service, app_models.User user) {
    // Subscribe-once + cache pattern (see _ensureMyPostsSubscriptions doc).
    _ensureMyPostsSubscriptions(service, user);

    if (_myPostsInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    // Build the combined list directly from cached data (no nested
    // StreamBuilders → no flicker).
    final List<dynamic> allItems = [
      ..._cachedPosts,
      ..._cachedJobs,
      ..._cachedMarket,
    ];

    for (var uniPost in _cachedUniPosts) {
      // Avoid duplicates if post already exists in main feed
      if (!allItems.any((item) => item is Post && item.id == uniPost.id)) {
        allItems.add(_UniPostWrapper(uniPost));
      }
    }
    
    for (var uniQ in _cachedUniQuestions) {
      allItems.add(_UniQuestionWrapper(uniQ));
    }

    if (allItems.isEmpty) {
      return _buildEmptyState(
        Icons.article_outlined,
        'No posts yet',
      );
    }

    return _buildMyPostsListView(allItems, service, user);
  }

  Widget _buildMyPostsListView(List<dynamic> allItems, FirestoreService service, app_models.User user) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        if (item is _UniPostWrapper) {
                          // University post card with distinctive styling
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => UniversityPostDetailSheet(
                                    post: item.post,
                                    uniId: user.universityId,
                                    uniColor: const Color(0xFF1565C0),
                                  ),
                                );
                              },
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.school_outlined,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                              title: Text(
                                item.post.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                item.post.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.post.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        } else if (item is _UniQuestionWrapper) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UniversityQnaDetailScreen(
                                      question: item.question,
                                      uniId: user.universityId,
                                      uniColor: const Color(0xFF1565C0),
                                    ),
                                  ),
                                );
                              },
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.help_outline_rounded,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                              title: Text(
                                item.question.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                item.question.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(8),
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
                            ),
                          );
                        } else if (item is Post) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(postId: item.id),
                            ),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.teal[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.article_outlined,
                              color: Colors.teal,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            item.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => service.deletePost(item.id),
                          ),
                        ),
                      );
                    } else if (item is Job) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JobDetailScreen(job: item),
                            ),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE7F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.work_outline,
                              color: Color(0xFF4527A0),
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE7F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Job',
                              style: TextStyle(
                                color: Color(0xFF4527A0),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      );
                    } else if (item is MarketplaceItem) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MarketplaceDetailScreen(item: item),
                            ),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '₩${item.price.toStringAsFixed(0)} • ${item.condition}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Market',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
      },
    );
  }

  Widget _buildJoinedMeetupsList(FirestoreService service, String userId) {
    return StreamBuilder<List<Meetup>>(
      stream: service.getJoinedMeetups(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final meetups = snapshot.data!;
        if (meetups.isEmpty) {
          return _buildEmptyState(
            Icons.groups_outlined,
            "No joined meetups yet",
          );
        }

        // Split into active (upcoming / happening now) and past meetups
        final now = DateTime.now();
        final activeMeetups = meetups
            .where((m) => m.dateTime.isAfter(now) || !m.isClosed)
            .toList();
        final pastMeetups = meetups
            .where((m) => m.isClosed)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Active Meetups
            if (activeMeetups.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Active Meetups',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ),
              ...activeMeetups.map((meetup) => _buildMeetupCard(meetup)),
            ],
            if (activeMeetups.isEmpty && pastMeetups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildEmptyState(
                  Icons.event_available,
                  "No active meetups",
                ),
              ),

            // Past Meetups (Collapsible)
            if (pastMeetups.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.history,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Past Joined Meetups (${pastMeetups.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
                    subtitle: const Text(
                      'Tap to view history',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    children: pastMeetups.map((meetup) {
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.event_busy,
                            color: Colors.grey[500],
                          ),
                        ),
                        title: Text(
                          meetup.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    meetup.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.person_outline,
                                    size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  'Host: ${meetup.host.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM d, yyyy • h:mm a')
                                      .format(meetup.dateTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMeetupCard(Meetup meetup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MeetupDetailScreen(meetupId: meetup.id),
            ),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.event, color: Colors.teal[700]),
        ),
        title: Text(
          meetup.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${DateFormat('MMM d').format(meetup.dateTime)} • ${meetup.participantIds.length} joined',
        ),
      ),
    );
  }

  Widget _buildScrappedPostsList(FirestoreService service, app_models.User user) {
    _ensureScrappedSubscriptions(service, user);

    if (_scrappedInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<dynamic> allItems = [..._cachedScrappedFeed];

    for (var uniPost in _cachedScrappedUniPosts) {
      if (!allItems.any((item) => item is Post && item.id == uniPost.id)) {
        allItems.add(_UniPostWrapper(uniPost));
      }
    }

    for (var uniQ in _cachedScrappedUniQuestions) {
      allItems.add(_UniQuestionWrapper(uniQ));
    }

    if (allItems.isEmpty) {
      return _buildEmptyState(Icons.bookmark_border, "No scrapped items");
    }

    // Sort by timestamp if possible
    allItems.sort((a, b) {
      DateTime getTimestamp(dynamic item) {
        if (item is Post) return item.timestamp;
        if (item is Meetup) return item.dateTime;
        if (item is _UniPostWrapper) return item.post.timestamp;
        if (item is _UniQuestionWrapper) return item.question.timestamp;
        return DateTime(2000);
      }
      return getTimestamp(b).compareTo(getTimestamp(a));
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        
        if (item is Post) {
          return _buildScrappedCard(
            title: item.title,
            content: item.content,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(postId: item.id)),
            ),
          );
        } else if (item is Meetup) {
          return _buildScrappedCard(
            title: item.title,
            content: '${DateFormat('MMM d').format(item.dateTime)} • ${item.location}',
            icon: Icons.event,
            iconColor: Colors.teal[700],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MeetupDetailScreen(meetupId: item.id)),
            ),
          );
        } else if (item is _UniPostWrapper) {
          return _buildScrappedCard(
            title: item.post.title,
            content: item.post.content,
            icon: Icons.school_outlined,
            iconColor: const Color(0xFF1565C0),
            tag: 'University',
            tagColor: const Color(0xFFE3F2FD),
            textColor: const Color(0xFF1565C0),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => UniversityPostDetailSheet(
                  post: item.post,
                  uniId: user.universityId,
                  uniColor: const Color(0xFF1565C0),
                ),
              );
            },
          );
        } else if (item is _UniQuestionWrapper) {
          return _buildScrappedCard(
            title: item.question.title,
            content: item.question.content,
            icon: Icons.help_outline,
            iconColor: Colors.orange[700],
            tag: 'Q&A',
            tagColor: Colors.orange[50],
            textColor: Colors.orange[700],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversityQnaDetailScreen(
                    question: item.question,
                    uniId: user.universityId,
                    uniColor: Colors.orange[700]!,
                  ),
                ),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildScrappedCard({
    required String title,
    required String content,
    IconData icon = Icons.article_outlined,
    Color? iconColor,
    String? tag,
    Color? tagColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? Colors.teal).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor ?? Colors.teal),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: tag != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.bookmark, color: Colors.teal, size: 20),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

/// Simple wrapper to tag university posts in the "My Posts" list
class _UniPostWrapper {
  final Post post;
  _UniPostWrapper(this.post);
}

/// Simple wrapper to tag university questions in the "My Posts" list
class _UniQuestionWrapper {
  final Question question;
  _UniQuestionWrapper(this.question);
}
