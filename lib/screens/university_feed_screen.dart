import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/university_constants.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';
import '../models/question_model.dart';
import '../models/user_model.dart' as app_models;
import '../providers/feed_state_provider.dart';
import 'university_create_post_screen.dart';
import 'university_qna_detail_screen.dart';
import '../widgets/university_drawer.dart';
import '../widgets/university_badge.dart';

import 'user_profile_screen.dart';

/// The dedicated feed screen for a single university.
/// Contains 3 tabs: General, News, Q&A.
class UniversityFeedScreen extends StatefulWidget {
  final University university;

  const UniversityFeedScreen({super.key, required this.university});

  @override
  State<UniversityFeedScreen> createState() => _UniversityFeedScreenState();
}

class _UniversityFeedScreenState extends State<UniversityFeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  University get uni => widget.university;
  Color get uniColor => Color(uni.colorValue);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const UniversityDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: const Color(0xFF1A1F36),
          onPressed: () {
            Provider.of<FeedStateProvider>(context, listen: false)
                .setUniversity(null);
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // University badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: uniColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                uni.shortName,
                style: TextStyle(
                  color: uniColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    uni.nameEn,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF1A1F36),
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    uni.nameKo,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: uniColor,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: uniColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'News'),
            Tab(text: 'Q&A'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostListTab(uniId: uni.id, category: 'general', uniColor: uniColor),
          _PostListTab(uniId: uni.id, category: 'news', uniColor: uniColor),
          _QnaListTab(uniId: uni.id, uniColor: uniColor),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'uni_${uni.id}_fab',
        backgroundColor: uniColor,
        elevation: 4,
        onPressed: () {
          final currentTab = _tabController.index;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversityCreatePostScreen(
                university: uni,
                initialCategory: currentTab == 2 ? 'qna' : (currentTab == 1 ? 'news' : 'general'),
              ),
            ),
          );
        },
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Post List Tab (General / News)
// ─────────────────────────────────────────────────────

class _PostListTab extends StatelessWidget {
  final String uniId;
  final String category;
  final Color uniColor;

