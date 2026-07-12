import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('syncledger.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // We create a sync_queue table to store offline actions.
    // actions could be: 'INSERT', 'UPDATE', 'DELETE'
    // table_name: 'invoices', 'cash_transactions', etc.
    // payload: JSON string of the data
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    
    // We can also create local caches for 'invoices', etc.
    await db.execute('''
      CREATE TABLE invoices_cache (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL
      )
    ''');
  }
  
  Future<void> queueAction(String action, String tableName, String payload, {String? recordId}) async {
    final db = await instance.database;
    await db.insert('sync_queue', {
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await instance.database;
    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Future<void> removeQueueItem(int id) async {
    final db = await instance.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearQueue() async {
    final db = await instance.database;
    await db.delete('sync_queue');
  }
}
