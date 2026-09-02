import 'api_client.dart';

class WatchlistService {
  static Future<Map<String, dynamic>> getWatchlist() async {
    try {
      final res = await ApiClient.dio.get('/watchlist');
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      return {'success': false, 'data': [], 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addStock(String symbol) async {
    try {
      final res = await ApiClient.dio.post('/watchlist', data: {'symbol': symbol});
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> removeStock(String symbol) async {
    try {
      final res = await ApiClient.dio.delete('/watchlist/$symbol');
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}