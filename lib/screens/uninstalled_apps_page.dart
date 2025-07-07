import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';
import 'app_details_page.dart';
import '../main.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:typed_data';

class UninstalledAppsPage extends StatefulWidget {
  const UninstalledAppsPage({super.key});

  @override
  State<UninstalledAppsPage> createState() => _UninstalledAppsPageState();
}

class _UninstalledAppsPageState extends State<UninstalledAppsPage>
    with SingleTickerProviderStateMixin {
  List<AppLogEntry>? cachedApps;
  List<AppLogEntry> displayApps = [];
  final DatabaseHelper dbHelper = DatabaseHelper();
  String? errorMessage;
  String sortBy = 'deletion_date';

  @override
  void initState() {
    super.initState();
    _loadCachedUninstalledApps();
    AppStateManager().addListener(_onAppStateUpdate);
  }

  @override
  void dispose() {
    AppStateManager().removeListener(_onAppStateUpdate);
    super.dispose();
  }

  Future<void> _onAppStateUpdate() async {
    await _loadCachedUninstalledApps();
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
      }
    } catch (e) {
      print('Error loading cached uninstalled apps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load uninstalled apps: $e')),
        );
      }
    }
  }

  void _sortDisplayApps() {
    setState(() {
      displayApps = List.from(cachedApps ?? []);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DropdownButton<String>(
                value: sortBy,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
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
            ],
          ),
        ),
        Expanded(
          child:
              cachedApps == null && errorMessage != null
                  ? Center(child: Text(errorMessage!))
                  : cachedApps == null
                  ? const Center(child: CircularProgressIndicator())
                  : cachedApps!.isEmpty
                  ? const Center(child: Text('No uninstalled apps found'))
                  : ListView.builder(
                    itemCount: displayApps.length,
                    itemBuilder: (context, index) {
                      final log = displayApps[index];
                      return InkWell(
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              log.icon != null
                                  ? Image.memory(
                                    Uint8List.fromList(log.icon!),
                                    width: 40,
                                    height: 40,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.delete,
                                          size: 40,
                                          color: Colors.grey[600],
                                        ),
                                  )
                                  : Icon(
                                    Icons.delete,
                                    size: 40,
                                    color: Colors.grey[600],
                                  ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          log.appName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (log.isFavorite)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4.0,
                                            ),
                                            child: Icon(
                                              Icons.star,
                                              size: 16,
                                              color: Colors.yellow[700],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 16,
                                              color: Colors.red[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              log.versionName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _formatRelativeTime(
                                            log.deletionDate ??
                                                DateTime.now()
                                                    .millisecondsSinceEpoch,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
