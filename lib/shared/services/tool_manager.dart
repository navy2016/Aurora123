import 'dart:convert';
import 'package:ddgs/ddgs.dart';

class ToolManager {
  final DDGS _ddgs = DDGS();

  /// Defines the available tools for the LLM
  List<Map<String, dynamic>> getTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'search_web',
          'description': 'Search the web for current information. Use this when the user asks about up-to-date events, news, or specific knowledge that might be recent.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'The search query to execute.'
              }
            },
            'required': ['query']
          }
        }
      }
    ];
  }

  /// Executes a tool call and returns the result as a JSON string
  Future<String> executeTool(String name, Map<String, dynamic> args, {String preferredEngine = 'duckduckgo'}) async {
    if (name == 'search_web') {
      final query = args['query'] as String;
      // Use preferred engine from settings, ignoring any hallucinated engine arg
      final result = await _searchWeb(query, preferredEngine);
      return result;
    }
    return jsonEncode({'error': 'Tool not found: $name'});
  }

  Future<String> _searchWeb(String query, String engine) async {
    try {
      
      // Attempt 1
      var results = await _ddgs.text(
        query,
        backend: engine,
        maxResults: 5,
      );

      // Fallback 1: If Google/Bing fails, try DuckDuckGo
      if (results.isEmpty && engine != 'duckduckgo') {
        results = await _ddgs.text(
          query,
          backend: 'duckduckgo',
          maxResults: 5,
        );
      }
      
      // Fallback 2: If still empty, try Bing (if not already tried)
      if (results.isEmpty && engine != 'bing') {
         results = await _ddgs.text(
           query,
           backend: 'bing',
           maxResults: 5,
         );
      }

      if (results.isEmpty) {
        return jsonEncode({
          'status': 'error',
          'message': 'No results found. The search engine returned no data. Please try a different query or check network connection.'
        });
      }

      // Format results for the LLM
      final formattedResults = results.asMap().entries.map((entry) {
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
        'engine': engine, // Keep original engine name in response context
        'results': formattedResults
      });
    } catch (e) {
      return jsonEncode({
        'status': 'error',
        'message': 'Search failed: $e'
      });
    }
  }
}
