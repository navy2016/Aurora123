import 'package:flutter_test/flutter_test.dart';

import 'package:aurora/shared/services/mcp/mcp_client_session.dart';

import 'fake_mcp_http_server.dart';

void main() {
  test('MCP streamable HTTP: initialize + tools/list + tools/call', () async {
    final server = await FakeMcpHttpServer.start();
    addTearDown(() async {
      await server.close();
    });

    final session = await McpClientSession.connectHttp(url: server.baseUri);
    addTearDown(() async {
      await session.close();
    });

    await session.initialize();
    await session.ping();

    final tools = await session.listToolsAll();
    expect(tools.map((t) => t.name), contains('echo'));

    final result = await session.callTool('echo', {'text': 'hello'});
    expect(result['isError'], isFalse);
    final content = result['content'];
    expect(content, isA<List>());
    final first = (content as List).first as Map;
    expect(first['type'], 'text');
    expect(first['text'], 'hello');
    expect(result['structuredContent'], isA<Map>());
  }, timeout: const Timeout(Duration(seconds: 20)));
}

