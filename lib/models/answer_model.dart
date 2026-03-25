class Answer {
  final String id;
  final String questionId;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final DateTime timestamp;

  Answer({
    required this.id,
    required this.questionId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.timestamp,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      id: json['id']?.toString() ?? '',
      questionId: json['questionId']?.toString() ?? '',
      content: json['content'] ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName'] ?? '',
      authorAvatar: json['authorAvatar'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionId': questionId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
