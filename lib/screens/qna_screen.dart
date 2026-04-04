import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../models/question_model.dart';
import '../models/user_model.dart' as app_models;
import 'create_qna_screen.dart';
import 'qna_detail_screen.dart';

class QnaScreen extends StatelessWidget {
  const QnaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Q&A (지식인)')),
      body: StreamBuilder<app_models.User?>(
        stream: firestoreService.currentUserId != null
            ? firestoreService.getUserStream(firestoreService.currentUserId!)
            : null,
        builder: (context, userSnap) {
          final hiddenUsers = <String>[
            ...(userSnap.data?.blockedUsers ?? []),
            ...(userSnap.data?.blockedBy ?? []),
          ];
          return StreamBuilder<List<Question>>(
            stream: firestoreService.getQuestions(hiddenUsers: hiddenUsers),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final questions = snapshot.data ?? [];
              if (questions.isEmpty) {
                return const Center(child: Text('No questions yet. Ask one!'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final question = questions[index];
                  return _buildQuestionItem(context, question);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'qna_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateQnaScreen()),
          );
        },
        label: const Text('Ask Question'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuestionItem(BuildContext context, Question question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          question.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              question.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'By ${question.authorName} • ${question.answersCount} answers',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QnaDetailScreen(question: question),
            ),
          );
        },
      ),
    );
  }
}
