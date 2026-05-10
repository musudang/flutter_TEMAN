import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/university_constants.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';
import '../widgets/university_badge.dart';
import 'university_feed_screen.dart';
import 'package:rxdart/rxdart.dart';
import '../models/question_model.dart';
import 'university_qna_detail_screen.dart';

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

  bool _matches(dynamic item, String q) {
    if (q.isEmpty) return false;
    final lower = q.toLowerCase();
    if (item is Post) {
      return item.title.toLowerCase().contains(lower) ||
          item.content.toLowerCase().contains(lower) ||
          item.authorName.toLowerCase().contains(lower);
    } else if (item is Question) {
      return item.title.toLowerCase().contains(lower) ||
          item.content.toLowerCase().contains(lower) ||
          item.authorName.toLowerCase().contains(lower);
    }
    return false;
  }

  void _openItem(dynamic item) {
    if (item is Post) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UniversityPostDetailSheet(
          post: item,
          uniId: widget.university.id,
          uniColor: _uniColor,
        ),
      );
    } else if (item is Question) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UniversityQnaDetailScreen(
            question: item,
            uniId: widget.university.id,
            uniColor: _uniColor,
          ),
        ),
      );
    }
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
      body: StreamBuilder<List<dynamic>>(
        stream: Rx.combineLatest2(
          fs.getUniversityPosts(widget.university.id, limit: _fetchLimit),
          fs.getUniversityQuestions(widget.university.id, limit: _fetchLimit),
          (List<Post> posts, List<Question> questions) {
            final List<dynamic> combined = [...posts, ...questions];
            combined.sort((a, b) {
              final aDate = (a is Post) ? a.timestamp : (a as Question).timestamp;
              final bDate = (b is Post) ? b.timestamp : (b as Question).timestamp;
              return bDate.compareTo(aDate);
            });
            return combined;
          },
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
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = results[i];
              return _SearchResultCard(
                item: item,
                color: color,
                onTap: () => _openItem(item),
              );
            },
          );
        },
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final dynamic item;
  final Color color;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.item,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPost = item is Post;
    final post = isPost ? (item as Post) : null;
    final question = !isPost ? (item as Question) : null;

    final title = isPost ? post!.title : question!.title;
    final content = isPost ? post!.content : question!.content;
    final isAnonymous = isPost ? post!.isAnonymous : question!.isAnonymous;
    final authorAvatar = isPost ? post!.authorAvatar : question!.authorAvatar;
    final authorName = isPost ? post!.authorName : question!.authorName;
    final authorUniversityId = isPost ? post!.authorUniversityId : question!.authorUniversityId;
    
    // Determine category
    String categoryLabel = 'General';
    if (isPost && post!.category == 'news') categoryLabel = 'News';
    if (!isPost) categoryLabel = 'Q&A';

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
                      !isAnonymous && authorAvatar.isNotEmpty
                          ? NetworkImage(authorAvatar)
                          : null,
                  child: isAnonymous || authorAvatar.isEmpty
                      ? Icon(Icons.person, size: 12, color: color)
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isAnonymous ? 'Anonymous' : authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF1A1F36),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (authorUniversityId != null &&
                    authorUniversityId.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  UniversityBadge(
                    universityId: authorUniversityId,
                    fontSize: 9,
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    categoryLabel,
                    style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                title,
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
              content,
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
