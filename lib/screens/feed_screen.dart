import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';
import 'create_post_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teman Feed'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Links Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickLink(
                  context,
                  Icons.info_outline,
                  'Info',
                  Colors.blue,
                ),
                _buildQuickLink(
                  context,
                  Icons.work_outline,
                  'Jobs',
                  Colors.orange,
                ),
                _buildQuickLink(
                  context,
                  Icons.storefront_outlined,
                  'Market',
                  Colors.green,
                ),
                _buildQuickLink(
                  context,
                  Icons.translate_outlined,
                  'Translate',
                  Colors.purple,
                ),
              ],
            ),
          ),
          const Divider(thickness: 8, color: Colors.black12),

          // Dynamic Feed
          Expanded(
            child: StreamBuilder<List<Post>>(
              stream: firestoreService.getPosts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = snapshot.data ?? [];
                if (posts.isEmpty) {
                  return const Center(
                    child: Text('No posts yet. Be the first!'),
                  );
                }

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _buildPostItem(post);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildQuickLink(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildPostItem(Post post) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final timeString = dateFormat.format(post.timestamp);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[300],
                child: Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : '?',
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.authorName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    timeString,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.content),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border, size: 20),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
              ),
              Text('${post.likes}'),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.comment_outlined, size: 20),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
              ),
              Text('${post.comments}'),
            ],
          ),
        ],
      ),
    );
  }
}
