import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Bumped whenever notifications are read or the list changes, so the bell
/// badge refetches straight away instead of waiting for its 30s poll.
final ValueNotifier<int> notificationsChanged = ValueNotifier(0);

class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String? type;
  final String? link;
  final DateTime? createdAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.type,
    this.link,
    this.createdAt,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString(),
      link: json['link']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
      isRead: json['is_read'] == true,
    );
  }
}

class NotificationPage {
  final List<NotificationItem> items;
  final bool hasMore;
  final int unreadCount;

  NotificationPage(this.items, this.hasMore, this.unreadCount);
}

class NotificationsService {
  static Future<NotificationPage> fetch({
    int page = 1,
    int limit = 15,
    bool unreadOnly = false,
  }) async {
    final res = await ApiClient.dio.get(
      '/notifications',
      queryParameters: {'page': page, 'limit': limit, 'unread': unreadOnly},
    );
    final data = res.data as Map;
    final items = (data['data'] as List)
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return NotificationPage(
      items,
      data['hasMore'] == true,
      (data['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<void> markRead(int id) async {
    await ApiClient.dio.put('/notifications/$id/read');
    notificationsChanged.value++;
  }

  static Future<void> markAllRead() async {
    await ApiClient.dio.put('/notifications/read-all');
    notificationsChanged.value++;
  }
}
