import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question_model.dart';
import '../models/answer_model.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class QnaDetailScreen extends StatefulWidget {
  final Question question;

  const QnaDetailScreen({super.key, required this.question});

  @override
  State<QnaDetailScreen> createState() => _QnaDetailScreenState();
}

class _QnaDetailScreenState extends State<QnaDetailScreen> {
  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    if (_answerController.text.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Provider.of<FirestoreService>(
        context,
        listen: false,
      ).addAnswer(widget.question.id, _answerController.text.trim());
      _answerController.clear();
      // Scroll to bottom after adding
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to post answer: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Q&A Detail')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.question.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey[200],
                              child: Text(
                                widget.question.authorName[0].toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.question.authorName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat(
                                'MMM d, yyyy',
                              ).format(widget.question.timestamp),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.question.content,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Answers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Answers List
                  StreamBuilder<List<Answer>>(
                    stream: firestoreService.getAnswers(widget.question.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: const Text(
                            'No answers yet. Be the first to answer!',
                          ),
                        );
                      }

                      final answers = snapshot.data!;
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: answers.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final answer = answers[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundImage:
                                          answer.authorAvatar.isNotEmpty
                                          ? NetworkImage(answer.authorAvatar)
                                          : null,
                                      child: answer.authorAvatar.isEmpty
                                          ? Text(
                                              answer.authorName[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      answer.authorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat(
                                        'MMM d, HH:mm',
                                      ).format(answer.timestamp),
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(answer.content),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  // Add some bottom padding for the input field
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -2),
              blurRadius: 5,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answerController,
                  decoration: const InputDecoration(
                    hintText: 'Write an answer...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              IconButton(
                onPressed: _isSubmitting ? null : _submitAnswer,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.teal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
