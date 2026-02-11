import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart'; // Import for User type

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final user = await firestoreService.getCurrentUser();
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("User not found."),
              ElevatedButton(
                onPressed: () => authService.signOut(),
                child: const Text("Logout"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              // AuthWrapper in main.dart handles redirect
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(_user!.avatarUrl),
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              _user!.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Settings List
            _buildSettingsItem(Icons.person_outline, 'Edit Profile'),
            _buildSettingsItem(Icons.notifications_outlined, 'Notifications'),
            _buildSettingsItem(Icons.security, 'Privacy & Security'),
            _buildSettingsItem(Icons.help_outline, 'Help & Support'),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: Navigate to respective settings
      },
    );
  }
}
