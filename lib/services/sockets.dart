import 'dart:async';
import 'dart:convert';

import 'api_client.dart';
import 'auth_api_client.dart';
import 'resilient_socket_service.dart';

/// Market-data service (same host the web portal's SOCKET_BACKEND_URL
/// points at). The old hard-coded IP (ws://178.104.3.26:8000) no longer
/// answers, and plain ws:// is blocked by iOS anyway.
const String _marketDataBaseUrl = 'wss://ws.teztrader.com';

Uri _buildUri(String path, String token) =>
    Uri.parse('$_marketDataBaseUrl$path?token=$token');

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
    'channels': ['reversal_strategies', 'breakouts', 'movers'],
  },
);

/// Sector rotation board (strong/weak sectors, rotation arrows, signals).
final rotationSocket = ResilientSocketService(
  wsUriBuilder: (token) => _buildUri('/sector-rotation', token),
  ticketFetcher: _fetchTicket,
);

/// Live market news. It's served by a separate host from the price feeds
/// and uses the public (no-login) ticket, like the portal's News page.
const String _newsBaseUrl = 'wss://ws.wjxq.info';

Future<String?> _fetchPublicTicket() async {
  final r = await AuthApiClient.dio.get('/auth/tz-python-super-secret-generator-lmcql');
  return r.data['token'] as String?;
}

final newsSocket = ResilientSocketService(
  wsUriBuilder: (token) => Uri.parse('$_newsBaseUrl/ws/news?token=$token'),
  ticketFetcher: _fetchPublicTicket,
);

/// Symbols the paper-trading screen wants live prices for. The feed only
/// streams what it's told to via `update_symbols`, so this is re-sent on
/// every reconnect and whenever the set of open positions changes.
List<String> paperSymbols = [];

final paperSocket = ResilientSocketService(
  wsUriBuilder: (token) => _buildUri('/ltp-stocks-subscribed', token),
  ticketFetcher: _fetchTicket,
  subscribeMessageBuilder: () => {
    'type': 'update_symbols',
    'symbols': paperSymbols,
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
      } else if (decoded['type'] == 'batch') {
        // Many symbols at once, roughly every 250 ms: {SYMBOL: {...}, ...}
        _prices.addAll(Map<String, dynamic>.from(decoded['data']));
      } else if (decoded['type'] == 'update') {
        // Older per-symbol format; the server may still send it.
        _prices[decoded['symbol']] = decoded['data'];
      } else {
        return;
      }
      _controller.add(Map.unmodifiable(_prices));
    });
  }
}

final sectorsPrices = LivePricesCache();

const List<String> trackingInstruments = [
  "NIFTY_50",
  "NIFTY_BANK",
  "SENSEX",
  "NIFTY GIFT",
  "INDIA_VIX",
];

bool isTrackingInstrument(String symbol) => trackingInstruments.contains(symbol);