import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';
import 'app_details_page.dart';
import '../main.dart';
import 'package:intl/intl.dart';

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
  bool isRefreshing = false;
  String sortBy = 'deletion_date';
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..addListener(() {
      setState(() {});
    });
    _loadCachedUninstalledApps();
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

  Future<void> _onAppStateUpdate() async {
    setState(() {
      isRefreshing = AppStateManager().isFetching;
      if (isRefreshing) {
        _controller?.repeat();
      } else {
        _controller?.stop();
      }
    });
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

  Future<void> _fetchUninstalledApps() async {
    setState(() {
      isRefreshing = true;
      _controller?.repeat();
    });
    try {
      await AppStateManager().fetchAndUpdateApps();
      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      final installedPackageNames =
          installedApps.map((app) => app.packageName).toList();
      final updatedLogs = await dbHelper.getUninstalledAppLogs(
        installedPackageNames,
        sortBy: sortBy,
      );
      if (mounted) {
        setState(() {
          cachedApps = updatedLogs;
          displayApps = updatedLogs;
          errorMessage = null;
          isRefreshing = false;
          _controller?.stop();
        });
      }
    } catch (e) {
      print('Error fetching uninstalled apps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load uninstalled apps: $e')),
        );
        setState(() {
          isRefreshing = false;
          _controller?.stop();
        });
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
    return Stack(
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
              ],
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
                          return ListTile(
                            leading:
                                log.icon != null
                                    ? Image.memory(
                                      log.icon!,
                                      width: 40,
                                      height: 40,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.delete,
                                                size: 40,
                                              ),
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
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: isRefreshing ? null : _fetchUninstalledApps,
            backgroundColor: isRefreshing ? Colors.blue.shade300 : Colors.blue,
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_controller!),
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
