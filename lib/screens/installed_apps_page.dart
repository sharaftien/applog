import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:typed_data';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';
import '../main.dart';
import 'app_details_page.dart';

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
  String sortBy = 'update_date';
  bool filterFavorites = false;

  @override
  void initState() {
    super.initState();
    _loadCachedApps();
    AppStateManager().addListener(_onAppStateUpdate);
  }

  @override
  void dispose() {
    AppStateManager().removeListener(_onAppStateUpdate);
    super.dispose();
  }

  Future<void> _onAppStateUpdate() async {
    await _loadCachedApps();
  }

  Future<void> _loadCachedApps() async {
    try {
      print('Loading cached apps...');
      final logs = await dbHelper.getLatestAppLogs(sortBy: sortBy);
      if (mounted) {
        setState(() {
          cachedApps = logs;
          _filterApps();
          errorMessage = null;
        });
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

  void _filterApps() {
    setState(() {
      displayApps =
          cachedApps!
              .where(
                (log) =>
                    log.deletionDate == null &&
                    (!filterFavorites || log.isFavorite),
              )
              .toList();
      _sortDisplayApps();
    });
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

  @override
  Widget build(BuildContext context) {
    if (displayApps.isEmpty && errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

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
                ],
                onChanged: (value) {
                  if (value != null && value != sortBy) {
                    setState(() {
                      sortBy = value;
                    });
                    _filterApps();
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  filterFavorites ? Icons.star : Icons.star_border,
                  color:
                      filterFavorites ? Colors.yellow[700] : Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    filterFavorites = !filterFavorites;
                  });
                  _filterApps();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child:
              displayApps.isEmpty
                  ? const Center(child: Text('No installed apps found'))
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
                                          Icons.apps,
                                          size: 40,
                                          color: Colors.grey[600],
                                        ),
                                  )
                                  : Icon(
                                    Icons.apps,
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
                                              Icons.add_circle,
                                              size: 16,
                                              color: Colors.green[700],
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
                                          _formatRelativeTime(log.updateDate),
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
