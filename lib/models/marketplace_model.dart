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

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) {
    return MarketplaceItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : (json['price'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      condition: json['condition'] ?? '',
      category: json['category'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      sellerId: json['sellerId']?.toString() ?? '',
      sellerName: json['sellerName'] ?? '',
      sellerAvatar: json['sellerAvatar'] ?? '',
      postedDate: json['postedDate'] != null
          ? DateTime.parse(json['postedDate'])
          : DateTime.now(),
      isSold: json['isSold'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'description': description,
      'condition': condition,
      'category': category,
      'imageUrls': imageUrls,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerAvatar': sellerAvatar,
      'postedDate': postedDate.toIso8601String(),
      'isSold': isSold,
    };
  }
}
