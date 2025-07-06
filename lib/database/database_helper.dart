import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'app_log_entry.dart';

class DatabaseHelper {
  static const _databaseName = 'applog.db';
  static const _databaseVersion = 3; // Incremented for update_date
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
            update_date INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print(
          'Upgrading database from version $oldVersion to $newVersion',
        ); // Debug log
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
              update_date INTEGER NOT NULL
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
        'Inserted: ${entry.appName}, Version: ${entry.versionName}, Install: ${entry.installDate}, Update: ${entry.updateDate}',
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
}
