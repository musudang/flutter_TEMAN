import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/notification_model.dart';

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
              return ListTile(
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
                  // Navigate based on type if needed
                },
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
