import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/app_log_entry.dart'; // Added missing import
import 'database/database_helper.dart';
import 'screens/history_page.dart';
import 'screens/installed_apps_page.dart';
import 'screens/uninstalled_apps_page.dart';

void main() {
  runApp(const MyApp());
}

class AppStateManager extends ChangeNotifier {
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isFetching = false;

  bool get isFetching => _isFetching;

  Future<void> fetchAndUpdateApps({bool isInitialLaunch = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    notifyListeners();
    try {
      print('Fetching apps for global update...');
      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final isFirstLaunch =
          isInitialLaunch || await _dbHelper.isDatabaseEmpty();
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
          newEntries.add(
            AppLogEntry(
              packageName: app.packageName,
              appName: app.appName,
              versionName: currentVersion,
              installVersionName: currentVersion,
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
          newEntries.add(
            AppLogEntry(
              packageName: app.packageName,
              appName: app.appName,
              versionName: currentVersion,
              installVersionName: latestLog.installVersionName,
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
              installVersionName: latestLog.installVersionName,
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
      notifyListeners();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Log',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.grey[900]!,
        colorScheme: ColorScheme.dark(
          primary: Colors.grey[900]!,
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
          color: Colors.grey[850],
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
        ),
        tabBarTheme: TabBarTheme(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          dividerColor: Colors.transparent,
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.grey[900],
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _checkAndFetchApps();
    AppStateManager().addListener(_onAppStateUpdate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchApps();
    }
  }

  Future<void> _checkAndFetchApps() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    await AppStateManager().fetchAndUpdateApps(isInitialLaunch: isFirstLaunch);
    if (isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
    }
    if (mounted && AppStateManager().isFetching) {
      setState(() {
        isRefreshing = true;
        _controller?.repeat();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          title: const Text('App Log'),
          titleSpacing: 16.0,
          toolbarHeight: 48.0,
          bottom: const TabBar(
            padding: EdgeInsets.only(top: 4.0, bottom: 4.0),
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
                    isRefreshing ? Colors.grey[600] : Colors.grey[900],
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
