import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/marketplace_model.dart';
import '../models/user_model.dart' as app_models;
import 'create_marketplace_item_screen.dart';
import 'marketplace_detail_screen.dart';
import 'package:intl/intl.dart';

class MarketplaceListScreen extends StatefulWidget {
  final bool embedded;
  const MarketplaceListScreen({super.key, this.embedded = false});

  @override
  State<MarketplaceListScreen> createState() => _MarketplaceListScreenState();
}

class _MarketplaceListScreenState extends State<MarketplaceListScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Electronics',
    'Fashion',
    'Books',
    'Home',
    'Beauty',
    'Sports',
    'Others',
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Jang-teo (Marketplace)'),
              automaticallyImplyLeading: false,
            ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        }
                      },
                      selectedColor: Colors.teal,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<app_models.User?>(
              stream: firestoreService.currentUserId != null
                  ? firestoreService.getUserStream(firestoreService.currentUserId!)
                  : null,
              builder: (context, userSnap) {
                final hiddenUsers = <String>[
                  ...(userSnap.data?.blockedUsers ?? []),
                  ...(userSnap.data?.blockedBy ?? []),
                ];
                return StreamBuilder<List<MarketplaceItem>>(
                  stream: firestoreService.getMarketplaceItems(
                    hiddenUsers: hiddenUsers,
                    category: _selectedCategory,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.storefront,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items in this category yet.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    final items = snapshot.data!;
                    return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MarketplaceDetailScreen(item: item),
                              ),
                            );
                          },
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    color: Colors.grey[300],
                                    width: double.infinity,
                                    child: item.imageUrls.isNotEmpty
                                        ? Image.network(
                                            item.imageUrls.first,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currencyFormat.format(item.price),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            item.condition,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            DateFormat(
                                              'MM/dd',
                                            ).format(item.postedDate),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton(
              heroTag: 'market_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateMarketplaceItemScreen(),
                  ),
                );
              },
              backgroundColor: Colors.teal,
              child: const Icon(Icons.add),
            ),
    );
  }
}
