import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/io.dart';

import 'api_client.dart';
import 'auth_api_client.dart';

class UrgentAlert {
  final String id;
  final String message;
  final DateTime? timestamp;
  const UrgentAlert(this.id, this.message, this.timestamp);
}

/// Latest urgent admin broadcast. MainShell listens and shows a modal.
final ValueNotifier<UrgentAlert?> urgentAlert = ValueNotifier(null);

/// Backend alerts socket: admins can push an URGENT_BROADCAST to every
/// logged-in user. Needs a short-lived ticket (`/user/ws-node-ticket`) and an
/// allow-listed Origin header, which a native app must set itself (the web
/// portal gets it from the browser).
class AlertsService with WidgetsBindingObserver {
  AlertsService._();
  static final AlertsService instance = AlertsService._();

  static const _url = 'wss://api.teztrader.com';
  static const _retry = Duration(seconds: 3);

  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retryTimer;
  bool _wanted = false;
  bool _connecting = false;
  String? _lastId;

  void start() {
    if (_wanted) return;
    _wanted = true;
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  void stop() {
    _wanted = false;
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _close();
  }

  void _close() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _scheduleRetry() {
    _close();
    if (!_wanted) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retry, _connect);
  }

  Future<void> _connect() async {
    if (!_wanted || _connecting || _channel != null) return;
    _connecting = true;
    try {
      final res = await ApiClient.dio.post('/user/ws-node-ticket');
      final token = res.data['token'] as String?;
      if (token == null || !_wanted) {
        _scheduleRetry();
        return;
      }

      final channel = IOWebSocketChannel.connect(
        Uri.parse('$_url?token=$token'),
        headers: {'Origin': apiOrigin},
        pingInterval: const Duration(seconds: 25),
      );
      await channel.ready.timeout(const Duration(seconds: 10));
      _channel = channel;
      _sub = channel.stream.listen(
        _onMessage,
        onDone: _scheduleRetry,
        onError: (_) => _scheduleRetry(),
        cancelOnError: true,
      );
    } on SocketException {
      _scheduleRetry();
    } catch (_) {
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['type'] != 'URGENT_BROADCAST') return;
      final data = Map<String, dynamic>.from(msg['data'] as Map);
      final id = data['id']?.toString() ?? '';
      if (id.isNotEmpty && id == _lastId) return;
      _lastId = id;
      urgentAlert.value = UrgentAlert(
        id,
        data['message']?.toString() ?? '',
        DateTime.tryParse(data['timestamp']?.toString() ?? '')?.toLocal(),
      );
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_wanted) return;
    if (state == AppLifecycleState.paused) {
      // Drop the socket in the background; reconnect on resume.
      _retryTimer?.cancel();
      _close();
    } else if (state == AppLifecycleState.resumed && _channel == null) {
      _connect();
    }
  }
}
