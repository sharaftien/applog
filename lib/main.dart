import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import 'database/app_log_entry.dart';
import 'screens/history_page.dart';
import 'screens/installed_apps_page.dart';
import 'screens/uninstalled_apps_page.dart';

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
              isFavorite: false,
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
              installDate: latestLog.installDate,
              updateDate: updateTime,
              icon: icon,
              deletionDate: null,
              notes: latestLog.notes,
              isFavorite: latestLog.isFavorite,
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
              isFavorite: latestLog.isFavorite,
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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.grey[800]!,
        colorScheme: ColorScheme.dark(
          primary: Colors.grey[800]!,
          onPrimary: Colors.white,
          surface: Colors.black,
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.grey[900],
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..addListener(() {
      setState(() {});
    });
    AppStateManager().fetchAndUpdateApps();
    AppStateManager().addListener(_onAppStateUpdate);
    if (AppStateManager().isFetching) {
      setState(() {
        isRefreshing = true;
        _controller?.repeat();
      });
    }
  }

  @override
  void dispose() {
    AppStateManager().removeListener(_onAppStateUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _onAppStateUpdate() {
    setState(() {
      isRefreshing = AppStateManager().isFetching;
      if (isRefreshing) {
        _controller?.repeat();
      } else {
        _controller?.stop();
      }
    });
  }

  Future<void> _fetchApps() async {
    setState(() {
      isRefreshing = true;
      _controller?.repeat();
    });
    try {
      await AppStateManager().fetchAndUpdateApps();
    } catch (e) {
      print('Error fetching apps: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to fetch apps: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
          _controller?.stop();
        });
      }
    }
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
        body: Stack(
          children: [
            const TabBarView(
              children: [
                HistoryPage(),
                InstalledAppsPage(),
                UninstalledAppsPage(),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: isRefreshing ? null : _fetchApps,
                backgroundColor:
                    isRefreshing ? Colors.grey[600] : Colors.grey[800],
                child: RotationTransition(
                  turns: Tween(begin: 0.0, end: 1.0).animate(_controller!),
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
