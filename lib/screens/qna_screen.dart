import 'package:flutter/material.dart';

class QnaScreen extends StatelessWidget {
  const QnaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Q&A (지식인)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildQuestionItem(
            'Visa Question',
            'How long does it take to renew an F-6 visa?',
            'user123',
            5,
          ),
          _buildQuestionItem(
            'Transportation',
            'Is the subway running after midnight on weekends?',
            'traveler_99',
            2,
          ),
          _buildQuestionItem(
            'Food Recommendation',
            'Best place for Samgyetang in Seoul?',
            'hungry_bear',
            12,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Ask Question'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuestionItem(
    String title,
    String content,
    String author,
    int answers,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              'By $author • $answers answers',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
