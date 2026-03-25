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

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id']?.toString() ?? '',
      participantIds: List<String>.from(json['participantIds'] ?? []),
      lastMessage: json['lastMessage'] ?? '',
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'])
          : DateTime.now(),
      unreadCounts: Map<String, int>.from(json['unreadCounts'] ?? {}),
      isGroup: json['isGroup'] ?? false,
      groupName: json['groupName'],
      meetupId: json['meetupId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCounts': unreadCounts,
      'isGroup': isGroup,
      'groupName': groupName,
      'meetupId': meetupId,
    };
  }
}
