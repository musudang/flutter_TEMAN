import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mock_data_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<MockDataService>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(user.avatarUrl),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('@${user.id}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),

          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('My Meetups'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('My Posts'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Saved'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
