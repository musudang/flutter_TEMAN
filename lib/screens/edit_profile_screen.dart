import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart' as app_models;
import '../widgets/interest_selection_sheet.dart';

class EditProfileScreen extends StatefulWidget {
  final app_models.User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _nationalityController;
  late TextEditingController _ageController;
  late TextEditingController _avatarUrlController;
  late TextEditingController _instagramController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late List<String> _selectedInterests;

  // 비밀번호 변경
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _showCurrentPw = false;
  bool _showNewPw = false;
  bool _showConfirmPw = false;

  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _nicknameController = TextEditingController(text: widget.user.nickname);
    _bioController = TextEditingController(text: widget.user.bio);
    _nationalityController = TextEditingController(
      text: widget.user.nationality,
    );
    _ageController = TextEditingController(
      text: widget.user.age?.toString() ?? '',
    );
    _avatarUrlController = TextEditingController(text: widget.user.avatarUrl);
    _instagramController = TextEditingController(text: widget.user.instagramId);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _emailController = TextEditingController(text: widget.user.email);
    _selectedInterests = List<String>.from(widget.user.interests);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _nationalityController.dispose();
    _ageController.dispose();
    _avatarUrlController.dispose();
    _instagramController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
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
          .child('profiles')
          .child(uid)
          .child('profile_pic.jpg');

      final bytes = await picked.readAsBytes();
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: picked.mimeType ?? 'image/jpeg'),
      );

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
        setState(() {
          _isUploadingPhoto = false;
          _uploadError = 'Upload failed: ${e.message}';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
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
        nickname: _nicknameController.text.trim(),
        bio: _bioController.text.trim(),
        nationality: _nationalityController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        personalInfo: '',
        instagramId: _instagramController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        interests: _selectedInterests,
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

  void _openInterestSheet() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          InterestSelectionSheet(initialInterests: _selectedInterests),
    );
    if (result != null) {
      setState(() => _selectedInterests = result);
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
            // ── 프로필 사진 ──
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.teal[50],
                    backgroundImage:
                        _avatarUrlController.text.trim().isNotEmpty &&
                            _avatarUrlController.text.trim().startsWith('http')
                        ? NetworkImage(_avatarUrlController.text.trim())
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
            const SizedBox(height: 32),

            // ── Public Info Section ──
            _buildSectionHeader(
              Icons.public,
              'Public Info',
              'Visible to other users',
            ),
            const SizedBox(height: 16),

            _buildLabel('Display Name *'),
            const SizedBox(height: 8),
            _buildTextField(_nameController, 'Your name'),

            const SizedBox(height: 20),
            _buildLabel('Nickname'),
            const SizedBox(height: 8),
            _buildTextField(_nicknameController, 'e.g. cooluser123'),

            const SizedBox(height: 20),
            _buildLabel('Nationality'),
            const SizedBox(height: 8),
            _buildTextField(_nationalityController, 'e.g. KR 🇰🇷'),

            const SizedBox(height: 20),
            _buildLabel('Age'),
            const SizedBox(height: 8),
            _buildTextField(
              _ageController,
              'e.g. 25',
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),
            _buildLabel('Bio'),
            const SizedBox(height: 8),
            _buildTextField(
              _bioController,
              'Tell us about yourself...',
              maxLines: 3,
            ),

            const SizedBox(height: 20),
            _buildLabel('Instagram ID / Link'),
            const SizedBox(height: 8),
            _buildTextField(
              _instagramController,
              'e.g. username or https://instagram.com/...',
            ),

            const SizedBox(height: 20),
            _buildLabel('Interests'),
            const SizedBox(height: 8),
            _buildInterestsSelector(),

            const SizedBox(height: 32),

            // ── Private Info Section ──
            _buildSectionHeader(
              Icons.lock_outline,
              'Private Info',
              'Only visible to you',
            ),
            const SizedBox(height: 16),

            _buildLabel('Email'),
            const SizedBox(height: 8),
            _buildTextField(
              _emailController,
              'your@email.com',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 20),
            _buildLabel('Phone Number'),
            const SizedBox(height: 8),
            _buildTextField(
              _phoneController,
              '+82 10-0000-0000',
              keyboardType: TextInputType.phone,
            ),

            // ── 비밀번호 변경 섹션 (이메일 로그인 사용자만) ──
            if (Provider.of<AuthService>(
              context,
              listen: false,
            ).isEmailPasswordUser)
              ..._buildPasswordChangeSection(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1A1F36),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSelector() {
    return GestureDetector(
      onTap: _openInterestSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: _selectedInterests.isEmpty
            ? Text(
                'Tap to select interests...',
                style: TextStyle(color: Colors.grey[400]),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _selectedInterests
                    .map(
                      (interest) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.teal.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          interest,
                          style: TextStyle(
                            color: Colors.teal[700],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
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

  // ── 비밀번호 변경 섹션 ──
  List<Widget> _buildPasswordChangeSection() {
    return [
      const SizedBox(height: 32),
      _buildSectionHeader(
        Icons.key_outlined,
        'Change Password',
        'Verify current password to set a new one',
      ),
      const SizedBox(height: 16),

      // Current password
      _buildLabel('Current Password'),
      const SizedBox(height: 8),
      TextField(
        controller: _currentPasswordController,
        obscureText: !_showCurrentPw,
        decoration: InputDecoration(
          hintText: 'Enter current password',
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
          suffixIcon: IconButton(
            icon: Icon(
              _showCurrentPw ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _showCurrentPw = !_showCurrentPw),
          ),
        ),
      ),

      const SizedBox(height: 20),

      // New password
      _buildLabel('New Password'),
      const SizedBox(height: 8),
      TextField(
        controller: _newPasswordController,
        obscureText: !_showNewPw,
        decoration: InputDecoration(
          hintText: 'New password (min. 6 characters)',
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
          suffixIcon: IconButton(
            icon: Icon(
              _showNewPw ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _showNewPw = !_showNewPw),
          ),
        ),
      ),

      const SizedBox(height: 20),

      // Confirm new password
      _buildLabel('Confirm New Password'),
      const SizedBox(height: 8),
      TextField(
        controller: _confirmNewPasswordController,
        obscureText: !_showConfirmPw,
        decoration: InputDecoration(
          hintText: 'Re-enter new password',
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
          suffixIcon: IconButton(
            icon: Icon(
              _showConfirmPw ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _showConfirmPw = !_showConfirmPw),
          ),
        ),
      ),

      const SizedBox(height: 20),

      // 비밀번호 변경 버튼
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isChangingPassword ? null : _changePassword,
          icon: _isChangingPassword
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.lock_reset, size: 18),
          label: Text(_isChangingPassword ? 'Changing...' : 'Change Password'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordController.text.trim();
    final newPw = _newPasswordController.text.trim();
    final confirm = _confirmNewPasswordController.text.trim();

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all password fields.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (newPw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 6 characters.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (newPw != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await authService.changePassword(
      currentPassword: current,
      newPassword: newPw,
    );

    if (!mounted) return;
    setState(() => _isChangingPassword = false);

    if (result.isSuccess) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Password changed successfully!'),
          backgroundColor: Colors.teal,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to change password.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
