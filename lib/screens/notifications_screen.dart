import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/notification_model.dart';
import 'post_detail_screen.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';
import 'meetup_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete All Notifications?'),
                  content: const Text(
                    'Are you sure you want to delete all of your notifications? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Delete All',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) =>
                      const Center(child: CircularProgressIndicator()),
                );

                await firestoreService.deleteAllNotifications();

                // Close loading indicator
                if (context.mounted) {
                  Navigator.pop(context);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All notifications deleted')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: firestoreService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          final notifications = snapshot.data!;
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  firestoreService.deleteNotification(notification.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification deleted'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: ListTile(
                  tileColor: notification.isRead
                      ? Colors.white
                      : Colors.teal.withValues(alpha: 0.05),
                  leading: CircleAvatar(
                    backgroundColor: _getIconColor(notification.type),
                    child: Icon(
                      _getIcon(notification.type),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.body),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'MMM d, h:mm a',
                        ).format(notification.timestamp),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  onTap: () {
                    firestoreService.markNotificationAsRead(notification.id);
                    // Navigate to the relevant screen
                    if (notification.relatedId.isNotEmpty) {
                      switch (notification.type) {
                        case 'like':
                        case 'comment':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(
                                postId: notification.relatedId,
                              ),
                            ),
                          );
                          break;
                        case 'message':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: notification.relatedId,
                                chatTitle: 'Chat',
                              ),
                            ),
                          );
                          break;
                        case 'follow':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: notification.relatedId,
                              ),
                            ),
                          );
                          break;
                        case 'meetup_join':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetupDetailScreen(
                                meetupId: notification.relatedId,
                              ),
                            ),
                          );
                          break;
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'message':
        return Icons.message;
      case 'meetup_join':
        return Icons.group_add;
      case 'job':
        return Icons.work;
      case 'comment':
        return Icons.comment;
      case 'like':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'message':
        return Colors.blue;
      case 'meetup_join':
        return Colors.green;
      case 'job':
        return Colors.orange;
      case 'comment':
        return Colors.purple;
      case 'like':
        return Colors.red;
      default:
        return Colors.teal;
    }
  }
}
