import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';

class SyncService {
  /// Adds a mutation to the offline SQLite queue
  static Future<void> queueMutation(Map<String, dynamic> data, {String? imagePath, String tableName = 'invoices'}) async {
    final payload = {
      'data': data,
      'imagePath': imagePath,
    };
    
    await DatabaseHelper.instance.queueAction(
      'INSERT', 
      tableName, 
      jsonEncode(payload),
    );
  }

  /// Attempts to sync all queued mutations to Supabase
  static Future<void> syncOfflineMutations() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    final queue = await DatabaseHelper.instance.getSyncQueue();
    if (queue.isEmpty) return;

    debugPrint('Syncing ${queue.length} offline mutations...');

    for (var item in queue) {
      final id = item['id'] as int;
      final action = item['action'] as String;
      final tableName = item['table_name'] as String;
      final payloadData = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
      
      try {
        final data = Map<String, dynamic>.from(payloadData['data']);
        final imagePath = payloadData['imagePath'] as String?;

        if (action == 'INSERT') {
          // 1. Upload image if exists
          if (imagePath != null) {
            final file = File(imagePath);
            if (await file.exists()) {
              final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
              await Supabase.instance.client.storage.from('receipts').upload(fileName, file);
              data['document_url'] = Supabase.instance.client.storage.from('receipts').getPublicUrl(fileName);
            }
          }
          
          // 2. Insert to Supabase
          await Supabase.instance.client.from(tableName).insert(data);
        } else if (action == 'UPDATE') {
           final recordId = item['record_id'] as String;
           await Supabase.instance.client.from(tableName).update(data).eq('id', recordId);
        } else if (action == 'DELETE') {
           final recordId = item['record_id'] as String;
           await Supabase.instance.client.from(tableName).delete().eq('id', recordId);
        }
        
        // Remove from local queue if successful
        await DatabaseHelper.instance.removeQueueItem(id);
      } catch (e) {
        debugPrint('Failed to sync mutation: $e');
        // It stays in the queue to be retried
      }
    }
  }
}
