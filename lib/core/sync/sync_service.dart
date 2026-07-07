import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static const _queueKey = 'offline_mutation_queue';

  /// Adds a mutation to the offline queue
  static Future<void> queueMutation(Map<String, dynamic> data, {String? imagePath}) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey);
    List<dynamic> queue = queueJson != null ? jsonDecode(queueJson) : [];
    
    queue.add({
      'data': data,
      'imagePath': imagePath,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Attempts to sync all queued mutations to Supabase
  static Future<void> syncOfflineMutations() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey);
    if (queueJson == null) return;

    List<dynamic> queue = jsonDecode(queueJson);
    if (queue.isEmpty) return;

    debugPrint('Syncing ${queue.length} offline mutations...');
    
    List<dynamic> failedMutations = [];

    for (var item in queue) {
      try {
        final data = Map<String, dynamic>.from(item['data']);
        final imagePath = item['imagePath'] as String?;
        
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
        await Supabase.instance.client.from('invoices').insert(data);
      } catch (e) {
        debugPrint('Failed to sync mutation: $e');
        failedMutations.add(item); // Keep it in queue for next time
      }
    }

    // Update queue with only the failed items
    if (failedMutations.isEmpty) {
      await prefs.remove(_queueKey);
    } else {
      await prefs.setString(_queueKey, jsonEncode(failedMutations));
    }
  }
}
