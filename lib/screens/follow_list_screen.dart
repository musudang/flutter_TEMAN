import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart' as app_models;
import 'user_profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final int initialTabIndex; // 0 for Followers, 1 for Following

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.initialTabIndex = 0,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1F36),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(firestoreService.getFollowers(widget.userId)),
          _buildUserList(firestoreService.getFollowing(widget.userId)),
        ],
      ),
    );
  }

  Widget _buildUserList(Stream<List<app_models.User>> stream) {
    return StreamBuilder<List<app_models.User>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              tileColor: Colors.white,
              leading: CircleAvatar(
                backgroundColor: Colors.teal[50],
                backgroundImage: user.avatarUrl.isNotEmpty
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: user.avatarUrl.isEmpty
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Colors.teal[700],
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              title: Text(
                user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                user.nationality,
                style: const TextStyle(fontSize: 13),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(userId: user.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
