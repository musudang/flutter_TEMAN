import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/marketplace_model.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'user_profile_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class MarketplaceDetailScreen extends StatefulWidget {
  final MarketplaceItem item;

  const MarketplaceDetailScreen({super.key, required this.item});

  @override
  State<MarketplaceDetailScreen> createState() =>
      _MarketplaceDetailScreenState();
}

class _MarketplaceDetailScreenState extends State<MarketplaceDetailScreen> {
  bool _loadingChat = false;

  Future<void> _openChat(FirestoreService firestoreService) async {
    setState(() => _loadingChat = true);
    try {
      final convId = await firestoreService.getOrCreateConversation(
        widget.item.sellerId,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: convId,
              chatTitle: widget.item.sellerName,
              otherUserId: widget.item.sellerId,
              otherUserName: widget.item.sellerName,
              otherUserAvatar: widget.item.sellerAvatar,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final currentUserId = firestoreService.currentUserId;
    final isOwnListing = currentUserId == widget.item.sellerId;
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Container(
              height: 250,
              color: Colors.grey[300],
              width: double.infinity,
              child: widget.item.imageUrls.isNotEmpty
                  ? Image.network(
                      widget.item.imageUrls.first,
                      fit: BoxFit.cover,
                    )
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
                  // Seller row — tappable
                  GestureDetector(
                    onTap: () {
                      if (isOwnListing) {
                        // Go to own profile (ProfileScreen)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserProfileScreen(userId: widget.item.sellerId),
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: widget.item.sellerAvatar.isNotEmpty
                              ? NetworkImage(widget.item.sellerAvatar)
                              : null,
                          child: widget.item.sellerAvatar.isEmpty
                              ? Text(
                                  widget.item.sellerName.isNotEmpty
                                      ? widget.item.sellerName[0].toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.item.sellerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMM d').format(widget.item.postedDate),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.item.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormat.format(widget.item.price),
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Chip(label: Text(widget.item.condition)),
                      const SizedBox(width: 8),
                      Chip(label: Text(widget.item.category)),
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
                    widget.item.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Hide chat button when viewing own listing
      bottomNavigationBar: isOwnListing
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _loadingChat
                      ? null
                      : () => _openChat(firestoreService),
                  icon: _loadingChat
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.chat),
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
