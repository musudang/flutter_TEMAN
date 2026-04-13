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
import '../models/marketplace_model.dart';
import '../models/job_model.dart';
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
  bool _isUploadingImage = false;

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
    final pickedFiles = await picker.pickMultiImage();
    
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

  // Category selection
  String _selectedCategory = 'General';
  final List<Map<String, dynamic>> _categories = [
    {'label': 'General', 'icon': Icons.article_outlined, 'color': Colors.teal},
    {'label': 'Q&A', 'icon': Icons.help_outline, 'color': Colors.blue},
    {'label': 'Meetup', 'icon': Icons.people_outline, 'color': Colors.orange},
    {
      'label': 'Market',
      'icon': Icons.storefront_outlined,
      'color': Colors.green,
    },
    {'label': 'Job', 'icon': Icons.work_outline, 'color': Colors.indigo},
    {'label': 'Event', 'icon': Icons.event_outlined, 'color': Colors.purple},
  ];

  // Map UI labels → Firestore category strings
  String get _firestoreCategory {
    switch (_selectedCategory) {
      case 'Q&A':
        return 'qna';
      case 'Meetup':
        return 'meetups';
      case 'Market':
        return 'market';
      case 'Job':
        return 'jobs';
      case 'Event':
        return 'events';
      default:
        return 'general';
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

  // Market-specific fields
  final _priceController = TextEditingController();
  String _productCategory = 'Electronics';
  final List<String> _productCategories = [
    'Electronics',
    'Fashion',
    'Books',
    'Home',
    'Sports',
    'Food',
    'Other',
  ];

  // Job-specific fields
  final _salaryController = TextEditingController();
  String _jobType = 'Full-time';
  final List<String> _jobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
  ];

  // Event-specific fields
  String _eventSubCategory = 'ALL';
  final List<String> _eventSubCategories = [
    'ALL',
    'CONCERT',
    'LOCAL FESTIVAL',
    'ACADEMIC',
    'CAREER',
    'EXPO',
    'EXHIBITION',
    'POP-UP',
    'NETWORKING',
    'OTHERS',
  ];
  DateTime? _eventDate;

  // Q&A-specific fields
  String _qnaSubCategory = 'ALL';
  final List<String> _qnaSubCategories = [
    'ALL',
    'IMMIGRATION',
    'ACADEMICS',
    'HOUSING',
    'JOBS',
    'DAILY LIFE',
    'LANGUAGE',
    'OTHERS',
  ];

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
          case 'qna':
            _selectedCategory = 'Q&A';
            _qnaSubCategory = item.subCategory ?? 'ALL';
            break;
          case 'meetups':
            _selectedCategory = 'Meetup';
            break;
          case 'market':
            _selectedCategory = 'Market';
            break;
          case 'jobs':
            _selectedCategory = 'Job';
            break;
          case 'events':
            _selectedCategory = 'Event';
            _eventSubCategory = item.subCategory ?? 'ALL';
            _eventDate = item.eventDate;
            break;
          default:
            _selectedCategory = 'General';
        }
      } else if (item is Job) {
        _selectedCategory = 'Job';
        _titleController.text = item.title;
        _contentController.text = item.description;
        _locationController.text = item.location;
        _salaryController.text = item.salary;
        _jobType = item.jobType;
        _existingImageUrls = List<String>.from(item.imageUrls);
      } else if (item is MarketplaceItem) {
        _selectedCategory = 'Market';
        _titleController.text = item.title;
        _contentController.text = item.description;
        _priceController.text = item.price.toString();
        _productCategory = item.category;
        _existingImageUrls = List<String>.from(item.imageUrls);
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
    _priceController.dispose();
    _salaryController.dispose();
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
        setState(() => _isUploadingImage = true);
        
        String folder = 'posts';
        if (_selectedCategory == 'Market') {
          folder = 'marketplace';
        } else if (_selectedCategory == 'Meetup') {
          folder = 'meetups';
        } else if (_selectedCategory == 'Q&A') {
          folder = 'questions';
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
        setState(() => _isUploadingImage = false);
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
        } else if (_selectedCategory == 'Market') {
          await _submitMarketItem(firestoreService, user, finalImageUrls);
        } else if (_selectedCategory == 'Job') {
          await _submitJob(firestoreService, user, finalImageUrls);
        } else {
          // General, Q&A, Event → standard post with correct category
          if (widget.editingItem != null && widget.editingItem is Post) {
            await firestoreService.updatePost((widget.editingItem as Post).id, {
              'title': _titleController.text.trim(),
              'content': _contentController.text.trim(),
              'imageUrls': finalImageUrls,
              'category': _firestoreCategory,
              'subCategory': _selectedCategory == 'Event'
                  ? _eventSubCategory
                  : (_selectedCategory == 'Q&A' ? _qnaSubCategory : null),
              'eventDate': _selectedCategory == 'Event' && _eventDate != null
                  ? Timestamp.fromDate(_eventDate!)
                  : null,
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
              subCategory: _selectedCategory == 'Event'
                  ? _eventSubCategory
                  : (_selectedCategory == 'Q&A' ? _qnaSubCategory : null),
              eventDate: _selectedCategory == 'Event' ? _eventDate : null,
              sharedItemId: widget.sharedItemId,
              sharedItemType: widget.sharedItemType,
              sharedItemTitle: widget.sharedItemTitle,
              sharedItemImage: widget.sharedItemImage,
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

  Future<void> _submitMarketItem(
    FirestoreService service,
    app_models.User user,
    List<String> imageUrls,
  ) async {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final item = MarketplaceItem(
      id: '',
      title: _titleController.text.trim(),
      price: price,
      description: _contentController.text.trim(),
      condition: 'New',
      category: _productCategory,
      imageUrls: imageUrls,
      sellerId: user.id,
      sellerName: user.name,
      sellerAvatar: user.avatarUrl,
      postedDate: DateTime.now(),
    );
    if (widget.editingItem != null && widget.editingItem is MarketplaceItem) {
      await service.updateMarketplaceItem((widget.editingItem as MarketplaceItem).id, {
        'title': item.title,
        'price': item.price,
        'description': item.description,
        'condition': item.condition,
        'category': item.category,
        'imageUrls': item.imageUrls,
      });
    } else {
      await service.addMarketplaceItem(item);
    }
  }

  Future<void> _submitJob(
    FirestoreService service,
    app_models.User user,
    List<String> imageUrls,
  ) async {
    final job = Job(
      id: '',
      title: _titleController.text.trim(),
      location: _locationController.text.trim(),
      salary: _salaryController.text.trim(),
      jobType: _jobType,
      description: _contentController.text.trim(),
      imageUrls: imageUrls,
      requirements: [],
      contactInfo: '',
      authorId: user.id,
      postedDate: DateTime.now(),
    );
    if (widget.editingItem != null && widget.editingItem is Job) {
      await service.updateJob((widget.editingItem as Job).id, {
        'title': job.title,
        'location': job.location,
        'salary': job.salary,
        'jobType': job.jobType,
        'description': job.description,
        'imageUrls': job.imageUrls,
      });
    } else {
      await service.addJob(job);
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
                        onTap: () =>
                            setState(() => _selectedCategory = cat['label']),
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

              // Title field (common)
              _buildField(
                controller: _titleController,
                label: _selectedCategory == 'Market'
                    ? 'Item Name'
                    : _selectedCategory == 'Job'
                    ? 'Job Title'
                    : 'Title',
                hint: _selectedCategory == 'Meetup'
                    ? 'e.g. Korean BBQ Night 🍖'
                    : _selectedCategory == 'Market'
                    ? 'e.g. iPhone 15 Pro Max'
                    : _selectedCategory == 'Q&A'
                    ? 'Your question...'
                    : _selectedCategory == 'Job'
                    ? 'e.g. English Teacher Needed'
                    : 'Title',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // Image Selection
              const Text(
                'Images (Max 5)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 8),
              if (_existingImageUrls.isNotEmpty || _imageBytesList.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._existingImageUrls.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final url = entry.value;
                        return Stack(
                          key: ValueKey('existing_$idx'),
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
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
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() => _existingImageUrls.removeAt(idx)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      ..._imageBytesList.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final bytes = entry.value;
                        return Stack(
                          key: ValueKey('new_$idx'),
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
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
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() => _imageBytesList.removeAt(idx)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      if (_existingImageUrls.length + _imageBytesList.length < 5)
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickImages,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.teal.withValues(alpha: 0.3),
                              ),
                            ),
                            child: _isUploadingImage
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.add_photo_alternate_outlined, color: Colors.teal, size: 32),
                          ),
                        ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: _isUploadingImage ? null : _pickImages,
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: _isUploadingImage
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: Colors.teal, size: 32),
                              SizedBox(height: 4),
                              Text('Add Photos', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600)),
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

              // ── Market-specific fields ──
              if (_selectedCategory == 'Market') ...[
                _buildField(
                  controller: _priceController,
                  label: 'Price (KRW)',
                  hint: 'e.g. 50000',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  label: 'Product Category',
                  value: _productCategory,
                  items: _productCategories,
                  onChanged: (v) =>
                      setState(() => _productCategory = v ?? 'Other'),
                ),
                const SizedBox(height: 16),
              ],

              // ── Job-specific fields ──
              if (_selectedCategory == 'Job') ...[
                _buildDropdown(
                  label: 'Job Type',
                  value: _jobType,
                  items: _jobTypes,
                  onChanged: (v) => setState(() => _jobType = v ?? 'Full-time'),
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _salaryController,
                  label: 'Salary / Rate',
                  hint: 'e.g. 3,000,000 KRW/month',
                  icon: Icons.payments_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _locationController,
                  label: 'Location',
                  hint: 'e.g. Seoul, Gangnam',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
              ],

              // ── Q&A-specific fields ──
              if (_selectedCategory == 'Q&A') ...[
                _buildDropdown(
                  label: 'Q&A Category',
                  value: _qnaSubCategory,
                  items: _qnaSubCategories,
                  onChanged: (v) =>
                      setState(() => _qnaSubCategory = v ?? 'ALL'),
                ),
                const SizedBox(height: 16),
              ],

              // ── Event-specific fields ──
              if (_selectedCategory == 'Event') ...[
                _buildDropdown(
                  label: 'Event Category',
                  value: _eventSubCategory,
                  items: _eventSubCategories,
                  onChanged: (v) =>
                      setState(() => _eventSubCategory = v ?? 'ALL'),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _eventDate = picked);
                    }
                  },
                  child: _buildReadonlyField(
                    label: 'Event Date',
                    value: _eventDate != null
                        ? '${_eventDate!.month}/${_eventDate!.day}/${_eventDate!.year}'
                        : 'Select Date',
                    icon: Icons.calendar_today_outlined,
                  ),
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

              // Content field (common)
              const Text(
                'Content',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: _selectedCategory == 'Meetup'
                      ? 'Describe your meetup...'
                      : _selectedCategory == 'Market'
                      ? 'Describe the item condition, details...'
                      : _selectedCategory == 'Job'
                      ? 'Job description, responsibilities...'
                      : "What's on your mind?",
                  hintStyle: TextStyle(color: Colors.grey[400]),
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
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable dropdown builder ──
  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
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
