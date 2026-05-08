import 'package:flutter/material.dart';

/// Shared helpers used by every comment system in the app
/// (main posts, meetups, university posts, Q&A answers) so the UX
/// stays consistent.

/// Confirmation dialog shown before any comment delete action.
/// Returns `true` if the user confirms.
Future<bool?> showConfirmDeleteCommentDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.delete_outline, color: Colors.red, size: 24),
          SizedBox(width: 8),
          Text('Delete Comment?'),
        ],
      ),
      content: const Text(
        'This action cannot be undone.\n\n'
        'If your comment has replies, it will be marked as deleted '
        'and the replies will remain visible.',
      ),
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
}

/// Placeholder rendered in place of a soft-deleted comment so the
/// reply thread structure remains intact. All comment systems should
/// short-circuit to this when `comment.isDeleted == true`.
class DeletedCommentPlaceholder extends StatelessWidget {
  /// True if this placeholder is rendered as a nested reply (smaller
  /// avatar + extra left padding to match indentation of normal replies).
  final bool isReply;

  /// Extra left padding to match the normal comment item layout. Each
  /// comment system uses a slightly different indent — pass it in to
  /// keep alignment consistent.
  final double leftPadding;

  const DeletedCommentPlaceholder({
    super.key,
    this.isReply = false,
    this.leftPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: leftPadding,
        right: 16,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isReply ? 12 : 16,
            backgroundColor: Colors.grey[200],
            child: Icon(
              Icons.do_not_disturb_alt,
              color: Colors.grey[500],
              size: isReply ? 12 : 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This comment was deleted',
              style: TextStyle(
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
                fontSize: isReply ? 12 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
