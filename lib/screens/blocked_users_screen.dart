import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart' as app_models;

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final currentUserId = firestoreService.currentUserId;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view blocked users.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<app_models.User?>(
        stream: firestoreService.getUserStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("An error occurred"));
          }

          final user = snapshot.data;
          final blockedUsers = user?.blockedUsers ?? [];

          if (blockedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No blocked users',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
              final targetUid = blockedUsers[index];
              return FutureBuilder<app_models.User?>(
                future: firestoreService.getUserById(targetUid),
                builder: (context, targetSnapshot) {
                  if (targetSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(targetUid),
                    );
                  }

                  final targetUser = targetSnapshot.data;
                  final displayName = targetUser?.name ?? 'Unknown User';
                  final avatarUrl = targetUser?.avatarUrl;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.teal,
                         textStyle: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await firestoreService.unblockUser(targetUid);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Unblocked $displayName')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Failed to unblock user.')),
                            );
                          }
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
