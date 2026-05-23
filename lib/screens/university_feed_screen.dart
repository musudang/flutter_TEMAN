import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/university_constants.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/question_model.dart';
import '../models/user_model.dart' as app_models;
import '../providers/feed_state_provider.dart';
import 'university_create_post_screen.dart';
import 'university_qna_detail_screen.dart';
import '../widgets/university_drawer.dart';
import '../widgets/university_badge.dart';
import '../widgets/comment_helpers.dart';
import 'profile_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_screen.dart';
import 'university_search_screen.dart';
import 'share_content_sheet.dart';
import 'chat_screen.dart';
import '../widgets/report_dialog.dart';

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

                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1A1F36)),
            tooltip: 'Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversitySearchScreen(university: uni),
                ),
              );
            },
          ),
        ],
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
      builder: (_) => UniversityPostDetailSheet(
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

            // Author row — real-time profile lookup for non-anonymous posts
            _LiveAuthorRow(
              authorId: post.authorId,
              isAnonymous: post.isAnonymous,
              fallbackName: post.authorName,
              fallbackAvatar: post.authorAvatar,
              authorUniversityId: post.authorUniversityId,
              uniColor: uniColor,
              avatarRadius: 14,
              fontSize: 13,
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
                  backgroundImage: !question.isAnonymous && question.authorAvatar.isNotEmpty
                      ? NetworkImage(question.authorAvatar)
                      : null,
                  child: question.isAnonymous || question.authorAvatar.isEmpty
                      ? Icon(Icons.person, size: 14, color: uniColor)
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    question.isAnonymous ? 'Anonymous' : question.authorName,
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

class UniversityPostDetailSheet extends StatelessWidget {
  final Post post;
  final String uniId;
  final Color uniColor;

  const UniversityPostDetailSheet({
    super.key,
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
    // Actions row (like/scrap/share/edit/delete) reads its own service —
    // we no longer need a service handle at this scope.
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
                    // Author row — real-time profile
                    _LiveAuthorDetailRow(
                      post: post,
                      uniColor: uniColor,
                      timeAgo: _timeAgo(post.timestamp),
                      uniId: uniId,
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

                    // Actions row: like + scrap + share + 3-dot menu
                    _UniversityPostActionsRow(
                      post: post,
                      uniId: uniId,
                      uniColor: uniColor,
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    // Comments section (with reply + anonymous support)
                    _UniversityCommentsSection(
                      uniId: uniId,
                      postId: post.id,
                      postTitle: post.title.isNotEmpty ? post.title : 'University Post',
                      uniColor: uniColor,
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

// ─────────────────────────────────────────────────────
// University Post Comments — supports nested replies and
// anonymous comments (mirrors main-board behavior).
// ─────────────────────────────────────────────────────

class _UniversityCommentsSection extends StatefulWidget {
  final String uniId;
  final String postId;
  final String postTitle;
  final Color uniColor;

  const _UniversityCommentsSection({
    required this.uniId,
    required this.postId,
    required this.postTitle,
    required this.uniColor,
  });

  @override
  State<_UniversityCommentsSection> createState() =>
      _UniversityCommentsSectionState();
}

class _UniversityCommentsSectionState
    extends State<_UniversityCommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  bool _isAnonymous = false;
  String? _replyToCommentId;
  String? _replyToCommentText;
  String? _replyToCommentAuthor;
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _setReplyTo(Comment c) {
    setState(() {
      _replyToCommentId = c.id;
      _replyToCommentText = c.content;
      _replyToCommentAuthor = c.displayName;
    });
  }

  void _clearReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToCommentText = null;
      _replyToCommentAuthor = null;
    });
  }

  Future<void> _send() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;
    final fs = Provider.of<FirestoreService>(context, listen: false);
    setState(() => _isSending = true);
    try {
      await fs.addUniversityPostComment(
        widget.uniId,
        widget.postId,
        text,
        replyToCommentId: _replyToCommentId,
        replyToCommentText: _replyToCommentText,
        replyToCommentAuthor: _replyToCommentAuthor,
        isAnonymous: _isAnonymous,
      );
      if (!mounted) return;
      _commentController.clear();
      _clearReply();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final uid = fs.currentUserId ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Comments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
        ),
        StreamBuilder<List<Comment>>(
          stream: fs.getUniversityPostComments(widget.uniId, widget.postId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final comments = snap.data!;
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No comments yet. Be the first to comment!',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              );
            }
            // Group: top-level comments + their replies (sorted by time)
            final topLevel =
                comments.where((c) => c.replyToCommentId == null).toList();
            final repliesByParent = <String, List<Comment>>{};
            for (final c in comments) {
              if (c.replyToCommentId != null) {
                repliesByParent
                    .putIfAbsent(c.replyToCommentId!, () => [])
                    .add(c);
              }
            }
            return Column(
              children: [
                for (final c in topLevel) ...[
                  _buildCommentTile(c, isReply: false, uid: uid),
                  for (final reply in repliesByParent[c.id] ?? const <Comment>[])
                    _buildCommentTile(reply, isReply: true, uid: uid),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        // Reply preview
        if (_replyToCommentId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: widget.uniColor, width: 3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to ${_replyToCommentAuthor ?? ""}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.uniColor,
                        ),
                      ),
                      Text(
                        _replyToCommentText ?? '',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _clearReply,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        // Input row
        Row(
          children: [
            // Anonymous toggle
            GestureDetector(
              onTap: () => setState(() => _isAnonymous = !_isAnonymous),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _isAnonymous
                      ? widget.uniColor.withValues(alpha: 0.15)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAnonymous
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 14,
                      color: _isAnonymous
                          ? widget.uniColor
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isAnonymous ? 'Anon' : 'Name',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isAnonymous
                            ? widget.uniColor
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: _isAnonymous
                      ? 'Comment anonymously...'
                      : 'Add a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send, color: widget.uniColor),
              onPressed: _isSending ? null : _send,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCommentTile(
    Comment c, {
    required bool isReply,
    required String uid,
  }) {
    // Soft-deleted: render placeholder so the reply thread structure
    // is preserved.
    if (c.isDeleted) {
      return DeletedCommentPlaceholder(
        isReply: isReply,
        leftPadding: isReply ? 32 : 0,
      );
    }

    // (Service handle moved to _showReactionReplySheet — the tile body
    // itself no longer needs it after switching to long-press UX.)
    final isMine = c.authorId == uid;
    final isAnon = c.isAnonymous;

    void onAuthorTap() {
      if (isAnon && !isMine) {
        // Find post info from the parent widget's context
        _showUniAnonymousDmPrompt(
          context,
          postId: widget.postId,
          postAuthorId: c.authorId,
          postTitle: widget.postTitle,
          uniId: widget.uniId,
          authorAnonIndex: c.anonymousIndex,
        );
        return;
      }
      if (isMine) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: c.authorId),
          ),
        );
      }
    }

    return GestureDetector(
      onLongPress: () => _showReactionReplySheet(c),
      child: Padding(
      padding: EdgeInsets.only(
        left: isReply ? 32 : 0,
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            child: CircleAvatar(
              radius: isReply ? 12 : 16,
              backgroundColor: widget.uniColor.withValues(alpha: 0.15),
              backgroundImage:
                  !c.isAnonymous && c.authorAvatar.isNotEmpty
                      ? NetworkImage(c.authorAvatar)
                      : null,
              child: (c.isAnonymous || c.authorAvatar.isEmpty)
                  ? Icon(Icons.person,
                      size: isReply ? 12 : 16, color: widget.uniColor)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: onAuthorTap,
                        child: Text(
                          c.displayName,
                          style: TextStyle(
                            fontSize: isReply ? 12 : 13,
                            fontWeight: FontWeight.w700,
                            color: isAnon
                                ? Colors.grey[700]
                                : const Color(0xFF1A1F36),
                            fontStyle:
                                isAnon ? FontStyle.italic : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // University badge — keep visible even when anonymous
                    if (c.authorUniversityId != null &&
                        c.authorUniversityId!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      UniversityBadge(
                        universityId: c.authorUniversityId!,
                        fontSize: 8,
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(c.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                if (c.replyToCommentId != null && c.replyToCommentText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border(
                          left: BorderSide(
                            color: widget.uniColor.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        '↳ ${c.replyToCommentAuthor ?? ""}: ${c.replyToCommentText!}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    c.content,
                    style: TextStyle(
                      fontSize: isReply ? 12 : 13,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
                // Reactions row — visible if any users have reacted
                if (c.reactions != null && c.reactions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 4,
                      children: _aggregateReactions(c.reactions!),
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

  /// Aggregate `{userId: emoji}` map into chips like "👍 3"
  /// (matches the main-board comment style).
  List<Widget> _aggregateReactions(Map<String, String> reactions) {
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts.entries.map((e) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${e.key} ${e.value}',
          style: const TextStyle(fontSize: 12),
        ),
      );
    }).toList();
  }

  /// Long-press on a comment opens this bottom sheet so users can react
  /// with an emoji, reply, or delete (own only). Mirrors the main-feed
  /// `post_detail_screen._showReactionReplySheet`.
  void _showReactionReplySheet(Comment comment) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final myUid = fs.currentUserId ?? '';
    final isMine = comment.authorId == myUid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji reactions row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      fs.toggleUniversityCommentReaction(
                        uniId: widget.uniId,
                        postId: widget.postId,
                        commentId: comment.id,
                        emoji: emoji,
                      );
                      Navigator.pop(sheetCtx);
                    },
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _setReplyTo(comment);
                },
              ),
              if (comment.isAnonymous && !isMine)
                ListTile(
                  leading: const Icon(Icons.mail_outline, color: Color(0xFF26A69A)),
                  title: const Text('Send Anonymous Message',
                      style: TextStyle(color: Color(0xFF26A69A))),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showUniAnonymousDmPrompt(
                      context,
                      postId: widget.postId,
                      postAuthorId: comment.authorId,
                      postTitle: widget.postTitle,
                      uniId: widget.uniId,
                      authorAnonIndex: comment.anonymousIndex,
                    );
                  },
                ),
              if (isMine || fs.isAdminCached)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final confirmed =
                        await showConfirmDeleteCommentDialog(context);
                    if (confirmed != true) return;
                    try {
                      await fs.deleteUniversityPostComment(
                        widget.uniId,
                        widget.postId,
                        comment.id,
                      );
                    } catch (e) {
                      if (mounted) {
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
}

// ─────────────────────────────────────────────────────
// University post actions row (mirrors main feed):
//   like · scrap · share + owner-only edit/delete menu
// ─────────────────────────────────────────────────────

class _UniversityPostActionsRow extends StatefulWidget {
  final Post post;
  final String uniId;
  final Color uniColor;

  const _UniversityPostActionsRow({
    required this.post,
    required this.uniId,
    required this.uniColor,
  });

  @override
  State<_UniversityPostActionsRow> createState() => _UniversityPostActionsRowState();
}

class _UniversityPostActionsRowState extends State<_UniversityPostActionsRow> {
  late bool isLiked;
  late bool isScrapped;
  late int likes;
  late int scrapCount;

  @override
  void initState() {
    super.initState();
    final uid = Provider.of<FirestoreService>(context, listen: false).currentUserId ?? '';
    isLiked = widget.post.likedBy.contains(uid);
    isScrapped = widget.post.scrappedBy.contains(uid);
    likes = widget.post.likes;
    scrapCount = widget.post.scrapCount;
  }

  void _toggleLike() {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    setState(() {
      isLiked = !isLiked;
      likes += isLiked ? 1 : -1;
    });
    fs.toggleLikeUniversityPost(widget.uniId, widget.post.id);
  }

  void _toggleScrap() {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    setState(() {
      isScrapped = !isScrapped;
      scrapCount += isScrapped ? 1 : -1;
    });
    fs.toggleScrapUniversityPost(widget.uniId, widget.post.id);
  }

  Future<void> _openShareSheet(BuildContext context) async {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    fs.incrementShareUniversityPost(widget.uniId, widget.post.id); // best-effort
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ShareContentSheet(
        itemId: widget.post.id,
        itemType: 'post',
        itemTitle: widget.post.title.isNotEmpty
            ? widget.post.title
            : 'Post on ${UniversityConstants.getById(widget.uniId)?.nameEn ?? "University"} board',
        itemDescription: widget.post.content,
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Delete Post?'),
          ],
        ),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final fs = Provider.of<FirestoreService>(context, listen: false);
    try {
      await fs.deleteUniversityPost(widget.uniId, widget.post.id);
      if (context.mounted) {
        Navigator.pop(context); // close detail sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  void _openEdit(BuildContext context) {
    Navigator.pop(context); // close detail sheet first
    final uni = UniversityConstants.getById(widget.uniId);
    if (uni == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UniversityCreatePostScreen(
          university: uni,
          editingPost: widget.post,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final uid = fs.currentUserId ?? '';
    final isOwner = widget.post.authorId == uid;

    return Row(
      children: [
        // Like
        GestureDetector(
          onTap: _toggleLike,
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.grey[400],
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                '$likes',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Scrap
        GestureDetector(
          onTap: _toggleScrap,
          child: Icon(
            isScrapped ? Icons.bookmark : Icons.bookmark_border,
            color: isScrapped ? widget.uniColor : Colors.grey[400],
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        // Share
        GestureDetector(
          onTap: () => _openShareSheet(context),
          child: Icon(
            Icons.ios_share,
            color: Colors.grey[400],
            size: 22,
          ),
        ),
        const Spacer(),
        // 3-dot menu — owner/admin sees Edit/Delete
        if (isOwner || fs.isAdminCached)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
            onSelected: (value) async {
              if (value == 'edit') {
                _openEdit(context);
              } else if (value == 'delete') {
                await _confirmAndDelete(context);
              }
            },
            itemBuilder: (_) => [
              if (isOwner)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          )
        else
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
            onSelected: (value) {
              if (value == 'report') {
                showReportUniversityPostDialog(context, widget.uniId, widget.post.id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Report', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// Live author widgets — fetch real-time profile data
// ─────────────────────────────────────────────────────

class _LiveAuthorRow extends StatelessWidget {
  final String authorId;
  final bool isAnonymous;
  final String fallbackName;
  final String fallbackAvatar;
  final String? authorUniversityId;
  final Color uniColor;
  final double avatarRadius;
  final double fontSize;

  const _LiveAuthorRow({
    required this.authorId,
    required this.isAnonymous,
    required this.fallbackName,
    required this.fallbackAvatar,
    required this.authorUniversityId,
    required this.uniColor,
    this.avatarRadius = 14,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    if (isAnonymous) {
      return Row(
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: uniColor.withValues(alpha: 0.15),
            child: Icon(Icons.person, size: avatarRadius, color: uniColor),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Anonymous',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
                color: const Color(0xFF1A1F36),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (authorUniversityId != null && authorUniversityId!.isNotEmpty) ...[
            const SizedBox(width: 6),
            UniversityBadge(universityId: authorUniversityId!, fontSize: 9),
          ],
        ],
      );
    }

    final fs = Provider.of<FirestoreService>(context, listen: false);
    return StreamBuilder<app_models.User?>(
      stream: fs.getUserStream(authorId),
      builder: (context, snap) {
        final name = snap.data?.name ?? fallbackName;
        final avatar = snap.data?.avatarUrl ?? fallbackAvatar;
        return Row(
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: uniColor.withValues(alpha: 0.15),
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? Icon(Icons.person, size: avatarRadius, color: uniColor)
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                  color: const Color(0xFF1A1F36),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (authorUniversityId != null && authorUniversityId!.isNotEmpty) ...[
              const SizedBox(width: 6),
              UniversityBadge(universityId: authorUniversityId!, fontSize: 9),
            ],
          ],
        );
      },
    );
  }
}

class _LiveAuthorDetailRow extends StatelessWidget {
  final Post post;
  final Color uniColor;
  final String timeAgo;
  final String uniId;

  const _LiveAuthorDetailRow({
    required this.post,
    required this.uniColor,
    required this.timeAgo,
    required this.uniId,
  });

  @override
  Widget build(BuildContext context) {
    if (post.isAnonymous) {
      final fs = Provider.of<FirestoreService>(context, listen: false);
      final isMine = post.authorId == (fs.currentUserId ?? '');
      return GestureDetector(
        onTap: isMine
            ? null
            : () => _showUniAnonymousDmPrompt(
                  context,
                  postId: post.id,
                  postAuthorId: post.authorId,
                  postTitle: post.title.isNotEmpty ? post.title : 'Anonymous Post',
                  uniId: uniId,
                ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person_off_outlined, size: 20, color: Colors.grey[600]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Anonymous',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (post.authorUniversityId != null && post.authorUniversityId!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        UniversityBadge(universityId: post.authorUniversityId!),
                      ],
                    ],
                  ),
                  Text(timeAgo, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final fs = Provider.of<FirestoreService>(context, listen: false);
    return StreamBuilder<app_models.User?>(
      stream: fs.getUserStream(post.authorId),
      builder: (context, snap) {
        final name = snap.data?.name ?? post.authorName;
        final avatar = snap.data?.avatarUrl ?? post.authorAvatar;
        return Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: post.authorId),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: uniColor.withValues(alpha: 0.15),
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty
                    ? Icon(Icons.person, size: 20, color: uniColor)
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
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (post.authorUniversityId != null && post.authorUniversityId!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        UniversityBadge(universityId: post.authorUniversityId!),
                      ],
                    ],
                  ),
                  Text(timeAgo, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// Anonymous DM helpers for university posts
// ─────────────────────────────────────────────────────

void _showUniAnonymousDmPrompt(
  BuildContext context, {
  required String postId,
  required String postAuthorId,
  required String postTitle,
  required String uniId,
  int? authorAnonIndex,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person_off_outlined,
                  size: 28, color: Colors.grey[600]),
            ),
            const SizedBox(height: 14),
            Text(
              'Send Anonymous Message',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Both you and the recipient will remain anonymous.\nThe chat room will be named after the post title.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.mail_outline, size: 18),
                label: const Text('Start Anonymous Chat'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF26A69A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _startUniAnonymousDm(
                    context,
                    postId: postId,
                    postAuthorId: postAuthorId,
                    postTitle: postTitle,
                    uniId: uniId,
                    authorAnonIndex: authorAnonIndex,
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _startUniAnonymousDm(
  BuildContext context, {
  required String postId,
  required String postAuthorId,
  required String postTitle,
  required String uniId,
  int? authorAnonIndex,
}) async {
  final fs = Provider.of<FirestoreService>(context, listen: false);
  final uid = fs.currentUserId;
  if (uid == null) return;
  if (uid == postAuthorId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You cannot message yourself')),
    );
    return;
  }

  try {
    final postCollection = 'universities/$uniId/posts';
    final anonIndex = authorAnonIndex ?? 0;

    final existingConvs = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .get();

    int senderIndex = 1;
    for (var doc in existingConvs.docs) {
      final data = doc.data();
      if (data['type'] == 'anonymous_dm' && data['postId'] == postId) {
        if (List<String>.from(data['participantIds'] ?? [])
            .contains(postAuthorId)) {
          final anonIndices = data['anonymousIndices'] != null
              ? Map<String, int>.from(
                  (data['anonymousIndices'] as Map).map(
                    (k, v) => MapEntry(k.toString(), (v as num).toInt()),
                  ),
                )
              : <String, int>{};
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: doc.id,
                  chatTitle: postTitle,
                  isAnonymousDm: true,
                  anonymousIndices: anonIndices,
                ),
              ),
            );
          }
          return;
        }
        senderIndex++;
      }
    }

    final conversationId = await fs.getOrCreateAnonymousConversation(
      postId: postId,
      postAuthorId: postAuthorId,
      postTitle: postTitle,
      postCollection: postCollection,
      senderAnonIndex: senderIndex,
      authorAnonIndex: anonIndex,
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            chatTitle: postTitle,
            isAnonymousDm: true,
            anonymousIndices: {
              uid: senderIndex,
              postAuthorId: anonIndex,
            },
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start conversation: $e')),
      );
    }
  }
}
