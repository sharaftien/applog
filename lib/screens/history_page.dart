import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../database/app_log_entry.dart';
import 'app_details_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>>? logs;
  String? errorMessage;
  final DatabaseHelper dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      print('Loading history logs...');
      final fetchedLogs = await dbHelper.getAllAppLogs();
      if (mounted) {
        setState(() {
          logs = fetchedLogs;
          errorMessage = null;
        });
      }
    } catch (e) {
      print('Error loading history logs: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load history: $e';
        });
      }
    }
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
    final previousLogs =
        logs!
            .where(
              (l) =>
                  l['package_name'] == entry.packageName && l['id'] < entry.id,
            )
            .toList();
    if (entry.deletionDate != null) return 'Deleted';
    if (previousLogs.isEmpty) return 'Installed';
    return 'Updated';
  }

  @override
  Widget build(BuildContext context) {
    if (logs == null && errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
          ],
        ),
        Expanded(
          child:
              logs == null
                  ? const Center(child: CircularProgressIndicator())
                  : logs!.isEmpty
                  ? const Center(child: Text('No history found'))
                  : ListView.builder(
                    itemCount: logs!.length,
                    itemBuilder: (context, index) {
                      final log = AppLogEntry.fromMap(logs![index]);
                      final eventType = _getEventType(logs![index]);
                      final timestamp = log.deletionDate ?? log.updateDate;
                      return ListTile(
                        leading:
                            log.icon != null
                                ? Image.memory(
                                  log.icon!,
                                  width: 40,
                                  height: 40,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(Icons.history, size: 40),
                                )
                                : const Icon(Icons.history, size: 40),
                        title: Text('$eventType ${log.appName}'),
                        subtitle: Text(
                          'Version: ${log.versionName}\n${_formatRelativeTime(timestamp)}',
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
    );
  }
}
