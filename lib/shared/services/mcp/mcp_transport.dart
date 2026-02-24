abstract class McpTransport {
  Stream<Map<String, dynamic>> get incoming;
  Stream<String> get stderrLines;

  bool get isConnected;

  Future<void> connect();
  Future<void> send(Map<String, dynamic> message);
  Future<void> close();

  /// Optional hook for transports that surface protocol negotiation via headers.
  void updateProtocolVersion(String protocolVersion) {}
}

