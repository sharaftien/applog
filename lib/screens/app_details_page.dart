import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:intl/intl.dart';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';

class AppDetailsPage extends StatelessWidget {
  final Application? app; // Null for uninstalled apps
  final AppLogEntry log; // Used for uninstalled apps or fallback
  final DatabaseHelper dbHelper; // Injected for database access

  const AppDetailsPage({
    super.key,
    this.app,
    required this.log,
    required this.dbHelper,
  });

  @override
  Widget build(BuildContext context) {
    final isInstalled = app != null;
    final icon =
        isInstalled && app is ApplicationWithIcon
            ? (app as ApplicationWithIcon).icon
            : log.icon;
    final appName = isInstalled ? app!.appName : log.appName;
    final packageName = isInstalled ? app!.packageName : log.packageName;
    final versionName =
        isInstalled ? app!.versionName ?? 'N/A' : log.versionName;
    final installDate = DateTime.fromMillisecondsSinceEpoch(log.installDate);
    final updateDate = DateTime.fromMillisecondsSinceEpoch(log.updateDate);
    final deletionDate =
        log.deletionDate != null
            ? DateTime.fromMillisecondsSinceEpoch(log.deletionDate!)
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(appName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                icon != null
                    ? Image.memory(
                      icon,
                      width: 80,
                      height: 80,
                      errorBuilder:
                          (context, error, stackTrace) => Icon(
                            isInstalled ? Icons.apps : Icons.delete,
                            size: 80,
                          ),
                    )
                    : Icon(isInstalled ? Icons.apps : Icons.delete, size: 80),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    appName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Non-scrollable details section (no Card)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Package: $packageName',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Version: $versionName',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Installed: ${DateFormat('dd/MM/yy HH:mm').format(installDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Last Updated: ${DateFormat('dd/MM/yy HH:mm').format(updateDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
                if (!isInstalled && deletionDate != null)
                  Text(
                    'Deleted: ${DateFormat('dd/MM/yy HH:mm').format(deletionDate)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                if (!isInstalled && deletionDate == null)
                  const Text('Deleted: N/A', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          // Scrollable version history
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Version History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AppLogEntry>>(
              future: dbHelper.getAppLogs(packageName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const Center(
                    child: Text('No version history available'),
                  );
                }
                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      log.updateDate,
                    );
                    final formattedDate = DateFormat(
                      'dd/MM/yy HH:mm',
                    ).format(date);
                    return ListTile(
                      title: Text('Version: ${log.versionName}'),
                      subtitle: Text('Updated: $formattedDate'),
                      // Non-clickable, but ListTile for future interactivity
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
