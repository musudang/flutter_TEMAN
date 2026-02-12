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
}
