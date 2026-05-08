import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/university_constants.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';
import '../widgets/university_badge.dart';
import 'university_feed_screen.dart';

/// Search screen scoped to a single university board.
///
/// We deliberately bypass Algolia here because university posts live in
/// the `universities/{uniId}/posts` subcollection — that subcollection
/// isn't covered by the top-level `firestore-algolia-search` extension
/// instances, so Algolia would return zero results.
///
/// Instead we stream the latest N posts of the university and run a
/// case-insensitive substring filter on title/content/authorName as
/// the user types. For typical university boards this is plenty fast
/// and avoids needing yet another Algolia extension instance.
class UniversitySearchScreen extends StatefulWidget {
  final University university;

  const UniversitySearchScreen({super.key, required this.university});

  @override
  State<UniversitySearchScreen> createState() => _UniversitySearchScreenState();
}

class _UniversitySearchScreenState extends State<UniversitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // Pull a generous slice of recent posts so client-side filtering
  // covers most realistic search workloads. If a board grows past
  // this, the user can still find recent posts; older posts would
  // need pagination (out of scope for this fix).
  static const int _fetchLimit = 200;

  Color get _uniColor => Color(widget.university.colorValue);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _query) {
        setState(() => _query = q);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Post p, String q) {
    if (q.isEmpty) return false;
    final lower = q.toLowerCase();
    return p.title.toLowerCase().contains(lower) ||
        p.content.toLowerCase().contains(lower) ||
        p.authorName.toLowerCase().contains(lower);
  }

  void _openPost(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UniversityPostDetailSheet(
        post: post,
        uniId: widget.university.id,
        uniColor: _uniColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final color = _uniColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search in ${widget.university.nameEn}...',
            border: InputBorder.none,
            hintStyle: const TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _searchController.clear(),
            ),
        ],
      ),
      body: StreamBuilder<List<Post>>(
        stream: fs.getUniversityPosts(
          widget.university.id,
          limit: _fetchLimit,
        ),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_query.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'Type to search ${widget.university.nameEn} board',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          final results =
              snap.data!.where((p) => _matches(p, _query)).toList();
          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 56,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No matching posts for "$_query"',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = results[i];
              return _SearchResultCard(
                post: p,
                color: color,
                onTap: () => _openPost(p),
              );
            },
          );
        },
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final Post post;
  final Color color;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.post,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color.withValues(alpha: 0.15),
                  backgroundImage:
                      !post.isAnonymous && post.authorAvatar.isNotEmpty
                          ? NetworkImage(post.authorAvatar)
                          : null,
                  child: post.isAnonymous || post.authorAvatar.isEmpty
                      ? Icon(Icons.person, size: 12, color: color)
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    post.isAnonymous ? 'Anonymous' : post.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF1A1F36),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (post.authorUniversityId != null &&
                    post.authorUniversityId!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  UniversityBadge(
                    universityId: post.authorUniversityId!,
                    fontSize: 9,
                  ),
                ],
              ],
            ),
            if (post.title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              post.content,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
