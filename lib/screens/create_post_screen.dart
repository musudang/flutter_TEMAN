import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/meetup_model.dart';
import '../models/marketplace_model.dart';
import '../models/job_model.dart';
import '../models/user_model.dart' as app_models;

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

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
  final _imageUrlController = TextEditingController();

  // Meetup-specific fields
  final _locationController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '5');
  DateTime _meetupDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _meetupTime = TimeOfDay.now();

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
  final _companyNameController = TextEditingController();
  final _salaryController = TextEditingController();
  String _jobType = 'Full-time';
  final List<String> _jobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    _priceController.dispose();
    _companyNameController.dispose();
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

      if (_selectedCategory == 'Meetup') {
        await _submitMeetup(firestoreService, user);
      } else if (_selectedCategory == 'Market') {
        await _submitMarketItem(firestoreService, user);
      } else if (_selectedCategory == 'Job') {
        await _submitJob(firestoreService, user);
      } else {
        // General, Q&A, Event → standard post with correct category
        await firestoreService.addPost(
          _titleController.text.trim(),
          _contentController.text.trim(),
          user.id,
          user.name,
          imageUrl: _imageUrlController.text.trim(),
          category: _firestoreCategory,
        );
      }

      if (mounted) {
        Navigator.pop(context);
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
      category: MeetupCategory.other,
      maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 5,
      host: user,
      participantIds: [user.id],
      imageUrl: _imageUrlController.text.trim(),
    );

    await service.addMeetup(meetup);
  }

  Future<void> _submitMarketItem(
    FirestoreService service,
    app_models.User user,
  ) async {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final item = MarketplaceItem(
      id: '',
      title: _titleController.text.trim(),
      price: price,
      description: _contentController.text.trim(),
      condition: 'New',
      category: _productCategory,
      imageUrls: _imageUrlController.text.trim().isNotEmpty
          ? [_imageUrlController.text.trim()]
          : [],
      sellerId: user.id,
      sellerName: user.name,
      sellerAvatar: user.avatarUrl,
      postedDate: DateTime.now(),
    );
    await service.addMarketplaceItem(item);
  }

  Future<void> _submitJob(
    FirestoreService service,
    app_models.User user,
  ) async {
    final job = Job(
      id: '',
      title: _titleController.text.trim(),
      companyName: _companyNameController.text.trim(),
      location: _locationController.text.trim(),
      salary: _salaryController.text.trim(),
      description: _contentController.text.trim(),
      requirements: [],
      contactInfo: '',
      authorId: user.id,
      postedDate: DateTime.now(),
    );
    await service.addJob(job);
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
        title: const Text(
          'Create',
          style: TextStyle(fontWeight: FontWeight.w700),
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
                  : const Text(
                      'Post',
                      style: TextStyle(
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

              // Image URL (common)
              _buildField(
                controller: _imageUrlController,
                label: 'Image URL (Optional)',
                hint: 'https://example.com/image.jpg',
                icon: Icons.image_outlined,
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
                _buildField(
                  controller: _companyNameController,
                  label: 'Company Name',
                  hint: 'e.g. Samsung Electronics',
                  icon: Icons.business_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
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
