/// Basic content filter for objectionable content.
/// Checks text against a list of prohibited words/patterns.
class ContentFilter {
  ContentFilter._();

  /// Words/phrases that are not allowed in posts or comments.
  /// This is a basic list — extend as needed.
  static final List<String> _prohibitedWords = [
    // English slurs & hate speech
    'nigger', 'nigga', 'faggot', 'fag', 'retard', 'chink', 'gook',
    'spic', 'kike', 'tranny', 'cunt',
    // Violence-related
    'kill yourself', 'kys', 'go die',
    // Korean profanity
    '씨발', '씨발', '니미', '소아랑',
    '병신', '지랄', '새끼',
    '닥쳐', '개새끼', '죽어',
    '개자식', '게이',
  ];

  /// Returns `true` if the text contains prohibited content.
  static bool containsProhibitedContent(String text) {
    final lower = text.toLowerCase().trim();
    for (final word in _prohibitedWords) {
      if (lower.contains(word.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Returns a user-friendly error message if content is prohibited,
  /// or `null` if the content is clean.
  static String? validate(String text) {
    if (containsProhibitedContent(text)) {
      return 'Your message contains inappropriate language. '
          'Please revise and try again.';
    }
    return null;
  }
}
