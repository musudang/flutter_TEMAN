import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/marketplace_model.dart';
import 'dart:io';

mixin MarketplaceService on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // dummy

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<MarketplaceItem>> getMarketplaceItems({
    int limit = 20,
    List<String> hiddenUsers = const [],
    String? category,
  }) {
    Query query = _db.collection('marketplace').orderBy('postedDate', descending: true);
    
    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    return query
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => MarketplaceItem.fromFirestore(doc))
              .toList();
          if (hiddenUsers.isEmpty) return items;
          return items.where((i) => !hiddenUsers.contains(i.sellerId)).toList();
        });
  }

  Future<void> addMarketplaceItem(
    MarketplaceItem item, [
    List<File> imageFiles = const [],
  ]) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to post an item');
    }

    try {
      // 1. Upload images first (dummy logic since we don't have StorageService in this mixin directly)
      // We will assume imageFiles are somehow already uploaded or we store empty urls if needed.
      // Assuming image uploading logic is handled externally before calling addMarketplaceItem or we add a helper.
      List<String> imageUrls =
          item.imageUrls; // Assuming they are already populated for now

      // 2. Add document to Firestore
      await _db.collection('marketplace').add({
        'title': item.title,
        'price': item.price,
        'description': item.description,
        'condition': item.condition,
        'category': item.category,
        'imageUrls': imageUrls,
        'sellerId': _auth.currentUser!.uid,
        'sellerName': item.sellerName,
        'sellerAvatar': item.sellerAvatar,
        'postedDate': FieldValue.serverTimestamp(),
        'isSold': item.isSold,
      });
    } catch (e) {
      debugPrint("Error adding marketplace item: $e");
      rethrow;
    }
  }

  Future<void> updateMarketplaceItem(
    String itemId,
    Map<String, dynamic> data,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db.collection('marketplace').doc(itemId).get();
    if (!doc.exists) return;

    final docData = doc.data()!;
    if (docData['sellerId'] == uid) {
      await _db.collection('marketplace').doc(itemId).update(data);
    } else {
      throw Exception('Permission denied');
    }
  }

  Future<void> deleteMarketplaceItem(String itemId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db.collection('marketplace').doc(itemId).get();
    if (!doc.exists) return;

    final docData = doc.data()!;
    if (docData['sellerId'] == uid) {
      // Note: We should delete images from storage here as well eventually
      await _db.collection('marketplace').doc(itemId).delete();
    } else {
      throw Exception('Permission denied');
    }
  }

  Future<void> markItemAsSold(String itemId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _db.collection('marketplace').doc(itemId).get();
    if (!doc.exists) return;

    final docData = doc.data()!;
    if (docData['sellerId'] == uid) {
      await _db.collection('marketplace').doc(itemId).update({'isSold': true});
    } else {
      throw Exception('Permission denied');
    }
  }

  Stream<List<MarketplaceItem>> getUserMarketplaceItems(String userId) {
    return _db
        .collection('marketplace')
        .where('sellerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MarketplaceItem.fromFirestore(doc))
              .toList();
        });
  }
}
