class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final DateTime timestamp;
  final String? sharedPostId;
  final String? sharedPostType; // 'meetup' or 'post'
  final String? sharedPostTitle;
  final String? sharedPostDescription;

  // New fields
  final String? replyToMessageId;
  final String? replyToMessageText;
  final String? replyToMessageSender;
  final Map<String, String>? reactions;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    required this.timestamp,
    this.sharedPostId,
    this.sharedPostType,
    this.sharedPostTitle,
    this.sharedPostDescription,
    this.replyToMessageId,
    this.replyToMessageText,
    this.replyToMessageSender,
    this.reactions,
  });
}
