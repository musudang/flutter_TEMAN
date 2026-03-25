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

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName'] ?? '',
      senderAvatar: json['senderAvatar'] ?? '',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      sharedPostId: json['sharedPostId']?.toString(),
      sharedPostType: json['sharedPostType'],
      sharedPostTitle: json['sharedPostTitle'],
      sharedPostDescription: json['sharedPostDescription'],
      replyToMessageId: json['replyToMessageId']?.toString(),
      replyToMessageText: json['replyToMessageText'],
      replyToMessageSender: json['replyToMessageSender'],
      reactions: json['reactions'] != null
          ? Map<String, String>.from(json['reactions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'sharedPostId': sharedPostId,
      'sharedPostType': sharedPostType,
      'sharedPostTitle': sharedPostTitle,
      'sharedPostDescription': sharedPostDescription,
      'replyToMessageId': replyToMessageId,
      'replyToMessageText': replyToMessageText,
      'replyToMessageSender': replyToMessageSender,
      'reactions': reactions,
    };
  }
}
