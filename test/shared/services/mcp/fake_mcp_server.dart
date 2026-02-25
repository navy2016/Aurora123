import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    final msg = jsonDecode(trimmed);
    if (msg is! Map) return;
    final map = msg.map((k, v) => MapEntry('$k', v));

    final id = map['id'];
    final method = map['method']?.toString();
    if (method == null) return;

    if (id == null) {
      // notifications/initialized etc.
      return;
    }

    Map<String, dynamic> response;
    switch (method) {
      case 'initialize':
        response = {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': map['params']?['protocolVersion'] ?? 'unknown',
            'serverInfo': {
              'name': 'Fake MCP',
              'version': '0.0.0',
            },
            'capabilities': {
              'tools': {},
            },
          },
        };
        break;
      case 'tools/list':
        response = {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'tools': [
              {
                'name': 'echo',
                'description': 'Echo back the input text',
                'inputSchema': {
                  'type': 'object',
                  'properties': {
                    'text': {'type': 'string'}
                  },
                  'required': ['text'],
                },
              }
            ],
            'nextCursor': null,
          },
        };
        break;
      case 'tools/call':
        final params = map['params'];
        final name = (params is Map ? params['name'] : null)?.toString();
        if (name != 'echo') {
          response = {
            'jsonrpc': '2.0',
            'id': id,
            'error': {
              'code': -32001,
              'message': 'Unknown tool',
            },
          };
          break;
        }
        final rawArgs = params is Map ? params['arguments'] : null;
        final text =
            rawArgs is Map ? (rawArgs['text']?.toString() ?? '') : '';
        response = {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'content': [
              {'type': 'text', 'text': text}
            ],
            'isError': false,
          },
        };
        break;
      default:
        response = {
          'jsonrpc': '2.0',
          'id': id,
          'error': {
            'code': -32601,
            'message': 'Method not found',
          },
        };
    }

    stdout.writeln(jsonEncode(response));
  });

  // Keep the process alive.
  await Completer<void>().future;
}

