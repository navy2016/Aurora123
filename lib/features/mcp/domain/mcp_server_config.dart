enum McpServerTransport {
  stdio,
  http,
}

String _transportToJson(McpServerTransport transport) {
  switch (transport) {
    case McpServerTransport.stdio:
      return 'stdio';
    case McpServerTransport.http:
      return 'http';
  }
}

McpServerTransport _transportFromJson(String? raw) {
  final normalized = (raw ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'http':
    case 'streamable_http':
    case 'sse':
      return McpServerTransport.http;
    case 'stdio':
    default:
      return McpServerTransport.stdio;
  }
}

class McpServerConfig {
  final String id;
  final String name;
  final bool enabled;
  final McpServerTransport transport;

  // stdio
  final String command;
  final List<String> args;
  final String? cwd;
  final Map<String, String> env;
  final bool runInShell;

  // http/streamable http
  final String url;
  final Map<String, String> headers;

  const McpServerConfig({
    required this.id,
    required this.name,
    this.transport = McpServerTransport.stdio,
    this.command = '',
    this.args = const [],
    this.enabled = true,
    this.cwd,
    this.env = const {},
    this.runInShell = false,
    this.url = '',
    this.headers = const {},
  });

  McpServerConfig copyWith({
    String? id,
    String? name,
    bool? enabled,
    McpServerTransport? transport,
    String? command,
    List<String>? args,
    String? cwd,
    Map<String, String>? env,
    bool? runInShell,
    String? url,
    Map<String, String>? headers,
  }) {
    return McpServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      transport: transport ?? this.transport,
      command: command ?? this.command,
      args: args ?? this.args,
      cwd: cwd ?? this.cwd,
      env: env ?? this.env,
      runInShell: runInShell ?? this.runInShell,
      url: url ?? this.url,
      headers: headers ?? this.headers,
    );
  }

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    final transport =
        _transportFromJson(json['transport']?.toString());

    final rawArgs = json['args'];
    final args = rawArgs is List
        ? rawArgs.map((e) => e.toString()).toList()
        : const <String>[];

    final rawEnv = json['env'];
    final env = <String, String>{};
    if (rawEnv is Map) {
      for (final entry in rawEnv.entries) {
        env[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }

    final rawHeaders = json['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }

    final rawCwd = json['cwd']?.toString();
    final cwd = (rawCwd != null && rawCwd.trim().isNotEmpty) ? rawCwd : null;

    return McpServerConfig(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      enabled: json['enabled'] == true,
      transport: transport,
      command: json['command']?.toString() ?? '',
      args: args,
      cwd: cwd,
      env: env,
      runInShell: json['runInShell'] == true,
      url: json['url']?.toString() ?? '',
      headers: headers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'transport': _transportToJson(transport),
      'command': command,
      'args': args,
      'cwd': cwd,
      'env': env,
      'runInShell': runInShell,
      'url': url,
      'headers': headers,
    };
  }
}
