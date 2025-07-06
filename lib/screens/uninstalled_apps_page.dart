import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../database/app_log_entry.dart';

class UninstalledAppsPage extends StatefulWidget {
  const UninstalledAppsPage({super.key});

  @override
  State<UninstalledAppsPage> createState() => _UninstalledAppsPageState();
}

class _UninstalledAppsPageState extends State<UninstalledAppsPage>
    with SingleTickerProviderStateMixin {
  List<AppLogEntry>? uninstalledApps;
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
    _fetchUninstalledApps();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _fetchUninstalledApps() async {
    setState(() {
      isRefreshing = true;
      _refreshController.repeat();
    });
    try {
      print('Fetching uninstalled apps...'); // Debug log
      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true, // Changed to true to cache icons
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      final installedPackageNames =
          installedApps.map((app) => app.packageName).toList();
      // Cache icons for installed apps to ensure future uninstalled apps have icons
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
      final logs = await dbHelper.getUninstalledAppLogs(installedPackageNames);
      print('Fetched ${logs.length} uninstalled app logs'); // Debug log

      if (mounted) {
        setState(() {
          uninstalledApps = logs;
          errorMessage = null;
          isRefreshing = false;
          _refreshController.stop();
        });
      }
    } catch (e) {
      print('Error fetching uninstalled apps: $e'); // Debug log
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load uninstalled apps: $e';
          isRefreshing = false;
          _refreshController.stop();
        });
      }
    }
  }

  void _showVersionHistory(BuildContext context, AppLogEntry log) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${log.appName} Version History'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text('Version: ${log.versionName}'),
                    subtitle: Text(
                      'Updated: ${DateFormat('dd/MM/yy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(log.updateDate))}',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uninstalledApps == null && errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Uninstalled Apps')),
        body: Center(child: Text(errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uninstalled Apps'),
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
            onPressed: isRefreshing ? null : _fetchUninstalledApps,
          ),
        ],
      ),
      body:
          uninstalledApps == null && isRefreshing
              ? const Center(child: CircularProgressIndicator())
              : uninstalledApps!.isEmpty
              ? const Center(child: Text('No uninstalled apps found'))
              : ListView.builder(
                itemCount: uninstalledApps!.length,
                itemBuilder: (context, index) {
                  final log = uninstalledApps![index];
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
                      'Version: ${log.versionName}\n'
                      'Package: ${log.packageName}',
                    ),
                    onTap: () => _showVersionHistory(context, log),
                  );
                },
              ),
    );
  }
}
