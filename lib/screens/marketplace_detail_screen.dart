import 'package:flutter/material.dart';
import '../models/marketplace_model.dart';
import 'package:intl/intl.dart';
import 'user_profile_screen.dart';
import 'chat_screen.dart';

class MarketplaceDetailScreen extends StatelessWidget {
  final MarketplaceItem item;

  const MarketplaceDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Placeholder area
            Container(
              height: 250,
              color: Colors.grey[300],
              width: double.infinity,
              child: item.imageUrls.isNotEmpty
                  ? Image.network(item.imageUrls.first, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserProfileScreen(userId: item.sellerId),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: item.sellerAvatar.isNotEmpty
                              ? NetworkImage(item.sellerAvatar)
                              : null,
                          child: item.sellerAvatar.isEmpty
                              ? Text(
                                  item.sellerName.isNotEmpty
                                      ? item.sellerName[0].toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.sellerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMM d').format(item.postedDate),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormat.format(item.price),
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Chip(label: Text(item.condition)),
                      const SizedBox(width: 8),
                      Chip(label: Text(item.category)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    conversationId:
                        '', // Will be created or fetched in ChatScreen
                    chatTitle: item.sellerName,
                    otherUserId: item.sellerId,
                    otherUserName: item.sellerName,
                    otherUserAvatar: item.sellerAvatar,
                    initialMessage:
                        'Hi! I am interested in your item: ${item.title}',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat),
            label: const Text('Chat with Seller'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}
