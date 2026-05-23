class User {
  final String id;
  final String name;
  final String avatarUrl;
  final String nationality;
  final String email;
  final String bio;
  final String role; // 'user' or 'admin'
  final DateTime? createdAt;
  final int? age;
  final String personalInfo;
  final String nickname;
  final String phoneNumber;
  final List<String> interests;

  final String instagramId;
  final List<String> followers;
  final List<String> following;

  final List<String> blockedUsers;
  final List<String> blockedBy;

  // University affiliation
  final String universityId;
  final String major;
  final String classOf; // e.g. "2024"
  final bool showClassOf; // whether to show classOf on profile
  // Location
  final double? latitude;
  final double? longitude;
  final bool locationSharingEnabled;
  final bool hideLocationFromFriends;
  final DateTime? locationUpdatedAt;

  /// "Map friends" — the user's opt-in close-friends list for location
  /// visibility. Bilateral: A sees B's pin on the map only if
  /// A.mapFriends.contains(B) && B.mapFriends.contains(A).
  /// Independent of `following`/`followers` (you can be mutual without
  /// being map friends).
  final List<String> mapFriends;

  User({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.nationality = 'KR 🇰🇷',
    this.email = '',
    this.bio = '',
    this.role = 'user',
    this.createdAt,
    this.age,
    this.personalInfo = '',
    this.nickname = '',
    this.phoneNumber = '',
    this.interests = const [],
    this.instagramId = '',
    this.followers = const [],
    this.following = const [],
    this.blockedUsers = const [],
    this.blockedBy = const [],
    this.universityId = '',
    this.major = '',
    this.classOf = '',
    this.showClassOf = false,
    this.latitude,
    this.longitude,
    this.locationSharingEnabled = true,
    this.hideLocationFromFriends = false,
    this.locationUpdatedAt,
    this.mapFriends = const [],
  });

  bool get isAdmin => role == 'admin';

  bool get isPhoneVerified => phoneNumber.isNotEmpty;
}
