class User {
  final String id;
  final String name;
  final String avatarUrl;
  final String nationality;
  final String email;
  final String bio;
  final String role; // 'user' or 'admin'
  final DateTime? createdAt;

  User({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.nationality = 'KR 🇰🇷',
    this.email = '',
    this.bio = '',
    this.role = 'user',
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';
}
