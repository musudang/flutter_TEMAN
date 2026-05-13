import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart' as app_models;
import 'contact_us_screen.dart';
import 'notices_screen.dart';
import 'restriction_history_screen.dart';
import 'information_consent_screen.dart';
import 'blocked_users_screen.dart';

class SettingsScreen extends StatefulWidget {
  final app_models.User user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Step 1 confirmation dialog
  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isEmailUser = authService.isEmailPasswordUser;

    // Step 1: Warning dialog
    final step1Confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Account', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          'This action cannot be undone.\n\n'
          'All your data including your profile, posts, and settings will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (step1Confirmed != true) return;
    if (!context.mounted) return;

    // Step 2: Password confirmation (email users) or final confirmation (social users)
    if (isEmailUser) {
      await _showPasswordConfirmDialog(context, authService);
    } else {
      await _performDelete(context, authService, null);
    }
  }

  Future<void> _showPasswordConfirmDialog(
    BuildContext context,
    AuthService authService,
  ) async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Confirm Your Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter your password to confirm account deletion.'),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await _performDelete(context, authService, passwordController.text.trim());
    passwordController.dispose();
  }

  Future<void> _performDelete(
    BuildContext context,
    AuthService authService,
    String? password,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await authService.deleteAccount(currentPassword: password);

    navigator.pop(); // Close loading

    if (result.isSuccess) {
      // ignore: use_build_context_synchronously
      await showDialog(
        context: navigator.context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Account Deleted'),
          content: const Text('Your account and data have been permanently deleted.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E56C8)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      navigator.pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to delete account.'),
        ),
      );
    }
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
          _buildSectionGroup('Community', [
            _buildSettingItem(
              context,
              title: 'Restriction History',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RestrictionHistoryScreen(),
                  ),
                );
              },
            ),
            _buildSettingItem(
              context,
              title: 'Blocked Users',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BlockedUsersScreen(),
                  ),
                );
              },
            ),
            _buildSettingItem(
              context,
              title: 'Community Guidelines',
              onTap: () async {
                final url = Uri.parse(
                  'https://teman-web-2026.web.app/community-rules.html',
                );
                // Use external browser — see login_screen for rationale.
                await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ]),
          const SizedBox(height: 16),
          _buildSectionGroup('Information / Support', [
            _buildSettingItem(
              context,
              title: 'Contact Us',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ContactUsScreen(currentUser: widget.user),
                  ),
                );
              },
            ),
            _buildSettingItem(
              context,
              title: 'Notices',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        NoticesScreen(isAdmin: widget.user.isAdmin),
                  ),
                );
              },
            ),
            _buildSettingItem(
              context,
              title: 'Terms of Service',
              onTap: () async {
                final url = Uri.parse(
                  'https://teman-web-2026.web.app/terms.html',
                );
                // Use external browser — see login_screen for rationale.
                await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            _buildSettingItem(
              context,
              title: 'Privacy Policy',
              onTap: () async {
                final url = Uri.parse(
                  'https://teman-web-2026.web.app/privacy.html',
                );
                // Use external browser — see login_screen for rationale.
                await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ]),
          const SizedBox(height: 16),
          _buildSectionGroup('Other', [
            _buildSettingItem(
              context,
              title: 'Information Consent Settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        InformationConsentScreen(userId: widget.user.id),
                  ),
                );
              },
            ),
            _buildSettingItem(
              context,
              title: 'Delete Account',
              onTap: () => _showDeleteAccountDialog(context),
              textColor: Colors.red,
            ),
            _buildSettingItem(
              context,
              title: 'Sign Out',
              onTap: () async {
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                await authService.signOut();
                // ignore: use_build_context_synchronously
                if (context.mounted) {
                  Navigator.of(context).pop(); // Pop settings screen
                }
              },
              textColor: Colors.red,
            ),
          ]),
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
            padding: const EdgeInsets.only(
              left: 16,
              top: 16,
              bottom: 8,
              right: 16,
            ),
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
            Text(title, style: TextStyle(fontSize: 15, color: textColor)),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}
