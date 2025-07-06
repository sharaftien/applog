import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import '../database/database_helper.dart';
import '../database/app_log_entry.dart';

class InstalledAppsPage extends StatefulWidget {
  const InstalledAppsPage({super.key});

  @override
  State<InstalledAppsPage> createState() => _InstalledAppsPageState();
}

class _InstalledAppsPageState extends State<InstalledAppsPage> {
  List<Application>? apps;
  final DatabaseHelper dbHelper = DatabaseHelper();
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInstalledApps();
  }

  Future<void> _fetchInstalledApps() async {
    try {
      print('Fetching installed apps...'); // Debug log
      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false, // Avoid memory issues
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      print('Fetched ${installedApps.length} apps'); // Debug log

      for (var app in installedApps) {
        final existingLogs = await dbHelper.getAppLogs(app.packageName);
        final currentVersion = app.versionName ?? 'N/A';
        final installTime = DateTime.now().millisecondsSinceEpoch;

        if (existingLogs.isEmpty ||
            existingLogs.first.versionName != currentVersion) {
          final entry = AppLogEntry(
            packageName: app.packageName,
            appName: app.appName,
            versionName: currentVersion,
            installDate: installTime,
          );
          await dbHelper.insertAppLog(entry);
        }
      }

      setState(() {
        installedApps.sort((a, b) => a.appName.compareTo(b.appName));
        apps = installedApps;
        errorMessage = null;
      });
    } catch (e) {
      print('Error fetching apps: $e'); // Debug log
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load apps: $e';
        });
      }
    }
  }

  void _showVersionHistory(BuildContext context, Application app) async {
    try {
      final logs = await dbHelper.getAppLogs(app.packageName);
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('${app.appName} Version History'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      log.installDate,
                    );
                    return ListTile(
                      title: Text('Version: ${log.versionName}'),
                      subtitle: Text(
                        'Installed: ${date.toString().split('.')[0]}',
                      ),
                    );
                  },
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
    } catch (e) {
      print('Error showing version history: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading version history: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (apps == null && errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Installed Apps')),
        body: Center(child: Text(errorMessage!)),
      );
    }

    if (apps == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Installed Apps')),
      body: ListView.builder(
        itemCount: apps!.length,
        itemBuilder: (context, index) {
          final app = apps![index];
          return ListTile(
            title: Text(app.appName),
            subtitle: Text(
              'Version: ${app.versionName ?? 'N/A'}\n'
              'Package: ${app.packageName}',
            ),
            onTap: () => _showVersionHistory(context, app),
          );
        },
      ),
    );
  }
}
