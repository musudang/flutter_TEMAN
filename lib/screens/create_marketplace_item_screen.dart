import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/marketplace_model.dart';
import '../services/firestore_service.dart';

class CreateMarketplaceItemScreen extends StatefulWidget {
  final MarketplaceItem? editingItem;

  const CreateMarketplaceItemScreen({super.key, this.editingItem});

  @override
  State<CreateMarketplaceItemScreen> createState() =>
      _CreateMarketplaceItemScreenState();
}

class _CreateMarketplaceItemScreenState
    extends State<CreateMarketplaceItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Electronics'; // Default
  String _condition = 'Used'; // Default

  bool _isLoading = false;

  final List<String> _conditions = ['New', 'Like New', 'Used', 'Refurbished'];
  final List<String> _categories = [
    'Electronics',
    'Fashion',
    'Books',
    'Home',
    'Beauty',
    'Sports',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.editingItem != null) {
      _titleController.text = widget.editingItem!.title;
      _priceController.text = widget.editingItem!.price.toString();
      _descriptionController.text = widget.editingItem!.description;
      if (_categories.contains(widget.editingItem!.category)) {
        _selectedCategory = widget.editingItem!.category;
      }
      _condition = widget.editingItem!.condition;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

        final item = MarketplaceItem(
          id: '',
          title: _titleController.text.trim(),
          price: price,
          description: _descriptionController.text.trim(),
          condition: _condition,
          category: _selectedCategory,
          imageUrls: [], // Placeholder for now
          sellerId: '',
          sellerName: '',
          sellerAvatar: '',
          postedDate: DateTime.now(),
        );

        if (widget.editingItem != null) {
          await Provider.of<FirestoreService>(
            context,
            listen: false,
          ).updateMarketplaceItem(widget.editingItem!.id, {
            'title': item.title,
            'price': item.price,
            'description': item.description,
            'condition': item.condition,
            'category': item.category,
            // imageUrls are placeholders for now
          });
        } else {
          await Provider.of<FirestoreService>(
            context,
            listen: false,
          ).addMarketplaceItem(item);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.editingItem != null
                    ? 'Item updated successfully!'
                    : 'Item posted successfully!',
              ),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error posting item: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingItem != null ? 'Edit Item' : 'Sell an Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Item Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (KRW)',
                  border: OutlineInputBorder(),
                  prefixText: '₩ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter price'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter description'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _condition,
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  border: OutlineInputBorder(),
                ),
                items: _conditions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _condition = val);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 24),
              // Image upload placeholder
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: Colors.grey),
                      Text(
                        'Add Photos (Coming Soon)',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitItem,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.editingItem != null
                            ? 'Update Item'
                            : 'Post Item',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
