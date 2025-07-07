import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../database/database_helper.dart';
import '../database/app_log_entry.dart';
import 'app_details_page.dart';

class UninstalledAppsPage extends StatefulWidget {
  const UninstalledAppsPage({super.key});

  @override
  State<UninstalledAppsPage> createState() => _UninstalledAppsPageState();
}

class _UninstalledAppsPageState extends State<UninstalledAppsPage>
    with SingleTickerProviderStateMixin {
  List<AppLogEntry>? uninstalledApps;
  List<AppLogEntry>? cachedApps;
  List<AppLogEntry> displayApps = [];
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
    _loadCachedUninstalledApps();
    _fetchUninstalledApps();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _sortDisplayApps() {
    setState(() {
      displayApps.sort((a, b) {
        if (sortBy == 'app_name') {
          return a.appName.compareTo(b.appName);
        } else if (sortBy == 'deletion_date') {
          return (b.deletionDate ?? 0).compareTo(a.deletionDate ?? 0);
        } else {
          return b.updateDate.compareTo(a.updateDate);
        }
      });
    });
  }

  Future<void> _loadCachedUninstalledApps() async {
    try {
      print('Loading cached uninstalled apps...');
      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      final installedPackageNames =
          installedApps.map((app) => app.packageName).toList();
      final logs = await dbHelper.getUninstalledAppLogs(
        installedPackageNames,
        sortBy: sortBy,
      );
      if (mounted) {
        setState(() {
          cachedApps = logs;
          displayApps = logs;
          errorMessage = null;
        });
        _sortDisplayApps();
      }
    } catch (e) {
      print('Error loading cached uninstalled apps: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load cached uninstalled apps: $e';
        });
      }
    }
  }

  Future<void> _fetchUninstalledApps() async {
    setState(() {
      isRefreshing = true;
      _refreshController.repeat();
    });
    try {
      print('Fetching uninstalled apps...');
      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      final installedPackageNames =
          installedApps.map((app) => app.packageName).toList();
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

      final uninstalledLogs = await dbHelper.getUninstalledAppLogs(
        installedPackageNames,
        sortBy: sortBy,
      );
      for (var log in uninstalledLogs) {
        if (log.deletionDate == null) {
          final updatedLog = AppLogEntry(
            id: log.id,
            packageName: log.packageName,
            appName: log.appName,
            versionName: log.versionName,
            installDate: log.installDate,
            updateDate: log.updateDate,
            icon: log.icon,
            deletionDate: currentTime,
            notes: log.notes,
          );
          await dbHelper.insertAppLog(updatedLog);
        }
      }

      print(
        'Fetched ${uninstalledLogs.length} uninstalled app logs, sorted by $sortBy',
      );

      if (mounted) {
        setState(() {
          uninstalledApps = uninstalledLogs;
          cachedApps = null;
          displayApps = uninstalledLogs;
          errorMessage = null;
          isRefreshing = false;
          _refreshController.stop();
        });
        _sortDisplayApps();
      }
    } catch (e) {
      print('Error fetching uninstalled apps: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load uninstalled apps: $e';
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
        appBar: AppBar(title: const Text('Uninstalled Apps')),
        body: Center(child: Text(errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uninstalled Apps'),
        actions: [
          DropdownButton<String>(
            value: sortBy,
            items: const [
              DropdownMenuItem(value: 'app_name', child: Text('Name')),
              DropdownMenuItem(
                value: 'update_date',
                child: Text('Last Update'),
              ),
              DropdownMenuItem(
                value: 'deletion_date',
                child: Text('Deletion Date'),
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
            onPressed: isRefreshing ? null : _fetchUninstalledApps,
          ),
        ],
      ),
      body:
          displayApps.isEmpty && isRefreshing
              ? const Center(child: CircularProgressIndicator())
              : displayApps.isEmpty
              ? const Center(child: Text('No uninstalled apps found'))
              : ListView.builder(
                itemCount: displayApps.length,
                itemBuilder: (context, index) {
                  final log = displayApps[index];
                  return ListTile(
                    leading:
                        log.icon != null
                            ? Image.memory(
                              log.icon!,
                              width: 40,
                              height: 40,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      const Icon(Icons.delete, size: 40),
                            )
                            : const Icon(Icons.delete, size: 40),
                    title: Text(log.appName),
                    subtitle: Text(
                      'Version: ${log.versionName}\nDeleted ${_formatRelativeTime(log.deletionDate ?? DateTime.now().millisecondsSinceEpoch)}',
                    ),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AppDetailsPage(
                                  log: log,
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
