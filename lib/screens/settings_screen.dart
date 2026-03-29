import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart' as app_models;
import 'contact_us_screen.dart';

class SettingsScreen extends StatelessWidget {
  final app_models.User user;

  const SettingsScreen({super.key, required this.user});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This feature is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
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
          _buildSectionGroup(
            'Account',
            [
              _buildSettingItem(
                context,
                title: 'Change Password',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionGroup(
            'Community',
            [
              _buildSettingItem(
                context,
                title: 'Restriction History',
                onTap: () => _showComingSoon(context),
              ),
              _buildSettingItem(
                context,
                title: 'Community Guidelines',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionGroup(
            'Information / Support',
            [
              _buildSettingItem(
                context,
                title: 'Contact Us',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContactUsScreen(currentUser: user),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                context,
                title: 'Notices',
                onTap: () => _showComingSoon(context),
              ),
              _buildSettingItem(
                context,
                title: 'Terms of Service',
                onTap: () => _showComingSoon(context),
              ),
              _buildSettingItem(
                context,
                title: 'Privacy Policy',
                onTap: () => _showComingSoon(context),
              ),
              _buildSettingItem(
                context,
                title: 'Youth Protection Policy',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionGroup(
            'Other',
            [
              _buildSettingItem(
                context,
                title: 'Information Consent Settings',
                onTap: () => _showComingSoon(context),
              ),
              _buildSettingItem(
                context,
                title: 'Delete Account',
                onTap: () => _showComingSoon(context),
              ),
              _buildSettingItem(
                context,
                title: 'Sign Out',
                onTap: () async {
                  final authService =
                      Provider.of<AuthService>(context, listen: false);
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Pop settings screen
                  }
                },
                textColor: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionGroup(String title, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8, right: 16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1F36),
              ),
            ),
          ),
          ...items,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
    Color textColor = const Color(0xFF1A1F36),
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
