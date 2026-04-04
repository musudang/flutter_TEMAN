import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InformationConsentScreen extends StatefulWidget {
  final String userId;
  const InformationConsentScreen({super.key, required this.userId});

  @override
  State<InformationConsentScreen> createState() =>
      _InformationConsentScreenState();
}

class _InformationConsentScreenState extends State<InformationConsentScreen> {
  bool _marketingConsent = false;
  bool _personalizedAds = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsents();
  }

  Future<void> _loadConsents() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final consents = data['consentSettings'] as Map<String, dynamic>? ?? {};
        setState(() {
          _marketingConsent = consents['marketing'] ?? false;
          _personalizedAds = consents['personalizedAds'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateConsent(String key, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
            'consentSettings': {key: value},
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consent updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update consent: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Information Consent Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1F36),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1F36)),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildConsentItem(
            title: 'Marketing Information Reception Agreement',
            description:
                'Receive notifications about special offers, events, and promotions from TEMAN.',
            value: _marketingConsent,
            onChanged: (val) {
              setState(() => _marketingConsent = val);
              _updateConsent('marketing', val);
            },
          ),
          const SizedBox(height: 16),
          _buildConsentItem(
            title: 'Personalized Advertising Consent',
            description:
                'Allow TEMAN to use your data to provide more relevant and personalized ads.',
            value: _personalizedAds,
            onChanged: (val) {
              setState(() => _personalizedAds = val);
              _updateConsent('personalizedAds', val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConsentItem({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1F36),
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: const Color(0xFF1E56C8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
