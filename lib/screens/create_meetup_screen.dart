import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/meetup_model.dart';
import '../services/firestore_service.dart';

class CreateMeetupScreen extends StatefulWidget {
  final Meetup? editingMeetup;

  const CreateMeetupScreen({super.key, this.editingMeetup});

  @override
  State<CreateMeetupScreen> createState() => _CreateMeetupScreenState();
}

class _CreateMeetupScreenState extends State<CreateMeetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _imageUrlController = TextEditingController(); // Added for URL input

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  MeetupCategory _selectedCategory = MeetupCategory.other;
  int _maxParticipants = 5;
  bool _requiresApproval = false; // [NEW] Accept/Decline toggle

  // Image Upload State
  Uint8List? _imageBytes;
  bool _isUploadingImage = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final meetup = widget.editingMeetup;
    if (meetup != null) {
      _titleController.text = meetup.title;
      _descriptionController.text = meetup.description;
      _locationController.text = meetup.location;
      _imageUrlController.text = meetup.imageUrl;
      _selectedDate = meetup.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(meetup.dateTime);
      _selectedCategory = meetup.category;
      _maxParticipants = meetup.maxParticipants;
      _requiresApproval = meetup.requiresApproval;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageUrlController.text = '';
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        final user = await firestoreService.getCurrentUser();

        if (user == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not fetch user details'),
              ),
            );
            setState(() => _isSubmitting = false);
          }
          return;
        }

        // Upload image if selected
        if (_imageBytes != null) {
          setState(() => _isUploadingImage = true);
          // Placeholder: simulate upload
          await Future.delayed(const Duration(seconds: 2));
          final url = 'https://example.com/meetup.jpg'; // Placeholder URL
          _imageUrlController.text = url;
          setState(() => _isUploadingImage = false);
        }

        // Use controller URL or fallback default
        final String finalImageUrl = _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : 'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60';

        final dateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        if (widget.editingMeetup != null) {
          await firestoreService.updateMeetup(widget.editingMeetup!.id, {
            'title': _titleController.text,
            'description': _descriptionController.text,
            'location': _locationController.text,
            'dateTime': dateTime.toIso8601String(),
            'category': _selectedCategory.name,
            'maxParticipants': _maxParticipants,
            'requiresApproval': _requiresApproval,
            'imageUrl': finalImageUrl,
          });
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Meetup updated successfully!')),
            );
          }
        } else {
          final newMeetup = Meetup(
            id: const Uuid().v4(),
            title: _titleController.text,
            description: _descriptionController.text,
            location: _locationController.text,
            dateTime: dateTime,
            category: _selectedCategory,
            maxParticipants: _maxParticipants,
            requiresApproval: _requiresApproval,
            host: user,
            participantIds: [user.id],
            imageUrl: finalImageUrl,
            createdAt: DateTime.now(),
          );

          await firestoreService.addMeetup(newMeetup);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Meetup created successfully!')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating meetup: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editingMeetup != null ? 'Edit Meetup' : 'Create Meetup',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Cover Image URL',
                        hintText: 'https://example.com/image.jpg',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.image),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: _isUploadingImage
                        ? const Center(child: CircularProgressIndicator())
                        : IconButton(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add_photo_alternate),
                            color: Colors.teal,
                          ),
                  ),
                ],
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _imageBytes!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _imageBytes = null;
                            _imageUrlController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(_selectedDate),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Category',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: MeetupCategory.values.map((category) {
                  final isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(
                      category.name.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                    selectedColor:
                        Colors.blueAccent, // Use explicit highlight color
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a location'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a description'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _maxParticipants.toString(),
                decoration: const InputDecoration(
                  labelText: 'Max Participants (모집 인원)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                  suffixText: 'people',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final int? val = int.tryParse(value);
                  if (val != null && val >= 2) {
                    setState(() {
                      _maxParticipants = val;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of participants';
                  }
                  final int? val = int.tryParse(value);
                  if (val == null || val < 2) {
                    return 'Minimum 2 participants required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // [NEW] Accept/Decline & Kick toggle
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

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.editingMeetup != null
                              ? 'Update Meetup'
                              : 'Create Meetup',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
