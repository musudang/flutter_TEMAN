import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import '../services/firestore_service.dart';
import '../models/meetup_model.dart';

import '../models/user_model.dart' as app_models;
import '../models/post_model.dart';
import '../utils/image_compress_util.dart';

class CreatePostScreen extends StatefulWidget {
  final String? initialPostText;
  final dynamic editingItem;
  final String? sharedItemId;
  final String? sharedItemType;
  final String? sharedItemTitle;
  final String? sharedItemDescription;
  final String? sharedItemImage;

  const CreatePostScreen({
    super.key,
    this.initialPostText,
    this.editingItem,
    this.sharedItemId,
    this.sharedItemType,
    this.sharedItemTitle,
    this.sharedItemDescription,
    this.sharedItemImage,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  final List<Uint8List> _imageBytesList = [];
  List<String> _existingImageUrls = [];
  bool _isAnonymous = false;

  Future<void> _pickImages() async {
    if (_imageBytesList.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 images allowed.')),
        );
      }
      return;
    }

    final picker = ImagePicker();
    // imageQuality < 100 → iOS auto-transcodes HEIC to JPEG before
    // returning bytes (otherwise iPhone HEIC photos won't render on
    // other devices).
    final pickedFiles = await picker.pickMultiImage(imageQuality: 90);
    
    if (pickedFiles.isNotEmpty) {
      if (_existingImageUrls.length + _imageBytesList.length + pickedFiles.length > 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 images allowed globally. Ignored additional images.')),
          );
        }
      }

      
      final toAdd = pickedFiles.take(5 - (_existingImageUrls.length + _imageBytesList.length));
      for (var file in toAdd) {
        final rawBytes = await file.readAsBytes();
        final compressedBytes = await ImageCompressUtil.compressImage(rawBytes);
        _imageBytesList.add(compressedBytes ?? rawBytes);
      }

    }
  }

  // Category selection
  String _selectedCategory = 'General';
  final List<Map<String, dynamic>> _categories = [
    {'label': 'General', 'icon': Icons.article_outlined, 'color': Colors.teal},
    {'label': 'Q&A', 'icon': Icons.help_outline, 'color': Colors.blue},
    {'label': 'Events', 'icon': Icons.event, 'color': Colors.orange},
    {'label': 'Market', 'icon': Icons.storefront, 'color': Colors.green},
    {'label': 'Jobs', 'icon': Icons.work_outline, 'color': Colors.indigo},
    {'label': 'Meetup', 'icon': Icons.people_outline, 'color': Colors.deepOrange},
  ];

  // Map UI labels → Firestore category strings
  String get _firestoreCategory {
    switch (_selectedCategory) {
      case 'Meetup': return 'meetups';
      case 'Q&A': return 'qna';
      case 'Events': return 'events';
      case 'Market': return 'market';
      case 'Jobs': return 'jobs';
      default: return 'general';
    }
  }

  // Common fields
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  // Meetup-specific fields
  final _locationController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '5');
  DateTime _meetupDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _meetupTime = TimeOfDay.now();
  MeetupCategory _meetupCategory = MeetupCategory.other;
  bool _requiresApproval = false;



  @override
  void initState() {
    super.initState();
    if (widget.initialPostText != null) {
      _contentController.text = widget.initialPostText!;
    }
    if (widget.editingItem != null) {
      final item = widget.editingItem;
      if (item is Post) {
        _titleController.text = item.title;
        _contentController.text = item.content;
        _existingImageUrls = List<String>.from(item.imageUrls);
        switch (item.category) {
          case 'meetups':
            _selectedCategory = 'Meetup';
            break;
          default:
            _selectedCategory = 'General';
        }
      } else if (item is Meetup) {
        _selectedCategory = 'Meetup';
        _titleController.text = item.title;
        _contentController.text = item.description;
        _locationController.text = item.location;
        _maxParticipantsController.text = item.maxParticipants.toString();
        _meetupDate = item.dateTime;
        _meetupTime = TimeOfDay.fromDateTime(item.dateTime);
        _meetupCategory = item.category;
        _requiresApproval = item.requiresApproval;
        _existingImageUrls = List<String>.from(item.imageUrls);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();

    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final user = await firestoreService.getCurrentUser();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (user == null || currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: You must be logged in to post'),
            ),
          );
        }
        return;
      }

      // Upload newly selected images
      List<String> uploadedUrls = [];
      if (_imageBytesList.isNotEmpty) {
        
        String folder = 'posts';
        if (_selectedCategory == 'Meetup') {
          folder = 'meetups';
        }

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
      }

      final finalImageUrls = [..._existingImageUrls, ...uploadedUrls];

      if (widget.editingItem != null && widget.editingItem is Post &&
          (widget.editingItem as Post).category == 'general' &&
          _selectedCategory == 'General') {
        await firestoreService.updatePost((widget.editingItem as Post).id, {
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'imageUrls': finalImageUrls,
          'category': _firestoreCategory,
          'subCategory': null,
          'eventDate': null,
        });
      } else {
        if (_selectedCategory == 'Meetup') {
          await _submitMeetup(firestoreService, user, finalImageUrls);
        } else {
          // General post
          if (widget.editingItem != null && widget.editingItem is Post) {
            await firestoreService.updatePost((widget.editingItem as Post).id, {
              'title': _titleController.text.trim(),
              'content': _contentController.text.trim(),
              'imageUrls': finalImageUrls,
              'category': _firestoreCategory,
              'subCategory': null,
              'eventDate': null,
            });
          } else {
            await firestoreService.addPost(
              _titleController.text.trim(),
              _contentController.text.trim(),
              user.id,
              user.name,
              imageUrls: finalImageUrls,
              category: _firestoreCategory,
              authorAvatar: user.avatarUrl,
              subCategory: null,
              eventDate: null,
              sharedItemId: widget.sharedItemId,
              sharedItemType: widget.sharedItemType,
              sharedItemTitle: widget.sharedItemTitle,
              sharedItemImage: widget.sharedItemImage,
              isAnonymous: _isAnonymous,
            );
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_selectedCategory created successfully!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitMeetup(
    FirestoreService service,
    app_models.User user,
    List<String> imageUrls,
  ) async {
    final meetupDateTime = DateTime(
      _meetupDate.year,
      _meetupDate.month,
      _meetupDate.day,
      _meetupTime.hour,
      _meetupTime.minute,
    );

    final meetup = Meetup(
      id: '',
      title: _titleController.text.trim(),
      description: _contentController.text.trim(),
      location: _locationController.text.trim(),
      dateTime: meetupDateTime,
      category: _meetupCategory,
      requiresApproval: _requiresApproval,
      maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 5,
      host: user,
      participantIds: [user.id],
      imageUrls: imageUrls,
      createdAt: DateTime.now(),
    );

    if (widget.editingItem != null && widget.editingItem is Meetup) {
      await service.updateMeetup((widget.editingItem as Meetup).id, {
        'title': meetup.title,
        'description': meetup.description,
        'location': meetup.location,
        'dateTime': Timestamp.fromDate(meetup.dateTime),
        'category': meetup.category.toString().split('.').last,
        'requiresApproval': meetup.requiresApproval,
        'maxParticipants': meetup.maxParticipants,
        'imageUrls': meetup.imageUrls,
      });
    } else {
      await service.addMeetup(meetup);
    }
  }


  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetupDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _meetupDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _meetupTime,
    );
    if (picked != null) setState(() => _meetupTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.editingItem != null ? 'Edit Post' : 'Create',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1F36),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submitPost,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.editingItem != null ? 'Update' : 'Post',
                      style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Selector
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat['label'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategory = cat['label'];
                          // Reset anonymous toggle for non-eligible categories
                          if (_selectedCategory == 'Meetup') {
                            _isAnonymous = false;
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (cat['color'] as Color).withValues(
                                    alpha: 0.15,
                                  )
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? cat['color'] as Color
                                  : Colors.grey[200]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                cat['icon'] as IconData,
                                size: 18,
                                color: isSelected
                                    ? cat['color'] as Color
                                    : Colors.grey[500],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat['label'] as String,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? cat['color'] as Color
                                      : Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
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
                  hintText: _selectedCategory == 'Meetup'
                      ? 'e.g. Korean BBQ Night 🍖'
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

              const SizedBox(height: 16),

              // Images
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
                                onTap: () => setState(() => _existingImageUrls.removeAt(idx)),
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
                                onTap: () => setState(() => _imageBytesList.removeAt(idx)),
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

              const SizedBox(height: 16),

              // ── Meetup-specific fields ──
              if (_selectedCategory == 'Meetup') ...[
                _buildField(
                  controller: _locationController,
                  label: 'Location',
                  hint: 'e.g. Gangnam Station Exit 3',
                  icon: Icons.location_on_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _maxParticipantsController,
                  label: 'Max Participants',
                  hint: '5',
                  icon: Icons.group_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 2) return 'At least 2';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: _buildReadonlyField(
                          label: 'Date',
                          value:
                              '${_meetupDate.month}/${_meetupDate.day}/${_meetupDate.year}',
                          icon: Icons.calendar_today_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: _buildReadonlyField(
                          label: 'Time',
                          value: _meetupTime.format(context),
                          icon: Icons.access_time_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Meetup Category',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: MeetupCategory.values.map((category) {
                    final isSelected = _meetupCategory == category;
                    return ChoiceChip(
                      label: Text(
                        category.name.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _meetupCategory = category);
                        }
                      },
                      selectedColor: const Color(0xFFFF5A5F),
                      backgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFFF5A5F)
                              : Colors.transparent,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Participant Management (Approval & Kick)'),
                  subtitle: const Text(
                    'Requires approval to join. The host can also kick existing participants.',
                  ),
                  value: _requiresApproval,
                  onChanged: (bool value) {
                    setState(() {
                      _requiresApproval = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],



              // ── Quote Post Preview ──
              if (widget.sharedItemId != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      if (widget.sharedItemImage != null && widget.sharedItemImage!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.sharedItemImage!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.article, color: Colors.grey),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shared ${widget.sharedItemType ?? 'Item'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.sharedItemTitle ?? 'Untitled',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Anonymous posting toggle (available for all boards except Meetup) ──
              if (_selectedCategory != 'Meetup') ...[
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
                  activeThumbColor: Colors.teal,
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200]),
              ],

              // Content field (common)
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
                  hintText: _selectedCategory == 'Meetup'
                      ? 'Describe your meetup in detail...'
                      : "What's on your mind?",
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
      ),
    );
  }


  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.grey[500], size: 20)
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.teal, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadonlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
