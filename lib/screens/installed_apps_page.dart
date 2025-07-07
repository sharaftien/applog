import 'package:flutter/material.dart';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';
import 'app_details_page.dart';
import '../main.dart';
import 'package:intl/intl.dart';

class InstalledAppsPage extends StatefulWidget {
  const InstalledAppsPage({super.key});

  @override
  State<InstalledAppsPage> createState() => _InstalledAppsPageState();
}

class _InstalledAppsPageState extends State<InstalledAppsPage>
    with SingleTickerProviderStateMixin {
  List<AppLogEntry>? cachedApps;
  List<AppLogEntry> displayApps = [];
  final DatabaseHelper dbHelper = DatabaseHelper();
  String? errorMessage;
  bool isRefreshing = false;
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
    _loadCachedApps();
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
    await _loadCachedApps();
  }

  Future<void> _loadCachedApps() async {
    try {
      print('Loading cached apps...');
      final logs = await dbHelper.getLatestAppLogs(sortBy: sortBy);
      if (mounted) {
        setState(() {
          cachedApps = logs;
          displayApps = logs.where((log) => log.deletionDate == null).toList();
          errorMessage = null;
        });
        _sortDisplayApps();
      }
    } catch (e) {
      print('Error loading cached apps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cached apps: $e')),
        );
      }
    }
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

  void _sortDisplayApps() {
    setState(() {
      displayApps.sort((a, b) {
        if (sortBy == 'app_name') {
          return a.appName.compareTo(b.appName);
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

  String sortBy = 'update_date';

  @override
  Widget build(BuildContext context) {
    if (displayApps.isEmpty && errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

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
                  displayApps.isEmpty
                      ? const Center(child: Text('No installed apps found'))
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
                                              const Icon(Icons.apps, size: 40),
                                    )
                                    : const Icon(Icons.apps, size: 40),
                            title: Text(log.appName),
                            subtitle: Text(
                              'Version: ${log.versionName}\nLast updated ${_formatRelativeTime(log.updateDate)}',
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
            onPressed: isRefreshing ? null : _fetchApps,
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
