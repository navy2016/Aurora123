/// DuckDuckGo search engine implementation.
library;

import '../base_search_engine.dart';
import '../results.dart';

/// DuckDuckGo search engine (stub implementation).
class DuckDuckGoEngine extends BaseSearchEngine<TextResult> {
  DuckDuckGoEngine({super.proxy, super.timeout, super.verify});

  @override
  String get name => 'duckduckgo';

  @override
  String get category => 'text';

  @override
  String get provider => 'duckduckgo';

  @override
  String get searchUrl => 'https://duckduckgo.com/html/';

  @override
  String get searchMethod => 'GET';

  @override
  String get itemsSelector => '.result';

  @override
  Map<String, String> get elementsSelector => {
        'title': '.result__a', // Title is in the anchor
        'href': '.result__a',  // Link is also the anchor
        'body': '.result__snippet',
      };

  @override
  Map<String, String> buildPayload({
    required String query,
    required String region,
    required String safesearch,
    String? timelimit,
    int page = 1,
    Map<String, dynamic>? extra,
  }) {
    final safesearchMap = {'on': '1', 'moderate': '0', 'off': '-1'};

    final payload = {
      'q': query,
      'kl': region,
      'p': safesearchMap[safesearch.toLowerCase()] ?? '0',
    };

    if (timelimit != null) {
      payload['df'] = timelimit;
    }

    return payload;
  }

  @override
  List<TextResult> extractResults(String htmlText) {
    final results = <TextResult>[];
    final document = extractTree(htmlText);
    final items = document.querySelectorAll(itemsSelector);

    for (final item in items) {
      final titleElement = item.querySelector(elementsSelector['title']!);
      final bodyElement = item.querySelector(elementsSelector['body']!);

      final title = titleElement?.text ?? '';
      // Extract href attribute, not text
      var href = titleElement?.attributes['href'] ?? '';
      
      // DDG HTML sometimes wraps the real URL in a redirect like /l/?kh=-1&uddg=...
      // But typically in the HTML version it is a direct link or a simple redirect.
      // If it is /l/?uddg=..., we should decode it.
      if (href.contains('uddg=')) {
         final uri = Uri.tryParse(href);
         if (uri != null && uri.queryParameters.containsKey('uddg')) {
           href = uri.queryParameters['uddg'] ?? href;
         }
      }

      final body = bodyElement?.text ?? '';

      if (title.isNotEmpty || href.isNotEmpty) {
        results.add(TextResult(title: title, href: href, body: body));
      }
    }

    return results;
  }
}
