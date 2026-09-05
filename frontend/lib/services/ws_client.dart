import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

const String _wsBaseOverride = String.fromEnvironment('WS_BASE', defaultValue: '');

/// Wraps the real-time WebSocket connection with automatic reconnect and a
/// broadcast stream of decoded server messages. Also exposes a connection
/// status stream so the UI can show online/offline state (satisfies the
/// "works offline" requirement gracefully — REST calls still work, chat and
/// live events just pause until reconnected).
class WsClient {
  final String Function() tokenProvider;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _connected = false;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<bool> get connectionStatus => _connection.stream;
  bool get isConnected => _connected;

  WsClient({required this.tokenProvider});

  String _wsUrl() {
    if (_wsBaseOverride.isNotEmpty) {
      return '$_wsBaseOverride/ws?token=${tokenProvider()}';
    }
    final uri = Uri.base;
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}${uri.hasPort && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}/ws?token=${tokenProvider()}';
  }

  void connect() {
    if (_disposed) return;
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_wsUrl()));
      _channel = channel;
      _sub = channel.stream.listen(
        (raw) {
          try {
            final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
            _messages.add(decoded);
          } catch (_) {}
        },
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
      // `ready` completes once the handshake succeeds (or throws if it
      // fails) — that's the real signal for "connected", not the first
      // message, since the server doesn't send one proactively.
      channel.ready.then((_) {
        if (_disposed || _channel != channel) return;
        _connected = true;
        _connection.add(true);
      }).catchError((_) {
        if (_channel == channel) _handleDisconnect();
      });
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (_connected) {
      _connected = false;
      _connection.add(false);
    }
    _sub?.cancel();
    _channel = null;
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), connect);
  }

  void send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  void notifySectorChanged() => send({'type': 'sync_sector'});

  void sendChat(String scope, String message) => send({'type': 'chat', 'scope': scope, 'message': message});

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _messages.close();
    _connection.close();
  }
}
