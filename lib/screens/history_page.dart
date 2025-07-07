import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';
import 'app_details_page.dart';
import '../main.dart';
import 'dart:typed_data';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>>? logs;
  List<Map<String, dynamic>> displayLogs = [];
  String? errorMessage;
  final DatabaseHelper dbHelper = DatabaseHelper();
  String filterType = 'all';
  String filterTime = 'all';
  bool filterFavorites = false;

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
      print('Loading history logs...');
      final fetchedLogs = await dbHelper.getAllAppLogs();
      if (mounted) {
        setState(() {
          logs = fetchedLogs;
          _filterLogs();
          errorMessage = null;
        });
      }
    } catch (e) {
      print('Error loading history logs: $e');
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

            // Filter by event type
            bool typeMatch = true;
            if (filterType != 'all') {
              final eventType = _getEventType(log);
              typeMatch = eventType == filterType;
            }

            // Filter by time range
            bool timeMatch = true;
            if (filterTime != 'all') {
              final diff = now - timestamp;
              if (filterTime == '24h' && diff > 24 * 60 * 60 * 1000) {
                timeMatch = false;
              } else if (filterTime == 'week' &&
                  diff > 7 * 24 * 60 * 60 * 1000) {
                timeMatch = false;
              } else if (filterTime == 'month' &&
                  diff > 30 * 24 * 60 * 60 * 1000) {
                timeMatch = false;
              }
            }

            // Filter by favorites
            bool favoriteMatch = true;
            if (filterFavorites) {
              favoriteMatch = entry.isFavorite;
            }

            return typeMatch && timeMatch && favoriteMatch;
          }).toList();
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

  String _getEventType(Map<String, dynamic> log) {
    final entry = AppLogEntry.fromMap(log);
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
    if (previousLogs.isEmpty ||
        previousLogs.every((l) => l.deletionDate != null)) {
      return 'installed';
    }
    final latestPrevious = previousLogs.reduce(
      (a, b) => (a.id ?? 0) > (b.id ?? 0) ? a : b,
    );
    return entry.updateDate > entry.installDate &&
            entry.updateDate > latestPrevious.updateDate
        ? 'updated'
        : 'installed';
  }

  int _getEventTimestamp(Map<String, dynamic> log) {
    final entry = AppLogEntry.fromMap(log);
    return entry.deletionDate ?? entry.updateDate ?? entry.installDate;
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
                    });
                    _filterLogs();
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
                    });
                    _filterLogs();
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
                  _filterLogs();
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
                  ? const Center(child: Text('No history found'))
                  : ListView.builder(
                    itemCount: displayLogs.length,
                    itemBuilder: (context, index) {
                      final log = AppLogEntry.fromMap(displayLogs[index]);
                      final eventType = _getEventType(displayLogs[index]);
                      final timestamp = _getEventTimestamp(displayLogs[index]);
                      return InkWell(
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => AppDetailsPage(
                                      log: log,
                                      dbHelper: dbHelper,
                                      selectedLogId: log.id,
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
                                          Icons.history,
                                          size: 40,
                                          color: Colors.grey[600],
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
                                              '$eventType ${log.versionName}',
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
