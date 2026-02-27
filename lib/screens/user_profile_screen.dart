import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart' as app_models;
import '../models/post_model.dart';
import 'chat_screen.dart';
import 'follow_list_screen.dart';

/// A screen that shows another user's public profile.
/// Accessible by tapping a participant avatar in MeetupDetailScreen, etc.
class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return FutureBuilder<app_models.User?>(
      future: firestoreService.getUserById(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
            body: const Center(child: Text('User not found')),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: Text(user.name),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1A1F36),
            elevation: 0,
          ),
          body: CustomScrollView(
            slivers: [
              // Profile Header
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.teal[50],
                        backgroundImage: user.avatarUrl.isNotEmpty
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
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Nationality + Age badges
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
                          if (user.age != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Age: ${user.age}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (user.bio.isNotEmpty)
                        Text(
                          user.bio,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      if (user.personalInfo.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          user.personalInfo,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
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
                            margin: const EdgeInsets.symmetric(horizontal: 20),
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

                      // DM Button
                      // Follow/Unfollow & Message Buttons
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<app_models.User?>(
                              stream: firestoreService.getUserStream(
                                firestoreService.currentUserId!,
                              ),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox();
                                final currentUser = snapshot.data!;
                                final isFollowing = currentUser.following
                                    .contains(userId);

                                return ElevatedButton.icon(
                                  onPressed: () async {
                                    if (isFollowing) {
                                      await firestoreService.unfollowUser(
                                        userId,
                                      );
                                    } else {
                                      await firestoreService.followUser(userId);
                                    }
                                  },
                                  icon: Icon(
                                    isFollowing
                                        ? Icons.check
                                        : Icons.person_add,
                                    size: 18,
                                  ),
                                  label: Text(
                                    isFollowing ? 'Following' : 'Follow',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing
                                        ? Colors.grey[200]
                                        : Colors.teal,
                                    foregroundColor: isFollowing
                                        ? Colors.black
                                        : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final conversationId = await firestoreService
                                      .startConversation(userId);
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          conversationId: conversationId,
                                          chatTitle: user.name,
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                              ),
                              label: const Text('Message'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal,
                                side: const BorderSide(color: Colors.teal),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // User's Posts
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text(
                    'Posts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                ),
              ),
              StreamBuilder<List<Post>>(
                stream: firestoreService.getUserPosts(userId),
                builder: (context, postSnap) {
                  if (postSnap.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }
                  final posts = postSnap.data ?? [];
                  if (posts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No posts yet.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final post = posts[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              post.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }, childCount: posts.length),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
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
}
