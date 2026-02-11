import 'package:flutter/material.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: ListView(
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

          // Mock Feed
          _buildPostItem(
            'Admin',
            'Welcome to TEMAN! This is the official community for foreigners in Korea.',
            '2 hours ago',
          ),
          _buildPostItem(
            'Sarah L.',
            'Does anyone know where to buy cheap furniture near Gangnam? I just moved in!',
            '5 hours ago',
          ),
          _buildPostItem(
            'Mike R.',
            'Looking for a language exchange partner. I speak English and French.',
            '1 day ago',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
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

  Widget _buildPostItem(String author, String content, String time) {
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
                child: Text(author[0]),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    time,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border, size: 20),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
              ),
              const Text('0'),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.comment_outlined, size: 20),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
              ),
              const Text('0'),
            ],
          ),
        ],
      ),
    );
  }
}
