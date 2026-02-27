import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart' as app_models;
import '../models/post_model.dart';
import '../models/meetup_model.dart';
import 'edit_profile_screen.dart';
import 'conversation_list_screen.dart';
import 'meetup_detail_screen.dart';
import 'follow_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      body: FutureBuilder<app_models.User?>(
        future: firestoreService.getCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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
                            const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1F36),
                              ),
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
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.settings_outlined,
                                    color: Colors.grey,
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'logout') {
                                      final authService =
                                          Provider.of<AuthService>(
                                            context,
                                            listen: false,
                                          );
                                      await authService.signOut();
                                    } else if (value == 'reset') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Reset App Data?'),
                                          content: const Text(
                                            'WARNING: This will delete ALL posts, meetups, and user data. This cannot be undone.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                'RESET EVERYTHING',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await firestoreService.resetAppData();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Data reset complete.',
                                              ),
                                            ),
                                          );
                                          // Force reload or sign out might be needed to clear local state visually
                                          setState(() {});
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'reset',
                                      child: Text(
                                        'Reset App Data',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'logout',
                                      child: Text('Sign Out'),
                                    ),
                                  ],
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
                _buildMyPostsList(firestoreService, user.id),
                _buildJoinedMeetupsList(firestoreService, user.id),
                _buildScrappedPostsList(firestoreService, user.id),
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

  Widget _buildMyPostsList(FirestoreService service, String userId) {
    return StreamBuilder<List<Post>>(
      stream: service.getUserPosts(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return _buildEmptyState(Icons.article_outlined, "No posts yet");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(
                  post.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => service.deletePost(post.id),
                ),
              ),
            );
          },
        );
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: meetups.length,
          itemBuilder: (context, index) {
            final meetup = meetups[index];
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
          },
        );
      },
    );
  }

  Widget _buildScrappedPostsList(FirestoreService service, String userId) {
    return StreamBuilder<List<dynamic>>(
      stream: service.getScrappedFeed(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _buildEmptyState(Icons.bookmark_border, "No scrapped items");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is Post) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    item.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.bookmark, color: Colors.teal),
                ),
              );
            } else if (item is Meetup) {
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
                            MeetupDetailScreen(meetupId: item.id),
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
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${DateFormat('MMM d').format(item.dateTime)} • ${item.participantIds.length} joined',
                  ),
                  trailing: const Icon(Icons.bookmark, color: Colors.teal),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
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
