import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added missing import
import 'app_log_entry.dart';

class DatabaseHelper {
  static const _databaseName = 'applog.db';
  static const _databaseVersion = 9;
  static const table = 'app_logs';
  static Database? _database;
  static final Map<String, dynamic> _cache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = path.join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) {
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA synchronous=NORMAL');
        db.execute('PRAGMA cache_size=10000');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        version_name TEXT NOT NULL,
        install_version_name TEXT NOT NULL,
        install_date INTEGER NOT NULL,
        update_date INTEGER NOT NULL,
        icon BLOB,
        deletion_date INTEGER,
        notes TEXT,
        is_favorite INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_package_name ON $table(package_name)');
    await db.execute('CREATE INDEX idx_deletion_date ON $table(deletion_date)');
    await db.execute('CREATE INDEX idx_update_date ON $table(update_date)');
    await db.execute('CREATE INDEX idx_install_date ON $table(install_date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE $table ADD install_version_name TEXT NOT NULL DEFAULT ""',
      );
      await db.execute(
        'UPDATE $table SET install_version_name = version_name WHERE install_version_name = ""',
      );
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE $table ADD icon BLOB');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE $table ADD deletion_date INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE $table ADD notes TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('CREATE INDEX idx_package_name ON $table(package_name)');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE $table ADD is_favorite INTEGER DEFAULT 0');
    }
    if (oldVersion < 9) {
      await db.execute(
        'CREATE INDEX idx_deletion_date ON $table(deletion_date)',
      );
      await db.execute('CREATE INDEX idx_update_date ON $table(update_date)');
      await db.execute('CREATE INDEX idx_install_date ON $table(install_date)');
    }
  }

  bool _isCacheValid(String key) {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
  }

  void _updateCache(String key, dynamic data) {
    _cache[key] = data;
    _lastCacheUpdate = DateTime.now();
  }

  Future<bool> isDatabaseEmpty() async {
    final db = await database;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $table'),
        ) ??
        0;
    return count == 0;
  }

  Future<void> insertAppLogs(List<AppLogEntry> entries) async {
    if (entries.isEmpty) return;
    try {
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var entry in entries) {
          batch.insert(
            table,
            entry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        await batch.commit(noResult: true);
      });
      _cache.clear();
    } catch (e) {
      print('Error inserting app logs: $e');
      rethrow;
    }
  }

  Future<void> updateAppLog(AppLogEntry entry) async {
    try {
      final db = await database;
      await db.update(
        table,
        {'notes': entry.notes, 'is_favorite': entry.isFavorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      _cache.clear();
    } catch (e) {
      print('Error updating app log: $e');
      rethrow;
    }
  }

  Future<List<AppLogEntry>> getAppLogs(String packageName) async {
    final cacheKey = 'app_logs_$packageName';
    if (_isCacheValid(cacheKey) && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<AppLogEntry>;
    }
    try {
      final db = await database;
      final maps = await db.query(
        table,
        where: 'package_name = ?',
        whereArgs: [packageName],
        orderBy: 'COALESCE(deletion_date, update_date, install_date) DESC',
      );
      final result = maps.map((map) => AppLogEntry.fromMap(map)).toList();
      _updateCache(cacheKey, result);
      return result;
    } catch (e) {
      print('Error retrieving app logs: $e');
      rethrow;
    }
  }

  Future<List<AppLogEntry>> getLatestAppLogs({
    String sortBy = 'update_date',
  }) async {
    final cacheKey = 'latest_apps_$sortBy';
    if (_isCacheValid(cacheKey) && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<AppLogEntry>;
    }
    try {
      final db = await database;
      final orderBy =
          sortBy == 'update_date' ? 'update_date DESC' : 'app_name ASC';
      final maps = await db.rawQuery('''
        SELECT * FROM $table
        WHERE deletion_date IS NULL
        AND id IN (
          SELECT MAX(id) FROM $table 
          WHERE deletion_date IS NULL 
          GROUP BY package_name
        )
        ORDER BY $orderBy
      ''');
      final result = maps.map((map) => AppLogEntry.fromMap(map)).toList();
      _updateCache(cacheKey, result);
      return result;
    } catch (e) {
      print('Error retrieving latest app logs: $e');
      rethrow;
    }
  }

  Future<List<AppLogEntry>> getUninstalledAppLogs(
    List<String> installedPackageNames, {
    String sortBy = 'deletion_date',
  }) async {
    final cacheKey = 'uninstalled_apps_$sortBy';
    if (_isCacheValid(cacheKey) && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<AppLogEntry>;
    }
    try {
      final db = await database;
      final orderBy =
          sortBy == 'deletion_date'
              ? 'deletion_date DESC'
              : sortBy == 'update_date'
              ? 'update_date DESC'
              : 'app_name ASC';
      final maps = await db.rawQuery('''
        SELECT * FROM $table
        WHERE deletion_date IS NOT NULL
        AND id IN (
          SELECT MAX(id) FROM $table
          WHERE deletion_date IS NOT NULL
          GROUP BY package_name
        )
        ORDER BY $orderBy
      ''');
      final result = maps.map((map) => AppLogEntry.fromMap(map)).toList();
      _updateCache(cacheKey, result);
      return result;
    } catch (e) {
      print('Error retrieving uninstalled app logs: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllAppLogs() async {
    final cacheKey = 'all_app_logs';
    if (_isCacheValid(cacheKey) && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<Map<String, dynamic>>;
    }
    try {
      final db = await database;
      final maps = await db.query(
        table,
        orderBy:
            'COALESCE(deletion_date, update_date, install_date) DESC, id DESC',
      );
      _updateCache(cacheKey, maps);
      return maps;
    } catch (e) {
      print('Error retrieving all app logs: $e');
      rethrow;
    }
  }

  Future<void> setLastSyncTime(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sync_time', timestamp);
  }

  Future<int?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_sync_time');
  }
}
