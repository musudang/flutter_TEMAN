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
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      nationality: json['nationality'] ?? json['country'] ?? '',
      email: json['email'] ?? '',
      bio: json['bio'] ?? '',
      role: json['role'] ?? 'user',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      age: json['age'],
      personalInfo: json['personalInfo'] ?? '',
      nickname: json['nickname'] ?? json['loginId'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone'] ?? '',
      interests: List<String>.from(json['interests'] ?? []),
      instagramId: json['instagramId'] ?? '',
      followers: List<String>.from(json['followers'] ?? []),
      following: List<String>.from(json['following'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'nationality': nationality,
      'email': email,
      'bio': bio,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
      'age': age,
      'personalInfo': personalInfo,
      'nickname': nickname,
      'phoneNumber': phoneNumber,
      'interests': interests,
      'instagramId': instagramId,
      'followers': followers,
      'following': following,
    };
  }
}
