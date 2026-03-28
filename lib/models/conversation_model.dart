class Conversation {
  final String id;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts; // map of userId -> count
  final bool isGroup;
  final String? groupName;
  final String? meetupId;

  Conversation({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCounts = const {},
    this.isGroup = false,
    this.groupName,
    this.meetupId,
  });
}