  const _PostListTab({
    required this.uniId,
    required this.category,
    required this.uniColor,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    return StreamBuilder<app_models.User?>(
      stream: firestoreService.currentUserId != null
          ? firestoreService.getUserStream(firestoreService.currentUserId!)
          : null,
      builder: (context, userSnap) {
        final hiddenUsers = <String>[
          ...(userSnap.data?.blockedUsers ?? []),
          ...(userSnap.data?.blockedBy ?? []),
        ];

        return StreamBuilder<List<Post>>(
          stream: firestoreService.getUniversityPosts(
            uniId,
            category: category,
            hiddenUsers: hiddenUsers,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final posts = snapshot.data ?? [];

            if (posts.isEmpty) {
              return _EmptyState(
                icon: category == 'news'
                    ? Icons.newspaper_rounded
                    : Icons.article_outlined,
                title: category == 'news'
                    ? 'No news yet'
                    : 'No posts yet',
                subtitle: category == 'news'
                    ? 'Share news and events from your university!'
                    : 'Start a conversation with your university community!',
              );
            }

            return RefreshIndicator(
              color: uniColor,
              onRefresh: () async {
                // StreamBuilder auto-refreshes; this is for pull-to-refresh UX
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _UniversityPostCard(
                    post: post,
                    uniColor: uniColor,
                    category: category,
                    onTap: () {
                      // Navigate to post detail – reuse main PostDetailScreen
                      // For now, show a detail dialog since uni posts use different collection
                      _showPostDetail(context, post, uniId, uniColor);
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showPostDetail(
      BuildContext context, Post post, String uniId, Color uniColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UniversityPostDetailSheet(
        post: post,
        uniId: uniId,
        uniColor: uniColor,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Q&A List Tab
// ─────────────────────────────────────────────────────

class _QnaListTab extends StatelessWidget {
  final String uniId;
  final Color uniColor;

  const _QnaListTab({
    required this.uniId,
    required this.uniColor,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    return StreamBuilder<app_models.User?>(
      stream: firestoreService.currentUserId != null
          ? firestoreService.getUserStream(firestoreService.currentUserId!)
          : null,
      builder: (context, userSnap) {
        final hiddenUsers = <String>[
          ...(userSnap.data?.blockedUsers ?? []),
          ...(userSnap.data?.blockedBy ?? []),
        ];

        return StreamBuilder<List<Question>>(
          stream: firestoreService.getUniversityQuestions(
            uniId,
            hiddenUsers: hiddenUsers,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final questions = snapshot.data ?? [];

            if (questions.isEmpty) {
              return const _EmptyState(
                icon: Icons.help_outline_rounded,
                title: 'No questions yet',
                subtitle: 'Ask anything about your university life!',
              );
            }

            return RefreshIndicator(
              color: uniColor,
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final question = questions[index];
                  return _UniversityQuestionCard(
                    question: question,
                    uniColor: uniColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UniversityQnaDetailScreen(
                            uniId: uniId,
                            question: question,
                            uniColor: uniColor,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UniversityPostCard extends StatelessWidget {
  final Post post;
  final Color uniColor;
  final String category;
  final VoidCallback onTap;

  const _UniversityPostCard({
    required this.post,
    required this.uniColor,
    required this.category,
    required this.onTap,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final isNews = category == 'news';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isNews
              ? Border.all(color: uniColor.withValues(alpha: 0.15), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Category badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isNews
                        ? const Color(0xFFFFF3E0)
                        : uniColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isNews ? Icons.newspaper_rounded : Icons.article_outlined,
                        size: 12,
                        color: isNews
                            ? const Color(0xFFEF6C00)
                            : uniColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isNews ? 'NEWS' : 'GENERAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isNews
                              ? const Color(0xFFEF6C00)
                              : uniColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _timeAgo(post.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: uniColor.withValues(alpha: 0.15),
                  backgroundImage: post.authorAvatar.isNotEmpty
                      ? NetworkImage(post.authorAvatar)
                      : null,
                  child: post.authorAvatar.isEmpty
                      ? Icon(Icons.person, size: 14, color: uniColor)
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    post.isAnonymous ? 'Anonymous' : post.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1A1F36),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!post.isAnonymous && post.authorUniversityId != null && post.authorUniversityId!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  UniversityBadge(universityId: post.authorUniversityId!, fontSize: 9),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Title
            if (post.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  post.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1A1F36),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Content
            Text(
              post.content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // Images preview
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrls.first,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 160,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Footer stats
            Row(
              children: [
                Icon(Icons.favorite_border, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  '${post.likes}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline,
                    size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  '${post.comments}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UniversityQuestionCard extends StatelessWidget {
  final Question question;
  final Color uniColor;
  final VoidCallback onTap;

  const _UniversityQuestionCard({
    required this.question,
    required this.uniColor,
    required this.onTap,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline_rounded,
                          size: 12, color: Color(0xFF1565C0)),
                      SizedBox(width: 4),
                      Text(
                        'Q&A',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _timeAgo(question.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Author
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: uniColor.withValues(alpha: 0.15),
                  backgroundImage: question.authorAvatar.isNotEmpty
                      ? NetworkImage(question.authorAvatar)
                      : null,
                  child: question.authorAvatar.isEmpty
                      ? Icon(Icons.person, size: 14, color: uniColor)
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    question.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1A1F36),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (question.authorUniversityId != null && question.authorUniversityId!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  UniversityBadge(universityId: question.authorUniversityId!, fontSize: 9),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              question.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1A1F36),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Content preview
            Text(
              question.content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Answers count
            Row(
              children: [
                Icon(Icons.question_answer_outlined,
                    size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  '${question.answersCount} answers',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Post Detail Bottom Sheet (for university posts)
// ─────────────────────────────────────────────────────

class _UniversityPostDetailSheet extends StatelessWidget {
  final Post post;
  final String uniId;
  final Color uniColor;

  const _UniversityPostDetailSheet({
    required this.post,
    required this.uniId,
    required this.uniColor,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Author row
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (!post.isAnonymous) {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(
                                      userId: post.authorId),
                                ),
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                uniColor.withValues(alpha: 0.15),
                            backgroundImage: post.authorAvatar.isNotEmpty
                                ? NetworkImage(post.authorAvatar)
                                : null,
                            child: post.authorAvatar.isEmpty
                                ? Icon(Icons.person,
                                    size: 20, color: uniColor)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      post.isAnonymous
                                          ? 'Anonymous'
                                          : post.authorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!post.isAnonymous && post.authorUniversityId != null && post.authorUniversityId!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    UniversityBadge(universityId: post.authorUniversityId!),
                                  ],
                                ],
                              ),
                              Text(
                                _timeAgo(post.timestamp),
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
                    const SizedBox(height: 20),

                    // Title
                    if (post.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          post.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: Color(0xFF1A1F36),
                            height: 1.3,
                          ),
                        ),
                      ),

                    // Content
                    Text(
                      post.content,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.6,
                      ),
                    ),

                    // Images
                    if (post.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...post.imageUrls.map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              url,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Like button
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            firestoreService.toggleLikeUniversityPost(
                                uniId, post.id);
                          },
                          child: Row(
                            children: [
                              Icon(
                                post.likedBy.contains(
                                        firestoreService.currentUserId)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: post.likedBy.contains(
                                        firestoreService.currentUserId)
                                    ? Colors.red
                                    : Colors.grey[400],
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${post.likes} likes',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
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
            ],
          ),
        );
      },
    );
  }
}
