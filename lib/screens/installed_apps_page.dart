import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
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
  List<Object> displayApps = [];
  final DatabaseHelper dbHelper = DatabaseHelper();
  String? errorMessage;
  bool isRefreshing = false;
  late AnimationController _refreshController;
  late Animation<double> _refreshAnimation;
  String sortBy = 'update_date';

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
    _fetchApps();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _sortDisplayApps() {
    setState(() {
      displayApps.sort((a, b) {
        final aIsApp = a is Application;
        final bIsApp = b is Application;
        final aName =
            aIsApp ? (a as Application).appName : (a as AppLogEntry).appName;
        final bName =
            bIsApp ? (b as Application).appName : (b as AppLogEntry).appName;
        final aUpdate =
            aIsApp
                ? (a as Application).updateTimeMillis ?? 0
                : (a as AppLogEntry).updateDate;
        final bUpdate =
            bIsApp
                ? (b as Application).updateTimeMillis ?? 0
                : (b as AppLogEntry).updateDate;

        if (sortBy == 'app_name') {
          return aName.compareTo(bName);
        } else {
          return bUpdate.compareTo(aUpdate);
        }
      });
    });
  }

  Future<void> _loadCachedApps() async {
    try {
      print('Loading cached apps...');
      final logs = await dbHelper.getLatestAppLogs(sortBy: sortBy);
      if (mounted) {
        setState(() {
          cachedApps = logs;
          displayApps = logs;
          errorMessage = null;
        });
        _sortDisplayApps();
      }
    } catch (e) {
      print('Error loading cached apps: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load cached apps: $e';
        });
      }
    }
  }

  Future<void> _fetchApps() async {
    setState(() {
      isRefreshing = true;
      _refreshController.repeat();
    });
    try {
      print('Fetching installed apps...');
      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      for (var app in installedApps) {
        final existingLogs = await dbHelper.getAppLogs(app.packageName);
        final currentVersion = app.versionName ?? 'N/A';
        final installTime =
            (app is ApplicationWithIcon)
                ? app.installTimeMillis ?? currentTime
                : currentTime;
        final updateTime =
            (app is ApplicationWithIcon)
                ? app.updateTimeMillis ?? currentTime
                : currentTime;
        final icon = (app is ApplicationWithIcon) ? app.icon : null;

        print('App: ${app.appName}, UpdateTime: $updateTime');

        if (existingLogs.isEmpty ||
            existingLogs.first.versionName != currentVersion) {
          final entry = AppLogEntry(
            packageName: app.packageName,
            appName: app.appName,
            versionName: currentVersion,
            installDate: installTime,
            updateDate: updateTime,
            icon: icon,
            deletionDate: null,
            notes: existingLogs.isNotEmpty ? existingLogs.first.notes : null,
          );
          await dbHelper.insertAppLog(entry);
        }
      }

      final logs = await dbHelper.getLatestAppLogs(sortBy: sortBy);
      print('Fetched ${installedApps.length} apps');

      if (mounted) {
        setState(() {
          apps = installedApps;
          cachedApps = null;
          displayApps = installedApps;
          errorMessage = null;
          isRefreshing = false;
          _refreshController.stop();
        });
        _sortDisplayApps();
      }
    } catch (e) {
      print('Error fetching apps: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load apps: $e';
          isRefreshing = false;
          _refreshController.stop();
        });
      }
    }
  }

  String _formatRelativeTime(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60)
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24)
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 30)
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (displayApps.isEmpty && errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Installed Apps')),
        body: Center(child: Text(errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Installed Apps'),
        actions: [
          DropdownButton<String>(
            value: sortBy,
            items: const [
              DropdownMenuItem(value: 'app_name', child: Text('Name')),
              DropdownMenuItem(
                value: 'update_date',
                child: Text('Last Update'),
              ),
            ],
            onChanged: (value) {
              if (value != null && value != sortBy) {
                setState(() {
                  sortBy = value;
                });
                _sortDisplayApps();
              }
            },
          ),
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
            onPressed: isRefreshing ? null : _fetchApps,
          ),
        ],
      ),
      body:
          displayApps.isEmpty && isRefreshing
              ? const Center(child: CircularProgressIndicator())
              : displayApps.isEmpty
              ? const Center(child: Text('No installed apps found'))
              : ListView.builder(
                itemCount: displayApps.length,
                itemBuilder: (context, index) {
                  final app = displayApps[index];
                  final isApp = app is Application;
                  final icon =
                      isApp &&
                              app is ApplicationWithIcon &&
                              (app as ApplicationWithIcon).icon.isNotEmpty
                          ? Image.memory(
                            (app as ApplicationWithIcon).icon,
                            width: 40,
                            height: 40,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    const Icon(Icons.apps, size: 40),
                          )
                          : app is AppLogEntry &&
                              (app as AppLogEntry).icon != null
                          ? Image.memory(
                            (app as AppLogEntry).icon!,
                            width: 40,
                            height: 40,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    const Icon(Icons.apps, size: 40),
                          )
                          : const Icon(Icons.apps, size: 40);
                  final appName =
                      isApp
                          ? (app as Application).appName
                          : (app as AppLogEntry).appName;
                  final versionName =
                      isApp
                          ? (app as Application).versionName ?? 'N/A'
                          : (app as AppLogEntry).versionName;
                  final updateTime =
                      isApp
                          ? (app as Application).updateTimeMillis ?? 0
                          : (app as AppLogEntry).updateDate;

                  return ListTile(
                    leading: icon,
                    title: Text(appName),
                    subtitle: Text(
                      'Version: $versionName\nLast updated ${_formatRelativeTime(updateTime)}',
                    ),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AppDetailsPage(
                                  app: isApp ? app as Application : null,
                                  log:
                                      isApp
                                          ? AppLogEntry(
                                            packageName:
                                                (app as Application)
                                                    .packageName,
                                            appName:
                                                (app as Application).appName,
                                            versionName:
                                                (app as Application)
                                                    .versionName ??
                                                'N/A',
                                            installDate:
                                                (app as Application)
                                                    .installTimeMillis ??
                                                DateTime.now()
                                                    .millisecondsSinceEpoch,
                                            updateDate:
                                                (app as Application)
                                                    .updateTimeMillis ??
                                                DateTime.now()
                                                    .millisecondsSinceEpoch,
                                            icon:
                                                app is ApplicationWithIcon
                                                    ? (app as ApplicationWithIcon)
                                                        .icon
                                                    : null,
                                          )
                                          : app as AppLogEntry,
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
