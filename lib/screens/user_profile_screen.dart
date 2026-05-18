import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart' as app_models;
import '../models/meetup_model.dart';
import 'chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/university_badge.dart';

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

    return StreamBuilder<app_models.User?>(
      stream: firestoreService.getUserStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
            actions: [
              if (firestoreService.currentUserId != null &&
                  firestoreService.currentUserId != userId)
                StreamBuilder<app_models.User?>(
                  stream: firestoreService.getUserStream(
                    firestoreService.currentUserId!,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox();
                    }
                    final currentUser = snapshot.data!;
                    final isBlocked = currentUser.blockedUsers.contains(userId);
                    return PopupMenuButton<String>(
                      onSelected: (value) async {
                        try {
                          if (value == 'block') {
                            await firestoreService.blockUser(userId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User blocked')),
                              );
                              Navigator.pop(context); // Close profile view
                            }
                          } else if (value == 'unblock') {
                            await firestoreService.unblockUser(userId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User unblocked')),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (isBlocked)
                          const PopupMenuItem(
                            value: 'unblock',
                            child: Text('Unblock User'),
                          )
                        else
                          const PopupMenuItem(
                            value: 'block',
                            child: Text(
                              'Block User',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
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
                      if (user.instagramId.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final Uri url;
                            if (user.instagramId.startsWith('http')) {
                              url = Uri.parse(user.instagramId);
                            } else {
                              url = Uri.parse(
                                'https://instagram.com/${user.instagramId}',
                              );
                            }
                            if (!await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            )) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not launch Instagram'),
                                  ),
                                );
                              }
                            }
                          },
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
                          if (user.major.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user.major,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ),
                          ],
                          if (user.showClassOf && user.classOf.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "'${user.classOf}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
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
                      const SizedBox(height: 16),

                      // (Followers/Following stats and Posts list removed
                      // — viewing another user's profile only exposes
                      // their public identity and Past Joined Meetups.)

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

              // Past Joined Meetups — read-only history (no detail nav).
              SliverToBoxAdapter(
                child: _PastJoinedMeetupsSection(
                  userId: userId,
                  service: firestoreService,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

}

/// Past joined meetups for a user, shown read-only in their public
/// profile. Tapping a row does NOT navigate to the meetup detail —
/// it's just a record. (Currently joined / future meetups are kept
/// private to the user's own profile screen.)
class _PastJoinedMeetupsSection extends StatelessWidget {
  final String userId;
  final FirestoreService service;

  const _PastJoinedMeetupsSection({
    required this.userId,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Meetup>>(
      stream: service.getJoinedMeetups(userId),
      builder: (context, snap) {
        final meetups = snap.data ?? [];
        // Past = either explicitly closed OR start time has elapsed.
        final now = DateTime.now();
        final past = meetups
            .where((m) => m.isClosed || m.dateTime.isBefore(now))
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

        if (past.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Past Joined Meetups',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1F36),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...past.map(
                (m) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        color: Colors.grey[500],
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF1A1F36),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('yyyy-MM-dd').format(m.dateTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
