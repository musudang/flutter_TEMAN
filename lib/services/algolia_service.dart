import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service class for searching posts via Algolia.
///
/// Uses the Algolia REST API directly (no heavy SDK dependency needed).
/// The Firebase Extension "Search with Algolia" keeps the `posts` index
/// in sync with Firestore automatically.
class AlgoliaService {
  static const String _applicationId = 'S08SBCEGXX';
  static const String _searchApiKey = '57c2b826e3dea5f2f0ba7938c808cd3d';
  /// Searches the given Algolia [indexName] for the given [query].
  ///
  /// Returns a list of Maps, each representing a hit (document).
  /// The returned maps contain the Firestore document fields plus
  /// an `objectID` which matches the Firestore document ID.
  static Future<List<Map<String, dynamic>>> searchIndex(
    String indexName,
    String query, {
    int hitsPerPage = 20,
    String? filters,
  }) async {
    if (query.trim().isEmpty) return [];

    final url = Uri.parse(
      'https://$_applicationId-dsn.algolia.net/1/indexes/$indexName/query',
    );

    final body = <String, dynamic>{
      'query': query,
      'hitsPerPage': hitsPerPage,
    };
    if (filters != null && filters.isNotEmpty) {
      body['filters'] = filters;
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'X-Algolia-API-Key': _searchApiKey,
          'X-Algolia-Application-Id': _applicationId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final hits = (data['hits'] as List<dynamic>?) ?? [];
        return hits.cast<Map<String, dynamic>>();
      } else {
        // Fallback silently – the caller can decide how to handle
        return [];
      }
    } catch (e) {
      // Network / parsing error — return empty list so UI degrades gracefully
      return [];
    }
  }
}
