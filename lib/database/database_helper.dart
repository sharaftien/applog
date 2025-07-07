import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_log_entry.dart';

class DatabaseHelper {
  static const _databaseName = 'applog.db';
  static const _databaseVersion = 8;
  static const table = 'app_logs';

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = path.join(await getDatabasesPath(), _databaseName);
    print('Initializing database at: $dbPath');
    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        print('Creating table: $table');
        await db.execute('''
          CREATE TABLE $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL,
            app_name TEXT NOT NULL,
            version_name TEXT NOT NULL,
            install_date INTEGER NOT NULL,
            update_date INTEGER NOT NULL,
            icon BLOB,
            deletion_date INTEGER,
            notes TEXT,
            is_favorite INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_package_name ON $table(package_name)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Upgrading database from version $oldVersion to $newVersion');
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
          await db.execute(
            'CREATE INDEX idx_package_name ON $table(package_name)',
          );
        }
        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE $table ADD is_favorite INTEGER DEFAULT 0',
          );
        }
      },
    );
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
    try {
      final db = await database;
      final batch = db.batch();
      for (var entry in entries) {
        batch.insert(
          table,
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        print(
          'Inserted: ${entry.appName}, Version: ${entry.versionName}, Install: ${entry.installDate}, Update: ${entry.updateDate}, Deletion: ${entry.deletionDate ?? 'N/A'}, Notes: ${entry.notes ?? 'N/A'}, Favorite: ${entry.isFavorite}',
        );
      }
      await batch.commit();
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
      print(
        'Updated notes and favorite for ${entry.appName}, Version: ${entry.versionName}, ID: ${entry.id}, Favorite: ${entry.isFavorite}',
      );
    } catch (e) {
      print('Error updating app log: $e');
      rethrow;
    }
  }

  Future<List<AppLogEntry>> getAppLogs(String packageName) async {
    try {
      final db = await database;
      final maps = await db.query(
        table,
        where: 'package_name = ?',
        whereArgs: [packageName],
        orderBy: 'id DESC',
      );
      print('Retrieved ${maps.length} logs for package: $packageName');
      return List.generate(maps.length, (i) => AppLogEntry.fromMap(maps[i]));
    } catch (e) {
      print('Error retrieving app logs: $e');
      rethrow;
    }
  }

  Future<List<AppLogEntry>> getLatestAppLogs({
    String sortBy = 'update_date',
  }) async {
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
      print('Retrieved ${maps.length} latest app logs, sorted by $sortBy');
      return List.generate(maps.length, (i) => AppLogEntry.fromMap(maps[i]));
    } catch (e) {
      print('Error retrieving latest app logs: $e');
      rethrow;
    }
  }

  Future<List<AppLogEntry>> getUninstalledAppLogs(
    List<String> installedPackageNames, {
    String sortBy = 'deletion_date',
  }) async {
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
      print(
        'Retrieved ${maps.length} logs for uninstalled apps, sorted by $sortBy',
      );
      return List.generate(maps.length, (i) => AppLogEntry.fromMap(maps[i]));
    } catch (e) {
      print('Error retrieving uninstalled app logs: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllAppLogs() async {
    try {
      final db = await database;
      final maps = await db.query(
        table,
        orderBy:
            'COALESCE(deletion_date, update_date, install_date) DESC, id DESC',
      );
      print('Retrieved ${maps.length} total app logs for history');
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
