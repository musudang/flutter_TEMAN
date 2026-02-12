import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      // The original code fetched 'user' and 'currentUser' and checked for null.
      // The new instruction implies using firestoreService.currentUserId! directly.
      // We'll keep the user check for robustness, but adapt the addPost call.
      final user = await firestoreService.getCurrentUser();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (user == null || currentUser == null) {
        debugPrint(
          "Error: User is null. DatabaseUser: $user, AuthUser: $currentUser",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: You must be logged in to post'),
            ),
          );
        }
        return;
      }

      debugPrint("Submitting post for user: ${user.name} (${user.id})");
      await firestoreService.addPost(title, content, user.id, user.name);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error creating post: $e\nHint: Check Firebase Console Rules!',
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Permission Error'),
                    content: const Text(
                      'This error usually means the Firestore Security Rules on the Firebase Console are blocking the write operation.\n\nPlease go to Firebase Console > Firestore Database > Rules and ensure "allow read, write: if request.auth != null;" is deployed.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
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
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          TextButton(
            onPressed: _isSubmitting || _contentController.text.trim().isEmpty
                ? null
                : _submitPost,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: "What's on your mind?",
                    border: InputBorder.none,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) {
                    setState(() {}); // Rebuild to enable/disable button
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
