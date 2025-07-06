import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../database/app_log_entry.dart';
import 'app_details_page.dart';

class InstalledAppsPage extends StatefulWidget {
  const InstalledAppsPage({super.key});

  @override
  State<InstalledAppsPage> createState() => _InstalledAppsPageState();
}

class _InstalledAppsPageState extends State<InstalledAppsPage>
    with SingleTickerProviderStateMixin {
  List<Application>? apps;
  List<AppLogEntry>? cachedApps;
  final DatabaseHelper dbHelper = DatabaseHelper();
  String? errorMessage;
  bool isRefreshing = false;
  late AnimationController _refreshController;
  late Animation<double> _refreshAnimation;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _refreshAnimation = Tween<double>(
      begin: 0,
      end: 360,
    ).animate(_refreshController);
    _loadCachedApps();
    _fetchInstalledApps();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedApps() async {
    try {
      print('Loading cached apps...'); // Debug log
      final logs = await dbHelper.getLatestAppLogs();
      if (mounted) {
        setState(() {
          cachedApps = logs;
          errorMessage = null;
        });
      }
    } catch (e) {
      print('Error loading cached apps: $e'); // Debug log
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load cached apps: $e';
        });
      }
    }
  }

  Future<void> _fetchInstalledApps() async {
    setState(() {
      isRefreshing = true;
      _refreshController.repeat();
    });
    try {
      print('Fetching installed apps...'); // Debug log
      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      print('Fetched ${installedApps.length} apps'); // Debug log

      for (var app in installedApps) {
        final existingLogs = await dbHelper.getAppLogs(app.packageName);
        final currentVersion = app.versionName ?? 'N/A';
        final installTime =
            (app is ApplicationWithIcon)
                ? app.installTimeMillis ?? DateTime.now().millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch;
        final updateTime =
            (app is ApplicationWithIcon)
                ? app.updateTimeMillis ?? DateTime.now().millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch;
        final icon = (app is ApplicationWithIcon) ? app.icon : null;

        if (existingLogs.isEmpty ||
            existingLogs.first.versionName != currentVersion) {
          final entry = AppLogEntry(
            packageName: app.packageName,
            appName: app.appName,
            versionName: currentVersion,
            installDate: installTime,
            updateDate: updateTime,
            icon: icon,
          );
          await dbHelper.insertAppLog(entry);
        }
      }

      if (mounted) {
        setState(() {
          installedApps.sort((a, b) => a.appName.compareTo(b.appName));
          apps = installedApps;
          cachedApps = null;
          errorMessage = null;
          isRefreshing = false;
          _refreshController.stop();
        });
      }
    } catch (e) {
      print('Error fetching apps: $e'); // Debug log
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load apps: $e';
          isRefreshing = false;
          _refreshController.stop();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (apps == null && cachedApps == null && errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Installed Apps')),
        body: Center(child: Text(errorMessage!)),
      );
    }

    final displayApps = apps ?? cachedApps ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Installed Apps'),
        actions: [
          IconButton(
            icon: AnimatedBuilder(
              animation: _refreshAnimation,
              builder:
                  (context, child) => Transform.rotate(
                    angle: _refreshAnimation.value * 3.14159 / 180,
                    child: Icon(
                      isRefreshing ? Icons.refresh : Icons.refresh_outlined,
                    ),
                  ),
            ),
            onPressed: isRefreshing ? null : _fetchInstalledApps,
          ),
        ],
      ),
      body:
          displayApps.isEmpty && !isRefreshing
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: displayApps.length,
                itemBuilder: (context, index) {
                  final app = apps != null ? apps![index] : null;
                  final log = cachedApps != null ? cachedApps![index] : null;
                  return ListTile(
                    leading:
                        app is ApplicationWithIcon
                            ? Image.memory(
                              app.icon,
                              width: 40,
                              height: 40,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      const Icon(Icons.error),
                            )
                            : log?.icon != null
                            ? Image.memory(
                              log!.icon!,
                              width: 40,
                              height: 40,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      const Icon(Icons.error),
                            )
                            : const Icon(Icons.apps, size: 40),
                    title: Text(app?.appName ?? log!.appName),
                    subtitle: Text(
                      'Version: ${app?.versionName ?? log!.versionName}\n'
                      'Package: ${app?.packageName ?? log!.packageName}',
                    ),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AppDetailsPage(
                                  app: app,
                                  log:
                                      log ??
                                      AppLogEntry(
                                        packageName: app!.packageName,
                                        appName: app.appName,
                                        versionName: app.versionName ?? 'N/A',
                                        installDate:
                                            DateTime.now()
                                                .millisecondsSinceEpoch,
                                        updateDate:
                                            DateTime.now()
                                                .millisecondsSinceEpoch,
                                        icon:
                                            app is ApplicationWithIcon
                                                ? app.icon
                                                : null,
                                      ),
                                  dbHelper: dbHelper,
                                ),
                          ),
                        ),
                  );
                },
              ),
    );
  }
}
