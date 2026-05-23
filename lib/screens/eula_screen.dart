import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main_screen.dart';

/// EULA / Terms of Service agreement screen.
/// Shown once after onboarding. User must agree before using the app.
class EulaScreen extends StatefulWidget {
  const EulaScreen({super.key});

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  bool _agreed = false;
  bool _isSubmitting = false;

  Future<void> _acceptEula() async {
    if (!_agreed) return;
    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'eulaAcceptedAt': FieldValue.serverTimestamp(),
        });
      }
      // Navigate directly to MainScreen (AuthWrapper's FutureBuilder
      // won't rebuild on its own since it's a one-shot future).
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Terms of Service',
          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1F36)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined,
                          size: 48, color: Colors.teal),
                      const SizedBox(height: 16),
                      const Text(
                        'End User License Agreement',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please read and accept our terms before using TEMAN.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EulaSection(
                              title: '1. Acceptance of Terms',
                              content:
                                  'By using TEMAN, you agree to these terms and our '
                                  'Privacy Policy. If you do not agree, you may not use the app.',
                            ),
                            _EulaSection(
                              title: '2. User Conduct',
                              content:
                                  'You agree not to post content that is illegal, harmful, '
                                  'threatening, abusive, harassing, defamatory, vulgar, obscene, '
                                  'or otherwise objectionable. There is zero tolerance for '
                                  'objectionable content or abusive behavior.',
                            ),
                            _EulaSection(
                              title: '3. Content Moderation',
                              content:
                                  'TEMAN reserves the right to remove any content and suspend '
                                  'or terminate accounts that violate these terms. Reported '
                                  'content will be reviewed and acted upon within 24 hours. '
                                  'Users who post objectionable content will be permanently '
                                  'removed from the platform.',
                            ),
                            _EulaSection(
                              title: '4. Anonymous Posting',
                              content:
                                  'While TEMAN allows anonymous posting, all posts are '
                                  'traceable by administrators for safety purposes. Anonymous '
                                  'posting does not exempt you from these terms.',
                            ),
                            _EulaSection(
                              title: '5. Location Sharing',
                              content:
                                  'TEMAN allows voluntary location sharing via manual check-in. '
                                  'Your location is only shared when you explicitly choose to '
                                  'check in, and is automatically removed after 3 minutes. '
                                  'You can check out at any time.',
                            ),
                            _EulaSection(
                              title: '6. Privacy',
                              content:
                                  'We respect your privacy. Personal data is handled in '
                                  'accordance with our Privacy Policy. You may block other '
                                  'users and report inappropriate content at any time.',
                            ),
                            _EulaSection(
                              title: '7. Contact',
                              content:
                                  'For questions, concerns, or to report inappropriate '
                                  'activity, please contact us through the app\'s Contact Us '
                                  'section in Settings, or email us at support@temanapp.com.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Agreement checkbox
              GestureDetector(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      activeColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'I have read and agree to the Terms of Service and '
                        'understand that objectionable content is not tolerated.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Accept button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _agreed && !_isSubmitting ? _acceptEula : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'I Agree',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EulaSection extends StatelessWidget {
  final String title;
  final String content;

  const _EulaSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1A1F36),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
