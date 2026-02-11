import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';

class CreateQnaScreen extends StatefulWidget {
  const CreateQnaScreen({super.key});

  @override
  State<CreateQnaScreen> createState() => _CreateQnaScreenState();
}

class _CreateQnaScreenState extends State<CreateQnaScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestion() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final user = await firestoreService.getCurrentUser();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: You must be logged in')),
          );
        }
        return;
      }

      await firestoreService.addQuestion(title, content, user.id, user.name);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question posted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error posting question: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isValid =
        _titleController.text.trim().isNotEmpty &&
        _contentController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Question'),
        actions: [
          TextButton(
            onPressed: _isSubmitting || !isValid ? null : _submitQuestion,
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
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Title",
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              onChanged: (val) => setState(() {}),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: "What's your question?",
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
