import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mcp_transport.dart';

class _SseEvent {
  final String? event;
  final String data;

  const _SseEvent({required this.event, required this.data});
}

class _SseParser {
  String? _event;
  final List<String> _data = [];

  _SseEvent? addLine(String line) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) {
      if (_data.isEmpty) {
        _event = null;
        return null;
      }
      final event = _SseEvent(event: _event, data: _data.join('\n'));
      _event = null;
      _data.clear();
      return event;
    }

    if (trimmed.startsWith(':')) return null;

    final idx = trimmed.indexOf(':');
    final field = idx == -1 ? trimmed : trimmed.substring(0, idx);
    var value = idx == -1 ? '' : trimmed.substring(idx + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'event':
        _event = value;
        break;
      case 'data':
        _data.add(value);
        break;
      default:
        break;
    }
    return null;
  }
}

class McpStreamableHttpTransport implements McpTransport {
  final Uri baseUri;
  final Map<String, String> headers;

  McpStreamableHttpTransport({
    required this.baseUri,
    this.headers = const {},
    String? initialProtocolVersion,
  }) : _protocolVersion = initialProtocolVersion;

  HttpClient? _client;
  bool _closed = false;

  final StreamController<Map<String, dynamic>> _incomingController =
      StreamController<Map<String, dynamic>>.broadcast();

  String? _protocolVersion;
  String? _sessionId;

  Uri? _legacyEndpointUri;
  StreamSubscription<String>? _legacySseSub;
  Completer<Uri>? _legacyEndpointCompleter;

  @override
  Stream<Map<String, dynamic>> get incoming => _incomingController.stream;

  @override
  Stream<String> get stderrLines => const Stream<String>.empty();

  @override
  bool get isConnected => _client != null && !_closed;

  @override
  Future<void> connect() async {
    if (_closed) return;
    _client ??= HttpClient();
  }

  @override
  void updateProtocolVersion(String protocolVersion) {
    final raw = protocolVersion.trim();
    if (raw.isEmpty) return;
    _protocolVersion = raw;
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (_closed) {
      throw StateError('MCP HTTP transport is closed');
    }
    await connect();

    final method = message['method']?.toString();
    final isInitialize = method == 'initialize';

    // Legacy mode: POST to the negotiated endpoint; SSE stream stays open.
    if (_legacyEndpointUri != null) {
      await _postAndPipeResponse(_legacyEndpointUri!, message);
      return;
    }

    try {
      await _postAndPipeResponse(baseUri, message);
    } on HttpException catch (e) {
      // For legacy MCP servers that require an SSE handshake, initialize POST
      // may fail with a 4xx. Attempt fallback to GET SSE endpoint discovery.
      if (isInitialize && e.message.startsWith('HTTP 4')) {
        await _ensureLegacySseConnected();
        final endpoint = _legacyEndpointUri;
        if (endpoint != null) {
          await _postAndPipeResponse(endpoint, message);
          return;
        }
      }
      rethrow;
    }
  }

  Future<void> _postAndPipeResponse(Uri uri, Map<String, dynamic> message) async {
    final client = _client;
    if (client == null) {
      throw StateError('MCP HTTP transport is not connected');
    }

    final req = await client.postUrl(uri);
    _applyCommonHeaders(req.headers);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');

    final encoded = jsonEncode(message);
    req.add(utf8.encode(encoded));
    final res = await req.close();

    _captureSessionId(res.headers);

    final status = res.statusCode;
    if (status >= 400 && status < 500) {
      final body = await res.transform(utf8.decoder).join();
      throw HttpException('HTTP $status: $body', uri: uri);
    }
    if (status >= 500) {
      final body = await res.transform(utf8.decoder).join();
      throw HttpException('HTTP $status: $body', uri: uri);
    }

    final contentType = res.headers.contentType?.mimeType ?? '';
    if (contentType.contains('text/event-stream')) {
      await _pipeSseStream(res);
      return;
    }

    // Default to JSON.
    final body = await res.transform(utf8.decoder).join();
    if (body.trim().isEmpty) return;
    final decoded = jsonDecode(body);
    _pushDecoded(decoded);
  }

  void _applyCommonHeaders(HttpHeaders target) {
    for (final entry in headers.entries) {
      if (entry.key.trim().isEmpty) continue;
      target.set(entry.key, entry.value);
    }
    final pv = _protocolVersion;
    if (pv != null && pv.isNotEmpty) {
      target.set('MCP-Protocol-Version', pv);
    }
    final sid = _sessionId;
    if (sid != null && sid.isNotEmpty) {
      target.set('Mcp-Session-Id', sid);
    }
  }

  void _captureSessionId(HttpHeaders headers) {
    final value = headers.value('Mcp-Session-Id') ?? headers.value('MCP-Session-Id');
    final sid = value?.trim();
    if (sid != null && sid.isNotEmpty) {
      _sessionId = sid;
    }
  }

  Future<void> _pipeSseStream(HttpClientResponse res) async {
    final parser = _SseParser();
    await for (final line in res.transform(utf8.decoder).transform(const LineSplitter())) {
      final event = parser.addLine(line);
      if (event == null) continue;
      _handleSseEvent(event);
    }
  }

  void _handleSseEvent(_SseEvent event) {
    final name = event.event?.trim();
    final data = event.data.trim();
    if (data.isEmpty) return;

    // Legacy handshake: endpoint discovery.
    if (name == 'endpoint') {
      final uri = Uri.tryParse(data);
      final resolved = uri == null ? null : (uri.hasScheme ? uri : baseUri.resolveUri(uri));
      if (resolved != null) {
        _legacyEndpointUri = resolved;
        _legacyEndpointCompleter?.complete(resolved);
        _legacyEndpointCompleter = null;
      }
      return;
    }

    try {
      final decoded = jsonDecode(data);
      _pushDecoded(decoded);
    } catch (_) {
      // Ignore non-JSON SSE payloads.
    }
  }

  void _pushDecoded(dynamic decoded) {
    if (_incomingController.isClosed) return;
    if (decoded is Map) {
      _incomingController.add(decoded.map((k, v) => MapEntry('$k', v)));
      return;
    }
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          _incomingController.add(item.map((k, v) => MapEntry('$k', v)));
        }
      }
    }
  }

  Future<void> _ensureLegacySseConnected() async {
    if (_legacyEndpointUri != null) return;
    if (_legacyEndpointCompleter != null) {
      await _legacyEndpointCompleter!.future;
      return;
    }

    final client = _client;
    if (client == null) throw StateError('MCP HTTP transport is not connected');

    final completer = Completer<Uri>();
    _legacyEndpointCompleter = completer;

    final req = await client.getUrl(baseUri);
    _applyCommonHeaders(req.headers);
    req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    final res = await req.close();

    if (res.statusCode >= 400) {
      final body = await res.transform(utf8.decoder).join();
      _legacyEndpointCompleter = null;
      throw HttpException('HTTP ${res.statusCode}: $body', uri: baseUri);
    }

    final parser = _SseParser();
    _legacySseSub = res
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final event = parser.addLine(line);
      if (event == null) return;
      _handleSseEvent(event);
    }, onError: (_) {}, onDone: () {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Legacy SSE stream closed'));
      }
    });

    await completer.future;
  }

  @override
  Future<void> close() async {
    _closed = true;
    try {
      await _legacySseSub?.cancel();
    } catch (_) {}
    _legacySseSub = null;
    _legacyEndpointCompleter = null;

    try {
      _client?.close(force: true);
    } catch (_) {}
    _client = null;

    try {
      await _incomingController.close();
    } catch (_) {}
  }
}

