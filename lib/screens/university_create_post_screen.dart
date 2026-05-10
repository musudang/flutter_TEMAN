import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/university_constants.dart';
import '../models/post_model.dart';
import '../services/firestore_service.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../utils/image_compress_util.dart';
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

  final List<Uint8List> _imageBytesList = [];
  List<String> _existingImageUrls = [];
  bool _isUploadingImage = false;

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
      _existingImageUrls = List<String>.from(editing.imageUrls);
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

  Future<void> _pickImages() async {
    if (_imageBytesList.length + _existingImageUrls.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 images allowed.')),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 90);
    
    if (pickedFiles.isNotEmpty) {
      if (_existingImageUrls.length + _imageBytesList.length + pickedFiles.length > 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 images allowed globally. Ignored additional images.')),
          );
        }
      }

      setState(() => _isUploadingImage = true);
      
      final toAdd = pickedFiles.take(5 - (_existingImageUrls.length + _imageBytesList.length));
      for (var file in toAdd) {
        final rawBytes = await file.readAsBytes();
        final compressedBytes = await ImageCompressUtil.compressImage(rawBytes);
        _imageBytesList.add(compressedBytes ?? rawBytes);
      }

      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _imageBytesList.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
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

      // Upload newly selected images
      List<String> uploadedUrls = [];
      if (_imageBytesList.isNotEmpty) {
        setState(() => _isUploadingImage = true);
        String folder = 'university_posts/${widget.university.id}';
        
        for (var bytes in _imageBytesList) {
          final ref = FirebaseStorage.instance
              .ref()
              .child(folder)
              .child('${const Uuid().v4()}.jpg');

          final uploadTask = ref.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          await uploadTask;
          final url = await ref.getDownloadURL();
          uploadedUrls.add(url);
        }
        setState(() => _isUploadingImage = false);
      }

      final finalImageUrls = [..._existingImageUrls, ...uploadedUrls];

      if (_isEditing) {
        // Edit path — only General/News posts are editable here.
        // (Q&A questions don't currently expose an edit flow.)
        await firestoreService.updateUniversityPost(
          widget.university.id,
          widget.editingPost!.id,
          title: title,
          content: content,
          imageUrls: finalImageUrls,
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
          imageUrls: finalImageUrls,
          isAnonymous: _isAnonymous,
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
          imageUrls: finalImageUrls,
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
              child: _isSubmitting || _isUploadingImage
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
            // 1. Title
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1F36),
              ),
              decoration: InputDecoration(
                hintText: 'Title',
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

            const SizedBox(height: 16),

            // 2. Images
            if (_existingImageUrls.isNotEmpty || _imageBytesList.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._existingImageUrls.asMap().entries.map((entry) {
                      int idx = entry.key;
                      String url = entry.value;
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(url),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(idx),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    ..._imageBytesList.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Uint8List bytes = entry.value;
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: MemoryImage(bytes),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => _removeNewImage(idx),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

            GestureDetector(
              onTap: _pickImages,
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined,
                        color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add Images (${_existingImageUrls.length + _imageBytesList.length}/5)',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Post anonymous
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
            const SizedBox(height: 16),
            Divider(color: Colors.grey[200]),

            // 4. Content
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
                hintText: "What's on your mind?",
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[350],
                ),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
