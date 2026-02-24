import 'dart:async';

import 'mcp_constants.dart';
import 'json_rpc_peer.dart';
import 'mcp_stdio_transport.dart';
import 'mcp_streamable_http_transport.dart';
import 'mcp_transport.dart';

class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  factory McpTool.fromJson(Map<String, dynamic> json) {
    final rawSchema = json['inputSchema'];
    final schema = rawSchema is Map
        ? rawSchema.map((k, v) => MapEntry('$k', v))
        : <String, dynamic>{};
    return McpTool(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      inputSchema: schema,
    );
  }
}

class McpClientSession {
  final McpTransport _transport;
  final JsonRpcPeer _peer;

  bool _initialized = false;
  bool _pingSupported = true;
  String? _negotiatedProtocolVersion;

  McpClientSession._(this._transport, this._peer);

  Stream<String> get stderrLines => _transport.stderrLines;
  bool get pingSupported => _pingSupported;
  String? get negotiatedProtocolVersion => _negotiatedProtocolVersion;

  static Future<McpClientSession> connect({
    required String command,
    List<String> args = const [],
    String? cwd,
    Map<String, String>? env,
    bool runInShell = false,
  }) async {
    final McpTransport transport = McpStdioTransport(
      command: command,
      args: args,
      workingDirectory: cwd,
      environment: env,
      runInShell: runInShell,
    );
    await transport.connect();
    final peer = JsonRpcPeer(incoming: transport.incoming, send: transport.send);
    return McpClientSession._(transport, peer);
  }

  static Future<McpClientSession> connectHttp({
    required Uri url,
    Map<String, String> headers = const {},
    String protocolVersion = kMcpDefaultProtocolVersion,
  }) async {
    final McpTransport transport = McpStreamableHttpTransport(
      baseUri: url,
      headers: headers,
      initialProtocolVersion: protocolVersion,
    );
    await transport.connect();
    final peer = JsonRpcPeer(incoming: transport.incoming, send: transport.send);
    return McpClientSession._(transport, peer);
  }

  Future<void> initialize({
    String protocolVersion = kMcpDefaultProtocolVersion,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_initialized) return;
    final result = await _peer.request(
      'initialize',
      params: {
        'protocolVersion': protocolVersion,
        'capabilities': <String, dynamic>{},
        'clientInfo': {
          'name': 'Aurora',
          'version': 'unknown',
        },
      },
      timeout: timeout,
    );

    if (result is Map) {
      final map = result.map((k, v) => MapEntry('$k', v));
      final negotiated = map['protocolVersion']?.toString().trim();
      if (negotiated != null && negotiated.isNotEmpty) {
        _negotiatedProtocolVersion = negotiated;
        _transport.updateProtocolVersion(negotiated);
      }
    }
    await _peer.notify('notifications/initialized');
    _initialized = true;
  }

  Future<void> ping({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_initialized) {
      throw StateError('MCP session not initialized');
    }
    if (!_pingSupported) {
      throw UnsupportedError('MCP ping not supported');
    }
    try {
      await _peer.request('ping', timeout: timeout);
    } on JsonRpcException catch (e) {
      if (e.code == -32601) {
        _pingSupported = false;
        throw UnsupportedError('MCP ping not supported');
      }
      rethrow;
    }
  }

  Future<List<McpTool>> listToolsAll({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final tools = <McpTool>[];
    Object? cursor;
    while (true) {
      final params = <String, dynamic>{};
      if (cursor != null) params['cursor'] = cursor;
      final result = await _peer.request(
        'tools/list',
        params: params.isEmpty ? null : params,
        timeout: timeout,
      );
      if (result is! Map) break;
      final resultMap =
          result.map((key, value) => MapEntry('$key', value));
      final rawTools = resultMap['tools'];
      if (rawTools is List) {
        for (final t in rawTools) {
          if (t is Map) {
            tools.add(McpTool.fromJson(
                t.map((key, value) => MapEntry('$key', value))));
          }
        }
      }
      cursor = resultMap['nextCursor'] ?? resultMap['next_cursor'];
      if (cursor == null || (cursor is String && cursor.trim().isEmpty)) {
        break;
      }
    }
    return tools;
  }

  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> arguments, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await _peer.request(
      'tools/call',
      params: {
        'name': name,
        'arguments': arguments,
      },
      timeout: timeout,
    );
    if (result is Map) {
      return result.map((key, value) => MapEntry('$key', value));
    }
    return <String, dynamic>{'result': result};
  }

  Future<void> close() async {
    await _peer.close();
    await _transport.close();
  }
}
