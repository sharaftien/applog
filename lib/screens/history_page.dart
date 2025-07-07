import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';
import '../main.dart';
import 'app_details_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>>? logs;
  List<Map<String, dynamic>> displayLogs = [];
  String? errorMessage;
  final DatabaseHelper dbHelper = DatabaseHelper();
  String filterType = 'all';
  String filterTime = 'all';
  bool filterFavorites = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    AppStateManager().addListener(_onAppStateUpdate);
  }

  @override
  void dispose() {
    AppStateManager().removeListener(_onAppStateUpdate);
    super.dispose();
  }

  Future<void> _onAppStateUpdate() async {
    await _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final fetchedLogs = await dbHelper.getAllAppLogs();
      if (mounted) {
        setState(() {
          logs = fetchedLogs;
          _filterLogs();
          errorMessage = null;
        });
      }
    } catch (e) {
      print('Fetching history... $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load history: $e')));
      }
    }
  }

  void _filterLogs() {
    if (logs == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      displayLogs =
          logs!.where((log) {
            final entry = AppLogEntry.fromMap(log);
            final timestamp =
                entry.deletionDate ?? entry.updateDate ?? entry.installDate;

            bool typeMatch = true;
            if (filterType != 'all') {
              final eventType = _getEventType(entry);
              typeMatch = eventType == filterType;
            }

            bool timeMatch = true;
            if (filterTime != 'all') {
              final diff = now - timestamp;
              if (filterTime == '24h' && diff > 24 * 60 * 60 * 1000)
                timeMatch = false;
              else if (filterTime == 'week' && diff > 7 * 24 * 60 * 60 * 1000)
                timeMatch = false;
              else if (filterTime == 'month' && diff > 30 * 24 * 60 * 60 * 1000)
                timeMatch = false;
            }

            bool favoriteMatch = !filterFavorites || entry.isFavorite;
            return typeMatch && timeMatch && favoriteMatch;
          }).toList();
    });
  }

  String _formatRelativeTime(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(date);
  }

  String _getEventType(AppLogEntry entry) {
    if (entry.deletionDate != null) return 'deleted';
    final previousLogs =
        logs!
            .where(
              (l) =>
                  l['package_name'] == entry.packageName &&
                  (l['id'] as int) < (entry.id ?? 0),
            )
            .map((l) => AppLogEntry.fromMap(l))
            .toList();
    if (previousLogs.isEmpty) return 'installed';
    final latestPrevious = previousLogs.reduce(
      (a, b) => (a.id ?? 0) > (b.id ?? 0) ? a : b,
    );
    if (latestPrevious.deletionDate != null) return 'installed';
    return entry.updateDate > entry.installDate &&
            entry.updateDate > (latestPrevious.updateDate ?? 0)
        ? 'updated'
        : 'installed';
  }

  String _getVersionForEvent(AppLogEntry entry, String eventType) {
    if (eventType == 'installed') return entry.installVersionName;
    return entry.versionName; // For 'updated' or 'deleted'
  }

  int _getEventTimestamp(AppLogEntry entry, String eventType) {
    if (eventType == 'deleted') return entry.deletionDate ?? entry.updateDate;
    return eventType == 'installed' ? entry.installDate : entry.updateDate;
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'installed':
        return Icons.add_circle;
      case 'updated':
        return Icons.update;
      case 'deleted':
        return Icons.delete;
      default:
        return Icons.history;
    }
  }

  Color _getIconColor(String eventType) {
    switch (eventType) {
      case 'installed':
        return Colors.green[700]!;
      case 'updated':
        return Colors.blue[700]!;
      case 'deleted':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DropdownButton<String>(
                value: filterType,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Events')),
                  DropdownMenuItem(
                    value: 'installed',
                    child: Text('Installed'),
                  ),
                  DropdownMenuItem(value: 'updated', child: Text('Updated')),
                  DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                ],
                onChanged: (value) {
                  if (value != null && value != filterType) {
                    setState(() {
                      filterType = value;
                      _filterLogs();
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: filterTime,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: '24h', child: Text('Last 24 Hours')),
                  DropdownMenuItem(value: 'week', child: Text('Last Week')),
                  DropdownMenuItem(value: 'month', child: Text('Last Month')),
                ],
                onChanged: (value) {
                  if (value != null && value != filterTime) {
                    setState(() {
                      filterTime = value;
                      _filterLogs();
                    });
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
                    _filterLogs();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child:
              logs == null && errorMessage != null
                  ? Center(child: Text(errorMessage!))
                  : logs == null
                  ? const Center(child: CircularProgressIndicator())
                  : displayLogs.isEmpty
                  ? const Center(child: Text('No history entries found'))
                  : ListView.separated(
                    itemCount: displayLogs.length,
                    separatorBuilder:
                        (context, index) =>
                            const Divider(height: 1, color: Colors.grey),
                    itemBuilder: (context, index) {
                      final log = AppLogEntry.fromMap(displayLogs[index]);
                      final eventType = _getEventType(log);
                      final version = _getVersionForEvent(log, eventType);
                      final timestamp = _getEventTimestamp(log, eventType);
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => AppDetailsPage(
                                    log: log,
                                    dbHelper: dbHelper,
                                    selectedLogId: log.id,
                                  ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              log.icon != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      Uint8List.fromList(log.icon!),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                            Icons.history,
                                            size: 40,
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                  )
                                  : Icon(
                                    Icons.history,
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
                                              _getEventIcon(eventType),
                                              size: 16,
                                              color: _getIconColor(eventType),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$version ($eventType)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _formatRelativeTime(timestamp),
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
