import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';
import 'app_details_page.dart';
import '../main.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>>? logs;
  String? errorMessage;
  final DatabaseHelper dbHelper = DatabaseHelper();
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
    _loadLogs();
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
    await _loadLogs();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load history: $e')));
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
      print('Error fetching apps for history: $e');
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
    if (entry.deletionDate != null) return 'Deleted';
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
      return 'Installed';
    }
    final latestPrevious = previousLogs.reduce(
      (a, b) => (a.id ?? 0) > (b.id ?? 0) ? a : b,
    );
    return entry.updateDate > entry.installDate &&
            entry.updateDate > latestPrevious.updateDate
        ? 'Updated'
        : 'Installed';
  }

  int _getEventTimestamp(Map<String, dynamic> log) {
    final entry = AppLogEntry.fromMap(log);
    return entry.deletionDate ?? entry.updateDate ?? entry.installDate;
  }

  @override
  Widget build(BuildContext context) {
    if (logs == null && errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    return Stack(
      children: [
        logs == null
            ? const Center(child: CircularProgressIndicator())
            : logs!.isEmpty
            ? const Center(child: Text('No history found'))
            : ListView.builder(
              itemCount: logs!.length,
              itemBuilder: (context, index) {
                final log = AppLogEntry.fromMap(logs![index]);
                final eventType = _getEventType(logs![index]);
                final timestamp = _getEventTimestamp(logs![index]);
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
                                selectedLogId: log.id, // Pass selected log ID
                              ),
                        ),
                      ),
                );
              },
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
