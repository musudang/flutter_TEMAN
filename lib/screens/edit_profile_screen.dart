import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import '../models/user_model.dart' as app_models;

class EditProfileScreen extends StatefulWidget {
  final app_models.User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _nationalityController;
  late TextEditingController _ageController;
  late TextEditingController _personalInfoController;
  late TextEditingController _avatarUrlController;
  late TextEditingController _instagramController;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio);
    _nationalityController = TextEditingController(
      text: widget.user.nationality,
    );
    _ageController = TextEditingController(
      text: widget.user.age?.toString() ?? '',
    );
    _personalInfoController = TextEditingController(
      text: widget.user.personalInfo,
    );
    _avatarUrlController = TextEditingController(text: widget.user.avatarUrl);
    _instagramController = TextEditingController(text: widget.user.instagramId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _nationalityController.dispose();
    _ageController.dispose();
    _personalInfoController.dispose();
    _avatarUrlController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 50,
      );
      if (picked == null) return;

      if (!mounted) return;

      setState(() {
        _isUploadingPhoto = true;
        _uploadError = null;
      });

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');

      UploadTask uploadTask;

      // Use putData for all platforms (Web, Windows, Mobile) for better cross-platform compatibility
      final bytes = await picked.readAsBytes();
      debugPrint(
        'Pick image: ${picked.path}, Mime: ${picked.mimeType}, Bytes: ${bytes.length}',
      );

      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: picked.mimeType ?? 'image/jpeg'),
      );

      // Wait for upload to fully complete before getting URL
      // Add timeout to prevent infinite loading
      // Wait for the upload to complete or timeout after 30 seconds
      await uploadTask
          .whenComplete(() {})
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              if (uploadTask.snapshot.state == TaskState.running) {
                uploadTask.cancel();
              }
              throw TimeoutException(
                'Upload timed out. Please check your internet connection and try again.',
              );
            },
          );

      final url = await ref.getDownloadURL();

      debugPrint('Upload successful. Download URL: $url');

      if (mounted) {
        setState(() {
          _avatarUrlController.text = url;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo uploaded!')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        String errorMessage = 'Upload failed: ${e.message}';
        if (e.code == 'unauthorized') {
          errorMessage = 'Permission denied. Check Firebase Storage Rules.';
          debugPrint('Upload Error: Permission denied. User: $uid');
        } else if (e.code == 'retry-limit-exceeded') {
          errorMessage = 'Upload timed out. Check connection.';
          debugPrint('Upload Error: Timeout');
        } else {
          debugPrint('Upload Error: ${e.code} - ${e.message}');
          errorMessage += '\nCode: ${e.code}\nMessage: ${e.message}';
        }

        setState(() {
          _isUploadingPhoto = false;
          _uploadError = errorMessage;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Error: ${e.code}'),
                    content: Text(e.message ?? 'Unknown error'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = Provider.of<FirestoreService>(context, listen: false);
      await service.updateUserProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        nationality: _nationalityController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        personalInfo: _personalInfoController.text.trim(),
        instagramId: _instagramController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1F36),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.teal[50],
                    backgroundImage: _avatarUrlController.text.trim().isNotEmpty
                        ? NetworkImage(_avatarUrlController.text.trim())
                        : null,
                    onBackgroundImageError:
                        _avatarUrlController.text.trim().isNotEmpty
                        ? (exception, stackTrace) {
                            debugPrint('Image load error: $exception');
                          }
                        : null,
                    child:
                        _avatarUrlController.text.trim().isEmpty ||
                            !_avatarUrlController.text.trim().startsWith('http')
                        ? Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: _isUploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: Text(
                    _uploadError!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _buildLabel('Profile Image URL'),
            const SizedBox(height: 8),
            _buildTextField(
              _avatarUrlController,
              'Paste image URL or upload above',
            ),
            const SizedBox(height: 24),

            _buildLabel('Display Name'),
            const SizedBox(height: 8),
            _buildTextField(_nameController, 'Your name'),

            const SizedBox(height: 24),
            _buildLabel('Bio'),
            const SizedBox(height: 8),
            _buildTextField(
              _bioController,
              'Tell us about yourself...',
              maxLines: 3,
            ),

            const SizedBox(height: 24),
            _buildLabel('Nationality'),
            const SizedBox(height: 8),
            _buildTextField(_nationalityController, 'e.g. KR 🇰🇷'),

            const SizedBox(height: 24),
            _buildLabel('Age'),
            const SizedBox(height: 8),
            _buildTextField(
              _ageController,
              'e.g. 25',
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),
            _buildLabel('About Me'),
            const SizedBox(height: 8),
            _buildTextField(
              _personalInfoController,
              'Hobbies, interests, what you do...',
              maxLines: 3,
            ),

            const SizedBox(height: 24),
            _buildLabel('Instagram ID / Link'),
            const SizedBox(height: 8),
            _buildTextField(
              _instagramController,
              'e.g. username or https://instagram.com/...',
            ),

            const SizedBox(height: 24),
            _buildLabel('Avatar URL (or use camera button above)'),
            const SizedBox(height: 8),
            _buildTextField(
              _avatarUrlController,
              'https://example.com/photo.jpg',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF4B5563),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
