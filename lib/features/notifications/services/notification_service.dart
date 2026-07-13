import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> scheduleDocumentExpiryNotifications() async {
    final supabase = Supabase.instance.client;
    
    // Fetch documents expiring in the next 30 days
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    final response = await supabase
        .from('documents')
        .select('*')
        .lte('expiry_date', thirtyDaysFromNow.toIso8601String())
        .gte('expiry_date', DateTime.now().toIso8601String());

    final List docs = response as List;

    // Clear previous scheduled notifications
    await _notificationsPlugin.cancelAll();

    for (var i = 0; i < docs.length; i++) {
      final doc = docs[i];
      final expiryDate = DateTime.parse(doc['expiry_date']);
      final docType = doc['document_type'] ?? 'Document';
      
      // Schedule notification 7 days before expiry
      final scheduleDate = expiryDate.subtract(const Duration(days: 7));
      
      if (scheduleDate.isAfter(DateTime.now())) {
        await _notificationsPlugin.zonedSchedule(
          i, // unique ID
          'Document Expiring Soon',
          '$docType is expiring on \${expiryDate.toIso8601String().split('T')[0]}',
          tz.TZDateTime.from(scheduleDate, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'document_expiry_channel',
              'Document Expiry Alerts',
              channelDescription: 'Notifications for expiring documents',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }
}
