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

  final String instagramId;
  final List<String> followers;
  final List<String> following;

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
    this.instagramId = '',
    this.followers = const [],
    this.following = const [],
  });

  bool get isAdmin => role == 'admin';
}
