import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/university_constants.dart';
import '../models/post_model.dart';
import '../services/firestore_service.dart';

/// Screen for creating a post in a university board.
/// Supports General, News, and Q&A categories.
class UniversityCreatePostScreen extends StatefulWidget {
  final University university;
  final String initialCategory; // 'general', 'news', or 'qna'

  /// When non-null, the screen runs in EDIT mode and pre-fills with the
  /// given post. Title, content and the anonymous flag are editable;
  /// category is locked because re-categorizing changes feed visibility.
  final Post? editingPost;

  const UniversityCreatePostScreen({
    super.key,
    required this.university,
    this.initialCategory = 'general',
    this.editingPost,
  });

  @override
  State<UniversityCreatePostScreen> createState() =>
      _UniversityCreatePostScreenState();
}

class _UniversityCreatePostScreenState
    extends State<UniversityCreatePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late String _selectedCategory;
  bool _isAnonymous = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.editingPost != null;

  Color get uniColor => Color(widget.university.colorValue);

  @override
  void initState() {
    super.initState();
    final editing = widget.editingPost;
    if (editing != null) {
      _titleController.text = editing.title;
      _contentController.text = editing.content;
      _selectedCategory = editing.category;
      _isAnonymous = editing.isAnonymous;
    } else {
      _selectedCategory = widget.initialCategory;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      final user = await firestoreService.getCurrentUser();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: You must be logged in')),
          );
        }
        return;
      }

      if (_isEditing) {
        // Edit path — only General/News posts are editable here.
        // (Q&A questions don't currently expose an edit flow.)
        await firestoreService.updateUniversityPost(
          widget.university.id,
          widget.editingPost!.id,
          title: title,
          content: content,
          isAnonymous: _isAnonymous,
        );
      } else if (_selectedCategory == 'qna') {
        // Create a Q&A question
        await firestoreService.addUniversityQuestion(
          widget.university.id,
          title: title,
          content: content,
          authorId: user.id,
          authorName: user.name,
          authorAvatar: user.avatarUrl,
        );
      } else {
        // Create a General or News post
        await firestoreService.addUniversityPost(
          widget.university.id,
          title: title,
          content: content,
          authorId: user.id,
          authorName: user.name,
          authorAvatar: user.avatarUrl,
          category: _selectedCategory,
          isAnonymous: _isAnonymous,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Post updated successfully!'
                  : (_selectedCategory == 'qna'
                      ? 'Question posted successfully!'
                      : 'Post created successfully!'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _titleController.text.trim().isNotEmpty &&
        _contentController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1F36)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: uniColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.university.shortName,
                style: TextStyle(
                  color: uniColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'New Post',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1A1F36),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSubmitting || !isValid ? null : _submit,
              style: TextButton.styleFrom(
                backgroundColor:
                    isValid ? uniColor : Colors.grey[200],
                foregroundColor: isValid ? Colors.white : Colors.grey[400],
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Post',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category selector
            const Text(
              'Board',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1A1F36),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildCategoryChip('general', 'General', Icons.article_outlined),
                const SizedBox(width: 8),
                _buildCategoryChip(
                    'news', 'News', Icons.newspaper_rounded),
                const SizedBox(width: 8),
                _buildCategoryChip('qna', 'Q&A', Icons.help_outline_rounded),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1F36),
              ),
              decoration: InputDecoration(
                hintText: _selectedCategory == 'qna'
                    ? 'What is your question?'
                    : _selectedCategory == 'news'
                        ? 'News headline'
                        : 'Title',
                hintStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[350],
                ),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
            Divider(color: Colors.grey[200]),

            // Content
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 8,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: _selectedCategory == 'qna'
                    ? 'Describe your question in detail...'
                    : _selectedCategory == 'news'
                        ? 'Share the news details...'
                        : "What's on your mind?",
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[350],
                ),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Anonymous toggle (only for general, not Q&A)
            if (_selectedCategory != 'qna')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Post anonymously',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                subtitle: Text(
                  'Your name will be hidden',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                value: _isAnonymous,
                onChanged: (val) => setState(() => _isAnonymous = val),
                activeThumbColor: uniColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String value, String label, IconData icon) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? uniColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? uniColor : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
