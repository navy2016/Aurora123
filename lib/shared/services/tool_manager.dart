import 'dart:convert';
import 'package:ddgs/ddgs.dart';

class ToolManager {
  final DDGS _ddgs = DDGS(timeout: const Duration(seconds: 15));
  List<Map<String, dynamic>> getTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'SearchWeb',
          'description':
              'Search the web for current information. Use this when the user asks about up-to-date events, news, or specific knowledge that might be recent.',
          'parameters': {
            'type': 'object',
            'required': ['query'],
            'properties': {
              'query': {
                'type': 'string',
                'description': 'The search query to execute.'
              }
            }
          }
        }
      }
    ];
  }

  Future<String> executeTool(String name, Map<String, dynamic> args,
      {String preferredEngine = 'duckduckgo'}) async {
    if (name == 'SearchWeb') {
      // Handle both 'query' (string) and 'queries' (array) - LLMs sometimes use wrong format
      String? query = args['query'] as String?;
      if ((query == null || query.isEmpty) && args['queries'] != null) {
        final queries = args['queries'];
        if (queries is List && queries.isNotEmpty) {
          // Join multiple queries or use the first one
          query = queries.whereType<String>().join(' OR ');
        }
      }
      if (query == null || query.isEmpty) {
        return jsonEncode({'error': 'Missing or empty query parameter'});
      }
      final result = await _searchWeb(query, preferredEngine);
      return result;
    }
    return jsonEncode({'error': 'Tool not found: $name'});
  }

  Future<String> _searchWeb(String query, String preferredEngine,
      {String region = 'us-en'}) async {
    final enginesToTry = {
      preferredEngine,
      'bing',
      'bing',
    }.toList();
    List<Map<String, dynamic>> finalResults = [];
    String successfulEngine = '';
    List<String> errors = [];
    for (final engine in enginesToTry) {
      if (finalResults.isNotEmpty) break;
      try {
        final results = await _ddgs
            .text(
              query,
              region: region,
              backend: engine,
              maxResults: 5,
            )
            .timeout(const Duration(seconds: 15));
        if (results.isNotEmpty) {
          finalResults = results;
          successfulEngine = engine;
        }
      } catch (e) {
        errors.add('$engine: $e');
      }
    }
    if (finalResults.isEmpty) {
      return jsonEncode({
        'status': 'error',
        'message':
            'No results found after trying mechanisms: ${enginesToTry.join(', ')}. Errors: ${errors.join('; ')}'
      });
    }
    final formattedResults = finalResults.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final r = entry.value;
      return {
        'index': index,
        'title': r['title'],
        'link': r['href'],
        'snippet': r['body'],
      };
    }).toList();
    return jsonEncode({
      'status': 'success',
      'engine': successfulEngine,
      'results': formattedResults
    });
  }
}
