import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../router/app_router.dart';

class NotificationService {
  static RealtimeChannel? _channel;

  static void initialize() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _channel = Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            final title = data['title'] ?? 'Notification';
            final message = data['message'] ?? '';
            
            _showNotification(title, message);
          },
        )
        .subscribe();
  }

  static void dispose() {
    _channel?.unsubscribe();
  }

  static void _showNotification(String title, String message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: Colors.blue.shade800,
      ),
    );
  }
}
