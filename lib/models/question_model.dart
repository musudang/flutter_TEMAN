class Question {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime timestamp;
  final int answersCount;

  Question({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.timestamp,
    this.answersCount = 0,
  });
}
