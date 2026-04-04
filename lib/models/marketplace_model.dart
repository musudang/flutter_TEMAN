import 'package:cloud_firestore/cloud_firestore.dart';

class MarketplaceItem {
  final String id;
  final String title;
  final double price;
  final String description;
  final String condition; // New, Like New, Used, etc.
  final String category;
  final List<String> imageUrls;
  final String sellerId;
  final String sellerName;
  final String sellerAvatar;
  final DateTime postedDate;
  final bool isSold;

  MarketplaceItem({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.condition,
    required this.category,
    required this.imageUrls,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatar,
    required this.postedDate,
    this.isSold = false,
  });

  factory MarketplaceItem.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return MarketplaceItem(
      id: doc.id,
      title: data['title'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      condition: data['condition'] ?? 'Used',
      category: data['category'] ?? 'Other',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? 'Unknown',
      sellerAvatar: data['sellerAvatar'] ?? '',
      postedDate:
          (data['postedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSold: data['isSold'] ?? false,
    );
  }
}
