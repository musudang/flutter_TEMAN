import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/comment_model.dart';
import '../widgets/comment_helpers.dart';
import '../widgets/university_badge.dart';
import 'user_profile_screen.dart';
import 'profile_screen.dart';

class MeetupCommentsSheet extends StatefulWidget {
  final String meetupId;

  const MeetupCommentsSheet({super.key, required this.meetupId});

  @override
  State<MeetupCommentsSheet> createState() => _MeetupCommentsSheetState();
}

class _MeetupCommentsSheetState extends State<MeetupCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isPosting = false;
  bool _isAnonymous = false;

  // Reply context (mirrors main-board comment reply pattern)
  String? _replyToCommentId;
  String? _replyToCommentText;
  String? _replyToCommentAuthor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setReplyTo(Comment c) {
    setState(() {
      _replyToCommentId = c.id;
      _replyToCommentText = c.content;
      _replyToCommentAuthor = c.displayName;
    });
  }

  Future<void> _confirmAndDelete(Comment c) async {
    final confirmed = await showConfirmDeleteCommentDialog(context);
    if (confirmed != true) return;
    try {
      await Provider.of<FirestoreService>(
        context,
        listen: false,
      ).deleteMeetupComment(widget.meetupId, c.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  void _navigateToCommentAuthorProfile(Comment c) {
    // Block navigation for anonymous comments authored by others.
    final myUid = Provider.of<FirestoreService>(context, listen: false)
            .currentUserId ??
        '';
    if (c.isAnonymous && c.authorId != myUid) return;
    if (c.authorId == myUid) {
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

  void _clearReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToCommentText = null;
      _replyToCommentAuthor = null;
    });
  }

  Future<void> _postComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      await Provider.of<FirestoreService>(
        context,
        listen: false,
      ).addMeetupComment(
        widget.meetupId,
        text,
        replyToCommentId: _replyToCommentId,
        replyToCommentText: _replyToCommentText,
        replyToCommentAuthor: _replyToCommentAuthor,
        isAnonymous: _isAnonymous,
      );
      _controller.clear();
      _clearReply();
      if (mounted) {
        FocusScope.of(context).unfocus(); // Hide keyboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Comments',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(),
          // Comments List
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: firestoreService.getMeetupComments(widget.meetupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No comments yet. Be the first!',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                final allComments = snapshot.data!;
                // Group: top-level comments + replies
                final topLevel = allComments
                    .where((c) => c.replyToCommentId == null)
                    .toList();
                final repliesByParent = <String, List<Comment>>{};
                for (final c in allComments) {
                  if (c.replyToCommentId != null) {
                    repliesByParent
                        .putIfAbsent(c.replyToCommentId!, () => [])
                        .add(c);
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final comment in topLevel) ...[
                      _buildCommentTile(comment, isReply: false),
                      for (final reply in repliesByParent[comment.id] ??
                          const <Comment>[])
                        _buildCommentTile(reply, isReply: true),
                    ],
                  ],
                );
              },
            ),
          ),
          // Reply preview (shown above input when user is replying)
          if (_replyToCommentId != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    color: Colors.blue,
                    margin: const EdgeInsets.only(right: 8),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyToCommentAuthor ?? ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
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
          // Input
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 8,
              ),
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
                            ? Colors.blue.withValues(alpha: 0.15)
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
                            color:
                                _isAnonymous ? Colors.blue : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isAnonymous ? 'Anon' : 'Name',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isAnonymous
                                  ? Colors.blue
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
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _replyToCommentId != null
                            ? (_isAnonymous
                                ? 'Reply anonymously...'
                                : 'Write a reply...')
                            : (_isAnonymous
                                ? 'Comment anonymously...'
                                : 'Add a comment...'),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isPosting ? null : _postComment,
                    icon: _isPosting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Comment comment, {required bool isReply}) {
    // Soft-deleted: render placeholder to preserve thread structure.
    if (comment.isDeleted) {
      return DeletedCommentPlaceholder(
        isReply: isReply,
        leftPadding: isReply ? 36 : 0,
      );
    }

    final myUid = Provider.of<FirestoreService>(context, listen: false)
            .currentUserId ??
        '';
    final isMine = comment.authorId == myUid;
    final isAnon = comment.isAnonymous;
    final showAvatarImage =
        !isAnon && comment.authorAvatar.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 36 : 0,
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _navigateToCommentAuthorProfile(comment),
            child: isAnon
                ? CircleAvatar(
                    radius: isReply ? 14 : 18,
                    backgroundColor: Colors.grey[300],
                    child: Icon(
                      Icons.person_off_outlined,
                      color: Colors.grey[600],
                      size: isReply ? 14 : 18,
                    ),
                  )
                : CircleAvatar(
                    radius: isReply ? 14 : 18,
                    backgroundImage: showAvatarImage
                        ? NetworkImage(comment.authorAvatar)
                        : null,
                    backgroundColor: Colors.grey[200],
                    child: !showAvatarImage
                        ? Text(
                            comment.authorName.isNotEmpty
                                ? comment.authorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
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
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _navigateToCommentAuthorProfile(comment),
                        child: Text(
                          comment.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isReply ? 12 : 13,
                            color: isAnon ? Colors.grey[700] : null,
                            fontStyle:
                                isAnon ? FontStyle.italic : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // University badge — visible even when anonymous.
                    if (comment.authorUniversityId != null &&
                        comment.authorUniversityId!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      UniversityBadge(
                        universityId: comment.authorUniversityId!,
                        fontSize: 9,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MM/dd HH:mm').format(comment.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                if (comment.replyToCommentId != null &&
                    comment.replyToCommentText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: const Border(
                          left: BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      child: Text(
                        '↳ ${comment.replyToCommentAuthor ?? ""}: ${comment.replyToCommentText!}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: TextStyle(fontSize: isReply ? 13 : 14),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _setReplyTo(comment),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, right: 12),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (isMine)
                      GestureDetector(
                        onTap: () => _confirmAndDelete(comment),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
