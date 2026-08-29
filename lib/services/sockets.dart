import 'dart:async';
import 'dart:convert';

import 'api_client.dart';
import 'resilient_socket_service.dart';

Uri _buildUri(String path, String token) {
  final decodedUrl =
      utf8.decode(base64Decode('d3M6Ly8xNzguMTA0LjMuMjY6ODAwMA=='));
  return Uri.parse('$decodedUrl$path?token=$token');
}

Future<String?> _fetchTicket() async {
  final r = await ApiClient.dio.post('/user/ws-python-ticket');
  return r.data['token'] as String?;
}

/// Shared across MarketsScreen (Strategies / Top Movers / Live Breakout).
/// Both `acquire()` here refer to this SAME object, so switching tabs or
/// rebuilding MarketsScreen never creates a second /stock-screener socket.
final marketsSocket = ResilientSocketService(
  wsUriBuilder: (token) => _buildUri('/stock-screener', token),
  ticketFetcher: _fetchTicket,
  subscribeMessage: const {
    'type': 'subscribe',
    'channels': ['strategies', 'breakouts', 'movers'],
  },
);

/// Shared for SectorsTab's AND StockRibbon's /ltp-stocks feed — both read
/// the same symbols from the same endpoint, so they share one socket.
final sectorsSocket = ResilientSocketService(
  wsUriBuilder: (token) => _buildUri('/ltp-stocks', token),
  ticketFetcher: _fetchTicket,
);

/// Maintains ONE merged `{symbol: data}` map for the /ltp-stocks feed,
/// built from sectorsSocket's raw messages, so any widget that mounts
/// AFTER the initial snapshot already went by (e.g. StockRibbon mounting
/// after SectorsTab, or vice versa) can read the current prices right
/// away instead of waiting for a fresh 'initial_snapshot' that may not
/// be resent for a while.
///
/// Widgets don't need to call acquire()/release() on this — only on
/// sectorsSocket itself, exactly as before. This just centralizes the
/// map-building logic both screens were duplicating.
class LivePricesCache {
  final Map<String, dynamic> _prices = {};
  bool _hasSnapshot = false;
  StreamSubscription? _sub;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  /// Emits the full merged map every time it changes.
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  /// Current merged prices, read synchronously (e.g. in initState).
  Map<String, dynamic> get current => Map.unmodifiable(_prices);

  /// Whether we've received at least one initial_snapshot yet.
  bool get hasSnapshot => _hasSnapshot;

  LivePricesCache() {
    _sub = sectorsSocket.stream.listen((message) {
      final decoded = jsonDecode(message);
      if (decoded['type'] == 'initial_snapshot') {
        _prices
          ..clear()
          ..addAll(Map<String, dynamic>.from(decoded['data']));
        _hasSnapshot = true;
      } else if (decoded['type'] == 'update') {
        _prices[decoded['symbol']] = decoded['data'];
      } else {
        return;
      }
      _controller.add(Map.unmodifiable(_prices));
    });
  }
}

final sectorsPrices = LivePricesCache();