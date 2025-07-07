import 'package:flutter/material.dart';
import 'screens/history_page.dart';
import 'screens/installed_apps_page.dart';
import 'screens/uninstalled_apps_page.dart';
import 'package:device_apps/device_apps.dart';
import 'database/app_log_entry.dart';
import 'database/database_helper.dart';

void main() {
  runApp(const MyApp());
}

class AppStateManager {
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isFetching = false;
  final List<Function> _listeners = [];

  bool get isFetching => _isFetching;

  void addListener(Function callback) {
    _listeners.add(callback);
  }

  void removeListener(Function callback) {
    _listeners.remove(callback);
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  Future<void> fetchAndUpdateApps() async {
    if (_isFetching) return;
    _isFetching = true;
    _notifyListeners();
    try {
      print('Fetching apps for global update...');
      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final isFirstLaunch = await _dbHelper.isDatabaseEmpty();
      final allLogs = isFirstLaunch ? [] : await _dbHelper.getAllAppLogs();
      final installedPackageNames =
          installedApps.map((app) => app.packageName).toList();

      final Map<String, List<AppLogEntry>> existingMap = {};
      for (var log in allLogs) {
        final entry = AppLogEntry.fromMap(log);
        existingMap.putIfAbsent(entry.packageName, () => []).add(entry);
      }
      final List<AppLogEntry> newEntries = [];

      // Handle installed/updated apps
      for (var app in installedApps) {
        final currentVersion = app.versionName ?? 'N/A';
        final installTime = app.installTimeMillis ?? currentTime;
        final updateTime = app.updateTimeMillis ?? currentTime;
        final icon = app is ApplicationWithIcon ? app.icon : null;

        final existingLogs = existingMap[app.packageName] ?? [];
        final latestLog =
            existingLogs.isNotEmpty
                ? existingLogs.reduce(
                  (a, b) => (a.id ?? 0) > (b.id ?? 0) ? a : b,
                )
                : null;

        if (isFirstLaunch || existingLogs.isEmpty) {
          // New installation
          newEntries.add(
            AppLogEntry(
              packageName: app.packageName,
              appName: app.appName,
              versionName: currentVersion,
              installDate: installTime,
              updateDate: installTime,
              icon: icon,
              deletionDate: null,
              notes: null,
            ),
          );
        } else if (latestLog!.versionName != currentVersion ||
            latestLog.updateDate != updateTime) {
          // Update detected
          newEntries.add(
            AppLogEntry(
              packageName: app.packageName,
              appName: app.appName,
              versionName: currentVersion,
              installDate:
                  latestLog.installDate, // Retain original install date
              updateDate: updateTime,
              icon: icon,
              deletionDate: null,
              notes: latestLog.notes,
            ),
          );
        }
      }

      // Handle deleted apps
      for (var log in existingMap.entries) {
        final latestLog = log.value.reduce(
          (a, b) => (a.id ?? 0) > (b.id ?? 0) ? a : b,
        );
        if (!installedPackageNames.contains(log.key) &&
            latestLog.deletionDate == null) {
          newEntries.add(
            AppLogEntry(
              packageName: log.key,
              appName: latestLog.appName,
              versionName: latestLog.versionName,
              installDate: latestLog.installDate,
              updateDate: latestLog.updateDate,
              icon: latestLog.icon,
              deletionDate: currentTime,
              notes: latestLog.notes,
            ),
          );
        }
      }

      if (newEntries.isNotEmpty) {
        await _dbHelper.insertAppLogs(newEntries);
      }
      await _dbHelper.setLastSyncTime(currentTime);
    } catch (e) {
      print('Error fetching apps: $e');
      rethrow;
    } finally {
      _isFetching = false;
      _notifyListeners();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppLog',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    super.initState();
    AppStateManager().fetchAndUpdateApps();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AppLog'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'History'),
              Tab(text: 'Installed'),
              Tab(text: 'Uninstalled'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [HistoryPage(), InstalledAppsPage(), UninstalledAppsPage()],
        ),
      ),
    );
  }
}
