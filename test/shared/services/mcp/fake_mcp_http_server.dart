import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FakeMcpHttpServer {
  final HttpServer _server;
  final Uri baseUri;

  FakeMcpHttpServer._(this._server, this.baseUri);

  static Future<FakeMcpHttpServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUri = Uri.parse('http://127.0.0.1:${server.port}/mcp');
    const sessionId = 'fake-mcp-session';

    server.listen((req) async {
      if (req.method != 'POST') {
        req.response.statusCode = HttpStatus.methodNotAllowed;
        await req.response.close();
        return;
      }

      final body = await utf8.decoder.bind(req).join();
      if (body.trim().isEmpty) {
        req.response.statusCode = HttpStatus.noContent;
        await req.response.close();
        return;
      }

      Object? decoded;
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.write('invalid json');
        await req.response.close();
        return;
      }

      if (decoded is! Map) {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.write('invalid json-rpc');
        await req.response.close();
        return;
      }

      final map = decoded.map((k, v) => MapEntry('$k', v));
      final id = map['id'];
      final method = map['method']?.toString();
      if (method == null) {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.write('missing method');
        await req.response.close();
        return;
      }

      // JSON-RPC notification: no response body.
      if (id == null) {
        req.response.statusCode = HttpStatus.noContent;
        await req.response.close();
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
                'name': 'Fake MCP HTTP',
                'version': '0.0.0',
              },
              'capabilities': {
                'tools': {},
              },
            },
          };
          break;
        case 'ping':
          response = {
            'jsonrpc': '2.0',
            'id': id,
            'result': {},
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
              'structuredContent': {'echo': text},
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

      req.response.headers.contentType = ContentType.json;
      req.response.headers.set('Mcp-Session-Id', sessionId);
      req.response.write(jsonEncode(response));
      await req.response.close();
    });

    return FakeMcpHttpServer._(server, baseUri);
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

