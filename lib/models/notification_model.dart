class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // 'message', 'comment', 'system', 'meetup_join'
  final String relatedId; // ID of the post, chat, or meetup
  final bool isRead;
  final DateTime timestamp;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.relatedId,
    required this.isRead,
    required this.timestamp,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> data) {
    return NotificationModel(
      id: data['id']?.toString() ?? '',
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'system',
      relatedId: data['relatedId'] ?? '',
      isRead: data['isRead'] ?? false,
      timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'isRead': isRead,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
