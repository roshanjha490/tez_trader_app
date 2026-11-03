import 'package:dio/dio.dart';

import 'api_client.dart';

class PaperInstrument {
  final String symbol;
  final String rawSymbolId;
  final String type;
  final int lotSize;

  PaperInstrument({
    required this.symbol,
    required this.rawSymbolId,
    required this.type,
    required this.lotSize,
  });

  factory PaperInstrument.fromJson(Map<String, dynamic> json) => PaperInstrument(
        symbol: json['symbol']?.toString() ?? '',
        rawSymbolId: json['raw_symbol_id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        lotSize: int.tryParse(json['lot_size']?.toString() ?? '') ?? 1,
      );

  /// For futures/options the quantity entered is a number of lots.
  bool get isFno => const ['FUT', 'OPT', 'FNO', 'F_N_O'].contains(type.toUpperCase());
}

class PaperPosition {
  final int id;
  final String symbol;
  final String direction; // LONG | SHORT
  final int quantity;
  final double entryPrice;
  final double? exitPrice;
  final double? stopLoss;
  final double? target;
  final double? pnl;
  final String status; // OPEN | CLOSED

  PaperPosition({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.quantity,
    required this.entryPrice,
    this.exitPrice,
    this.stopLoss,
    this.target,
    this.pnl,
    required this.status,
  });

  static double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());

  factory PaperPosition.fromJson(Map<String, dynamic> json) => PaperPosition(
        id: (json['id'] as num).toInt(),
        symbol: json['symbol']?.toString() ?? '',
        direction: json['direction']?.toString() ?? 'LONG',
        quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
        entryPrice: _d(json['purchase_price_per_share']) ?? 0,
        exitPrice: _d(json['sale_price_per_share']),
        stopLoss: _d(json['stop_loss']),
        target: _d(json['target']),
        pnl: _d(json['profit_n_loss']),
        status: json['status']?.toString() ?? 'OPEN',
      );

  bool get isOpen => status == 'OPEN';
  bool get isLong => direction == 'LONG';

  /// Unrealised P&L at [ltp] for an open position.
  double livePnl(double ltp) => (isLong ? ltp - entryPrice : entryPrice - ltp) * quantity;

  /// 'Stop Loss Hit' / 'Target Hit' when [ltp] crossed a threshold, else null.
  String? exitReason(double ltp) {
    final sl = stopLoss;
    final tgt = target;
    if (isLong) {
      if (sl != null && sl > 0 && ltp <= sl) return 'Stop Loss Hit';
      if (tgt != null && tgt > 0 && ltp >= tgt) return 'Target Hit';
    } else {
      if (sl != null && sl > 0 && ltp >= sl) return 'Stop Loss Hit';
      if (tgt != null && tgt > 0 && ltp <= tgt) return 'Target Hit';
    }
    return null;
  }
}

/// Result of a write call: the server's message and whether it succeeded.
class PaperResult {
  final bool success;
  final String message;
  PaperResult(this.success, this.message);
}

class PaperTradingService {
  static const _base = '/paperTrading';

  static String _message(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
    }
    return fallback;
  }

  static Future<List<PaperInstrument>> search(String query) async {
    final res = await ApiClient.dio.get(
      '$_base/instruments/search',
      queryParameters: {'q': query},
    );
    return (res.data['data'] as List)
        .map((e) => PaperInstrument.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Today's OPEN and CLOSED positions.
  static Future<List<PaperPosition>> positions() async {
    final res = await ApiClient.dio.get('$_base/paper-trades/open');
    return (res.data['data'] as List)
        .map((e) => PaperPosition.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<PaperResult> placeOrder({
    required PaperInstrument instrument,
    required String direction,
    required int quantity, // already lots * lot size for F&O
    double? target,
    double? stopLoss,
  }) async {
    try {
      final res = await ApiClient.dio.post('$_base/paper-trades', data: {
        'symbol': instrument.symbol,
        'raw_symbol_id': instrument.rawSymbolId,
        'direction': direction,
        'lot_size': instrument.lotSize,
        'quantity': quantity,
        if (target != null) 'target': target,
        if (stopLoss != null) 'stop_loss': stopLoss,
      });
      return PaperResult(res.data['success'] == true, res.data['message']?.toString() ?? 'Order placed');
    } catch (e) {
      return PaperResult(false, _message(e, 'Failed to place order.'));
    }
  }

  static Future<PaperResult> close(int id, double closingPrice) async {
    try {
      final res = await ApiClient.dio.put(
        '$_base/paper-trades/$id/close',
        data: {'closing_price': closingPrice},
      );
      return PaperResult(res.data['success'] == true, res.data['message']?.toString() ?? 'Position closed');
    } catch (e) {
      return PaperResult(false, _message(e, 'Failed to close position.'));
    }
  }

  static Future<PaperResult> updateTargets(int id, double? stopLoss, double? target) async {
    try {
      final res = await ApiClient.dio.put(
        '$_base/paper-trades/$id/update-targets',
        data: {'stop_loss': stopLoss, 'target': target},
      );
      return PaperResult(res.data['success'] == true, res.data['message']?.toString() ?? 'Updated');
    } catch (e) {
      return PaperResult(false, _message(e, 'Failed to update.'));
    }
  }
}
