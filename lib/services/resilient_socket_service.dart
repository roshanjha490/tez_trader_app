import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef TicketFetcher = Future<String?> Function();

/// A single, shared, self-healing WebSocket connection.
///
/// Multiple widgets can call `acquire()` / `release()` on the SAME instance
/// of this class (see sockets.dart for the singletons) — only the first
/// `acquire()` opens a socket, only the last matching `release()` closes it.
/// This is what prevents duplicate connections when you navigate between
/// tabs/screens that both want the same stream.
///
/// It also automatically:
///  - reconnects with backoff on onDone/onError
///  - reconnects when the app comes back to the foreground
///  - detects "zombie" connections (socket looks open but no data is
///    arriving — common on mobile networks) via a heartbeat/timeout check
///  - never gets permanently stuck if a connect attempt hangs (e.g. the
///    ticket-fetch request never resolves because the OS killed the
///    network stack while the app was suspended in the background)
class ResilientSocketService with WidgetsBindingObserver {
  ResilientSocketService({
    required this.wsUriBuilder, // (token) -> full ws:// or wss:// Uri
    required this.ticketFetcher,
    this.subscribeMessage,
    this.heartbeatInterval = const Duration(seconds: 20),
    this.heartbeatTimeout = const Duration(seconds: 45),
    this.connectTimeout = const Duration(seconds: 10),
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Uri Function(String token) wsUriBuilder;
  final TicketFetcher ticketFetcher;
  final Map<String, dynamic>? subscribeMessage;
  final Duration heartbeatInterval;
  final Duration heartbeatTimeout;
  // Max time we'll wait for ticketFetcher() + the socket handshake before
  // giving up on a connection attempt and letting it retry. Without this,
  // a hung request (common right after resuming from a long background
  // suspension) leaves _isConnecting stuck true FOREVER, silently
  // blocking every future reconnect attempt.
  final Duration connectTimeout;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  DateTime? _lastMessageAt;

  bool _isConnecting = false;
  bool _wantsConnection = false;
  int _reconnectAttempt = 0;
  int _listenerCount = 0;

  // Bumped every time we start a new attempt; lets a timed-out attempt
  // recognize it's stale and avoid clobbering a newer, successful one.
  int _connectGeneration = 0;

  final _controller = StreamController<dynamic>.broadcast();

  /// Broadcast stream of raw messages (still JSON strings — decode them
  /// the same way you already do in your screens).
  Stream<dynamic> get stream => _controller.stream;

  /// True only once we've actually received at least one message on the
  /// current connection attempt.
  bool get isConnected => _channel != null && _lastMessageAt != null;

  /// A stream of connection-status changes (true = connected, false = not)
  /// so screens can drive their "LIVE / WAIT" dot without polling.
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  void _setConnected(bool value) {
    _statusController.add(value);
  }

  /// Call in initState() of every widget that needs this socket.
  void acquire() {
    _listenerCount++;
    _wantsConnection = true;
    if (_channel == null && !_isConnecting) {
      _reconnectAttempt = 0;
      _connect();
    }
  }

  /// Call in dispose() of every widget that called acquire().
  void release() {
    _listenerCount = (_listenerCount - 1).clamp(0, 1 << 30);
    if (_listenerCount == 0) {
      _wantsConnection = false;
      _reconnectTimer?.cancel();
      _disconnect();
      _setConnected(false);
    }
  }

  Future<void> _connect() async {
    if (_isConnecting || !_wantsConnection || _channel != null) return;
    _isConnecting = true;
    final myGeneration = ++_connectGeneration;

    try {
      final token = await ticketFetcher()
          .timeout(connectTimeout, onTimeout: () => null);

      // Either timed out (token == null) or a newer attempt has already
      // started (e.g. a second resume event) — bail without touching
      // state that a later/other attempt now owns.
      if (myGeneration != _connectGeneration) return;
      if (token == null || !_wantsConnection) {
        return;
      }

      final channel = WebSocketChannel.connect(wsUriBuilder(token));
      // WebSocketChannel.connect() itself doesn't throw synchronously on
      // a bad host — wrap the "ready" future too so a hung handshake
      // can't block forever either.
      await channel.ready.timeout(connectTimeout);

      if (myGeneration != _connectGeneration || !_wantsConnection) {
        channel.sink.close();
        return;
      }

      _channel = channel;
      _lastMessageAt = DateTime.now();
      _setConnected(true);

      if (subscribeMessage != null) {
        channel.sink.add(jsonEncode(subscribeMessage));
      }

      _sub = channel.stream.listen(
        (message) {
          _lastMessageAt = DateTime.now();
          _reconnectAttempt = 0;
          if (!isConnected) _setConnected(true);
          _controller.add(message);
        },
        onDone: _handleDrop,
        onError: (_) => _handleDrop(),
        cancelOnError: true,
      );

      _startHeartbeat();
    } catch (_) {
      if (myGeneration == _connectGeneration) _handleDrop();
    } finally {
      if (myGeneration == _connectGeneration) _isConnecting = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_lastMessageAt == null) return;
      final silentFor = DateTime.now().difference(_lastMessageAt!);
      if (silentFor > heartbeatTimeout) {
        // No traffic for too long — the socket is very likely dead even
        // though onDone/onError never fired. This is the main fix for
        // "app sat in background too long" style disconnects.
        _handleDrop();
        return;
      }
      try {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {
        _handleDrop();
      }
    });
  }

  void _handleDrop() {
    _isConnecting = false;
    _disconnect();
    _setConnected(false);
    if (_wantsConnection) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempt++;
    final delaySeconds = (2 * _reconnectAttempt).clamp(2, 30);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _connect);
  }

  void _disconnect() {
    _heartbeatTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub = null;
    _lastMessageAt = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 1. COMPLETELY DROP CONNECTION ON BACKGROUND
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      if (_wantsConnection) {
        _isConnecting = false;
        _reconnectTimer?.cancel();
        _disconnect();
        _setConnected(false);
      }
      return;
    }

    // 2. RECONNECT ON FOREGROUND
    if (state != AppLifecycleState.resumed || !_wantsConnection) return;

    final stale = _lastMessageAt == null ||
        DateTime.now().difference(_lastMessageAt!) > heartbeatTimeout;

    if (!_isConnecting && (!isConnected || stale)) {
      _connectGeneration++;
      _isConnecting = false;
      _reconnectAttempt = 0;
      _reconnectTimer?.cancel();
      _disconnect();
      _connect();
    }
  }
}