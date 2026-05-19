import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/question_model.dart';
import '../widgets/university_badge.dart';
import '../widgets/comment_helpers.dart';
import 'user_profile_screen.dart';
import 'profile_screen.dart';
import '../widgets/report_dialog.dart';

/// Detail screen for a university Q&A question.
/// Shows the question, answers, and an input to add new answers.
class UniversityQnaDetailScreen extends StatefulWidget {
  final String uniId;
  final Question question;
  final Color uniColor;

  const UniversityQnaDetailScreen({
    super.key,
    required this.uniId,
    required this.question,
    required this.uniColor,
  });

  @override
  State<UniversityQnaDetailScreen> createState() =>
      _UniversityQnaDetailScreenState();
}

class _UniversityQnaDetailScreenState extends State<UniversityQnaDetailScreen> {
  final _answerController = TextEditingController();
  bool _isSubmitting = false;
  bool _isAnonymous = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final content = _answerController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.addUniversityAnswer(
        widget.uniId,
        widget.question.id,
        content,
        isAnonymous: _isAnonymous,
      );
      _answerController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting answer: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
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
            Text('Delete Question?'),
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
      await fs.deleteUniversityQuestion(widget.uniId, widget.question.id);
      if (context.mounted) {
        Navigator.pop(context); // go back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted')),
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

  @override
  Widget build(BuildContext context) {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    final q = widget.question;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: Color(0xFF1A1F36)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Question',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1F36),
          ),
        ),
        actions: [
          if (firestoreService.currentUserId == q.authorId || firestoreService.isAdminCached)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              onSelected: (value) async {
                if (value == 'delete') {
                  await _confirmAndDelete(context);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              onSelected: (value) {
                if (value == 'report') {
                  showReportUniversityQuestionDialog(context, widget.uniId, q.id);
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
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Question card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Q&A badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
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
                      const SizedBox(height: 14),

                      // Author
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserProfileScreen(userId: q.authorId),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  widget.uniColor.withValues(alpha: 0.15),
                              backgroundImage: q.authorAvatar.isNotEmpty
                                  ? NetworkImage(q.authorAvatar)
                                  : null,
                              child: q.authorAvatar.isEmpty
                                  ? Icon(Icons.person,
                                      size: 18, color: widget.uniColor)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          q.authorName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (q.authorUniversityId != null && q.authorUniversityId!.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        UniversityBadge(universityId: q.authorUniversityId!),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    _timeAgo(q.timestamp),
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
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        q.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Color(0xFF1A1F36),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Content
                      Text(
                        q.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Answers header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Answers',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                ),

                // Answers list
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: firestoreService.getUniversityAnswers(
                      widget.uniId, q.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ));
                    }

                    final answers = snapshot.data ?? [];

                    if (answers.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.question_answer_outlined,
                                size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text(
                              'No answers yet. Be the first to help!',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    final myUid = firestoreService.currentUserId ?? '';
                    return Column(
                      children: answers.map((answer) {
                        final timestamp =
                            answer['timestamp']?.toDate() ?? DateTime.now();
                        final isAnon =
                            answer['isAnonymous'] == true;
                        final aIdx = answer['anonymousIndex'] as int?;
                        final displayName = isAnon
                            ? (aIdx != null
                                ? 'Anonymous $aIdx'
                                : 'Anonymous')
                            : (answer['authorName'] ?? 'Unknown');
                        final isMine = answer['authorId'] == myUid;
                        final answerId = answer['id'] as String? ?? '';

                        void onAuthorTap() {
                          if (isAnon && !isMine) return;
                          if (isMine) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          } else {
                            final aId = answer['authorId'] as String? ?? '';
                            if (aId.isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserProfileScreen(userId: aId),
                              ),
                            );
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
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
                                  GestureDetector(
                                    onTap: onAuthorTap,
                                    child: isAnon
                                        ? CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Colors.grey[300],
                                            child: Icon(
                                              Icons.person_off_outlined,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                          )
                                        : CircleAvatar(
                                            radius: 14,
                                            backgroundColor: widget.uniColor
                                                .withValues(alpha: 0.15),
                                            backgroundImage:
                                                (answer['authorAvatar'] ?? '')
                                                        .isNotEmpty
                                                    ? NetworkImage(
                                                        answer['authorAvatar'])
                                                    : null,
                                            child: (answer['authorAvatar'] ??
                                                        '')
                                                    .isEmpty
                                                ? Icon(Icons.person,
                                                    size: 14,
                                                    color: widget.uniColor)
                                                : null,
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: GestureDetector(
                                      onTap: onAuthorTap,
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isAnon
                                              ? Colors.grey[700]
                                              : null,
                                          fontStyle: isAnon
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if ((answer['authorUniversityId'] ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    UniversityBadge(
                                      universityId:
                                          answer['authorUniversityId'],
                                      fontSize: 9,
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    _timeAgo(timestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                answer['content'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                              ),
                              if ((isMine || firestoreService.isAdminCached) && answerId.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: GestureDetector(
                                    onTap: () async {
                                      final confirmed =
                                          await showConfirmDeleteCommentDialog(
                                              context);
                                      if (confirmed != true) return;
                                      try {
                                        await firestoreService
                                            .deleteUniversityAnswer(
                                          widget.uniId,
                                          widget.question.id,
                                          answerId,
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Failed to delete: $e')));
                                      }
                                    },
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red[400],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          // Answer input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Anonymous toggle
                  GestureDetector(
                    onTap: () =>
                        setState(() => _isAnonymous = !_isAnonymous),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isAnonymous
                            ? widget.uniColor.withValues(alpha: 0.15)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _answerController,
                      decoration: InputDecoration(
                        hintText: _isAnonymous
                            ? 'Answer anonymously...'
                            : 'Write an answer...',
                        hintStyle:
                            TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              BorderSide(color: widget.uniColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: widget.uniColor,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _isSubmitting ? null : _submitAnswer,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
