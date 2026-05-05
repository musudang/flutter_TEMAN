/// University definitions for the TEMAN app.
/// Each university has a unique ID (used as Firestore sub-collection key),
/// Korean name, English name, short alias, and brand color.
library;

class University {
  final String id;
  final String nameKo;
  final String nameEn;
  final String shortName;
  final int colorValue;

  const University({
    required this.id,
    required this.nameKo,
    required this.nameEn,
    required this.shortName,
    required this.colorValue,
  });

  String get badgePath => 'images/universities/$id.png';
}

class UniversityConstants {
  static const List<University> universities = [
    University(
      id: 'hanyang',
      nameKo: '한양대학교',
      nameEn: 'Hanyang University',
      shortName: 'HYU',
      colorValue: 0xFF0057B7,
    ),
    University(
      id: 'kyunghee',
      nameKo: '경희대학교',
      nameEn: 'Kyung Hee University',
      shortName: 'KHU',
      colorValue: 0xFF8B0000,
    ),
    University(
      id: 'skku',
      nameKo: '성균관대학교',
      nameEn: 'Sungkyunkwan University',
      shortName: 'SKKU',
      colorValue: 0xFF006241,
    ),
    University(
      id: 'yonsei',
      nameKo: '연세대학교',
      nameEn: 'Yonsei University',
      shortName: 'YU',
      colorValue: 0xFF003876,
    ),
    University(
      id: 'chungang',
      nameKo: '중앙대학교',
      nameEn: 'Chung-Ang University',
      shortName: 'CAU',
      colorValue: 0xFF1B3A6B,
    ),
    University(
      id: 'korea',
      nameKo: '고려대학교',
      nameEn: 'Korea University',
      shortName: 'KU',
      colorValue: 0xFF8B0029,
    ),
    University(
      id: 'snu',
      nameKo: '서울대학교',
      nameEn: 'Seoul National University',
      shortName: 'SNU',
      colorValue: 0xFF003458,
    ),
    University(
      id: 'hufs',
      nameKo: '한국외국어대학교',
      nameEn: 'Hankuk University of Foreign Studies',
      shortName: 'HUFS',
      colorValue: 0xFF1A237E,
    ),
    University(
      id: 'ewha',
      nameKo: '이화여자대학교',
      nameEn: 'Ewha Womans University',
      shortName: 'EWU',
      colorValue: 0xFF00695C,
    ),
  ];

  /// Get university by ID
  static University? getById(String id) {
    try {
      return universities.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Firestore path helpers
  /// University posts are stored at: universities/{uniId}/posts/{docId}
  /// University questions are stored at: universities/{uniId}/questions/{docId}
  static String uniPostsPath(String uniId) => 'universities/$uniId/posts';
  static String uniQuestionsPath(String uniId) =>
      'universities/$uniId/questions';
}
