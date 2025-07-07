import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'app_log_entry.dart';

class DatabaseHelper {
  static const _databaseName = 'applog.db';
  static const _databaseVersion = 6;
  static const table = 'app_logs';

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    print('Initializing database at: $path'); // Debug log
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        print('Creating table: $table'); // Debug log
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
            notes TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print(
          'Upgrading database from version $oldVersion to $newVersion',
        ); // Debug log
        if (oldVersion < 4) {
          print('Adding icon column to table: $table'); // Debug log
          await db.execute('ALTER TABLE $table ADD icon BLOB');
        }
        if (oldVersion < 5) {
          print('Adding deletion_date column to table: $table'); // Debug log
          await db.execute('ALTER TABLE $table ADD deletion_date INTEGER');
        }
        if (oldVersion < 6) {
          print('Adding notes column to table: $table'); // Debug log
          await db.execute('ALTER TABLE $table ADD notes TEXT');
        }
        if (oldVersion < 3) {
          print('Dropping and recreating table: $table'); // Debug log
          await db.execute('DROP TABLE IF EXISTS $table');
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
              notes TEXT
            )
          ''');
        }
      },
    );
  }

  Future<void> insertAppLog(AppLogEntry entry) async {
    try {
      final db = await database;
      await db.insert(
        table,
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print(
        'Inserted: ${entry.appName}, Version: ${entry.versionName}, Install: ${entry.installDate}, Update: ${entry.updateDate}, Deletion: ${entry.deletionDate ?? 'N/A'}, Notes: ${entry.notes ?? 'N/A'}',
      ); // Debug log
    } catch (e) {
      print('Error inserting app log: $e'); // Debug log
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
        orderBy: 'update_date DESC',
      );
      print(
        'Retrieved ${maps.length} logs for package: $packageName',
      ); // Debug log
      return List.generate(maps.length, (i) => AppLogEntry.fromMap(maps[i]));
    } catch (e) {
      print('Error retrieving app logs: $e'); // Debug log
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
        WHERE id IN (
          SELECT MAX(id) FROM $table GROUP BY package_name
        )
        ORDER BY $orderBy
      ''');
      print(
        'Retrieved ${maps.length} latest app logs, sorted by $sortBy',
      ); // Debug log
      return List.generate(maps.length, (i) {
        final entry = AppLogEntry.fromMap(maps[i]);
        print(
          'App: ${entry.appName}, Update: ${entry.installDate}',
        ); // Debug log for update_date
        return entry;
      });
    } catch (e) {
      print('Error retrieving latest app logs: $e'); // Debug log
      rethrow;
    }
  }

  Future<List<AppLogEntry>> getUninstalledAppLogs(
    List<String> installedPackageNames, {
    String sortBy = 'update_date',
  }) async {
    try {
      final db = await database;
      final orderBy =
          sortBy == 'update_date'
              ? 'update_date DESC'
              : sortBy == 'deletion_date'
              ? 'deletion_date DESC'
              : 'app_name ASC';
      final maps = await db.rawQuery('''
        SELECT * FROM $table
        WHERE package_name NOT IN (${installedPackageNames.map((_) => '?').join(',')})
        AND id IN (
          SELECT MAX(id) FROM $table GROUP BY package_name
        )
        ORDER BY $orderBy
      ''', installedPackageNames);
      print(
        'Retrieved ${maps.length} logs for uninstalled apps, sorted by $sortBy',
      ); // Debug log
      return List.generate(maps.length, (i) {
        final entry = AppLogEntry.fromMap(maps[i]);
        print(
          'App: ${entry.appName}, Update: ${entry.updateDate}, Deletion: ${entry.deletionDate ?? 'N/A'}',
        ); // Debug log
        return entry;
      });
    } catch (e) {
      print('Error retrieving uninstalled app logs: $e'); // Debug log
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllAppLogs() async {
    try {
      final db = await database;
      final maps = await db.query(
        table,
        orderBy: 'update_date DESC, deletion_date DESC, install_date DESC',
      );
      print('Retrieved ${maps.length} total app logs for history'); // Debug log
      return maps;
    } catch (e) {
      print('Error retrieving all app logs: $e'); // Debug log
      rethrow;
    }
  }
}
