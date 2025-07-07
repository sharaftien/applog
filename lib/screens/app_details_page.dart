import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:intl/intl.dart';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';

class AppDetailsPage extends StatefulWidget {
  final Application? app;
  final AppLogEntry log;
  final DatabaseHelper dbHelper;

  const AppDetailsPage({
    super.key,
    this.app,
    required this.log,
    required this.dbHelper,
  });

  @override
  State<AppDetailsPage> createState() => _AppDetailsPageState();
}

class _AppDetailsPageState extends State<AppDetailsPage> {
  late Future<List<AppLogEntry>> _appLogsFuture;

  @override
  void initState() {
    super.initState();
    _appLogsFuture = widget.dbHelper.getAppLogs(
      widget.app?.packageName ?? widget.log.packageName,
    );
  }

  Future<void> _showNotesDialog(BuildContext context, AppLogEntry log) async {
    final controller = TextEditingController(text: log.notes ?? '');
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Notes for ${log.versionName}'),
            content: TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter notes here',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final updatedLog = AppLogEntry(
                    id: log.id,
                    packageName: log.packageName,
                    appName: log.appName,
                    versionName: log.versionName,
                    installDate: log.installDate,
                    updateDate: log.updateDate,
                    icon: log.icon,
                    deletionDate: log.deletionDate,
                    notes: controller.text.isEmpty ? null : controller.text,
                  );
                  await widget.dbHelper.insertAppLogs([updatedLog]);
                  setState(() {
                    _appLogsFuture = widget.dbHelper.getAppLogs(
                      widget.app?.packageName ?? widget.log.packageName,
                    );
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInstalled = widget.app != null;
    final icon =
        isInstalled && widget.app is ApplicationWithIcon
            ? (widget.app as ApplicationWithIcon).icon
            : widget.log.icon;
    final appName = isInstalled ? widget.app!.appName : widget.log.appName;
    final packageName =
        isInstalled ? widget.app!.packageName : widget.log.packageName;
    final versionName =
        isInstalled ? widget.app!.versionName ?? 'N/A' : widget.log.versionName;
    final installDate = DateTime.fromMillisecondsSinceEpoch(
      widget.log.installDate,
    );
    final updateDate = DateTime.fromMillisecondsSinceEpoch(
      widget.log.updateDate,
    );
    final deletionDate =
        widget.log.deletionDate != null
            ? DateTime.fromMillisecondsSinceEpoch(widget.log.deletionDate!)
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
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Version History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AppLogEntry>>(
              future: _appLogsFuture,
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
                      subtitle: Text(
                        'Updated: $formattedDate${log.notes != null ? '\nNotes: ${log.notes}' : ''}',
                      ),
                      onTap: () => _showNotesDialog(context, log),
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
