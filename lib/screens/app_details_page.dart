import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:typed_data';
import '../database/app_log_entry.dart';
import '../database/database_helper.dart';

class AppDetailsPage extends StatefulWidget {
  final Application? app;
  final AppLogEntry log;
  final DatabaseHelper dbHelper;
  final int? selectedLogId;

  const AppDetailsPage({
    super.key,
    this.app,
    required this.log,
    required this.dbHelper,
    this.selectedLogId,
  });

  @override
  State<AppDetailsPage> createState() => _AppDetailsPageState();
}

class _AppDetailsPageState extends State<AppDetailsPage>
    with SingleTickerProviderStateMixin {
  late Future<List<AppLogEntry>> _appLogsFuture;
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _highlightedLogId;
  AnimationController? _animationController;
  Animation<Color?>? _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _appLogsFuture = widget.dbHelper.getAppLogs(
      widget.app?.packageName ?? widget.log.packageName,
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _highlightAnimation = ColorTween(
      begin: Colors.grey[700],
      end: Colors.transparent,
    ).animate(_animationController!);
    if (widget.selectedLogId != null) {
      _highlightedLogId = widget.selectedLogId;
      _animationController?.forward().then((_) {
        if (mounted) {
          setState(() {
            _highlightedLogId = null;
          });
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedLog(widget.selectedLogId!);
      });
    }
  }

  Future<void> _showNotesDialog(BuildContext context, AppLogEntry log) async {
    _notesController.text = log.notes ?? '';
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(
              'Notes for ${log.versionName}',
              style: const TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: _notesController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter notes here',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[800],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
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
                    notes:
                        _notesController.text.isEmpty
                            ? null
                            : _notesController.text,
                    isFavorite: log.isFavorite,
                  );
                  await widget.dbHelper.updateAppLog(updatedLog);
                  setState(() {
                    _appLogsFuture = widget.dbHelper.getAppLogs(
                      widget.app?.packageName ?? widget.log.packageName,
                    );
                  });
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _toggleFavorite(AppLogEntry log) async {
    final updatedLog = AppLogEntry(
      id: log.id,
      packageName: log.packageName,
      appName: log.appName,
      versionName: log.versionName,
      installDate: log.installDate,
      updateDate: log.updateDate,
      icon: log.icon,
      deletionDate: log.deletionDate,
      notes: log.notes,
      isFavorite: !log.isFavorite,
    );
    await widget.dbHelper.updateAppLog(updatedLog);
    setState(() {
      _appLogsFuture = widget.dbHelper.getAppLogs(
        widget.app?.packageName ?? widget.log.packageName,
      );
    });
  }

  void _highlightAndScrollToLog(int logId, List<AppLogEntry> logs) {
    setState(() {
      _highlightedLogId = logId;
    });
    _scrollToSelectedLog(logId);
    _animationController?.reset();
    _animationController?.forward().then((_) {
      if (mounted) {
        setState(() {
          _highlightedLogId = null;
        });
      }
    });
  }

  void _scrollToSelectedLog(int logId) {
    _appLogsFuture.then((logs) {
      final index = logs.indexWhere((log) => log.id == logId);
      if (index != -1 && _scrollController.hasClients) {
        final offset = index * 80.0; // Approximate height per item
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  String _getEventType(AppLogEntry log, List<AppLogEntry> allLogs) {
    if (log.deletionDate != null) return 'deleted';
    final previousLogs =
        allLogs
            .where(
              (l) =>
                  l.packageName == log.packageName &&
                  (l.id ?? 0) < (log.id ?? 0),
            )
            .toList();
    if (previousLogs.isEmpty) return 'installed';
    final latestPrevious = previousLogs.reduce(
      (a, b) => (a.id ?? 0) > (b.id ?? 0) ? a : b,
    );
    if (latestPrevious.deletionDate != null) return 'installed';
    return log.updateDate > log.installDate &&
            log.updateDate > latestPrevious.updateDate
        ? 'updated'
        : 'installed';
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
  void dispose() {
    _notesController.dispose();
    _scrollController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInstalled = widget.app != null;
    final icon =
        isInstalled && widget.app is ApplicationWithIcon
            ? (widget.app as ApplicationWithIcon).icon
            : widget.log.icon != null
            ? Uint8List.fromList(widget.log.icon!)
            : null;
    final appName = isInstalled ? widget.app!.appName : widget.log.appName;
    final packageName =
        isInstalled ? widget.app!.packageName : widget.log.packageName;
    final versionName =
        isInstalled ? widget.app!.versionName ?? 'N/A' : widget.log.versionName;
    final installDate = DateTime.fromMillisecondsSinceEpoch(
      widget.log.installDate,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(appName),
        backgroundColor: Colors.grey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<AppLogEntry>>(
        future: _appLogsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final logs = snapshot.data ?? [];
          final latestLog =
              logs.isNotEmpty
                  ? logs.reduce((a, b) => (a.id ?? 0) > (b.id ?? 0) ? a : b)
                  : widget.log;
          final updateDate = DateTime.fromMillisecondsSinceEpoch(
            latestLog.updateDate,
          );
          final deletionDate =
              latestLog.deletionDate != null
                  ? DateTime.fromMillisecondsSinceEpoch(latestLog.deletionDate!)
                  : null;

          return SingleChildScrollView(
            child: Column(
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
                                  color: Colors.grey[600],
                                ),
                          )
                          : Icon(
                            isInstalled ? Icons.apps : Icons.delete,
                            size: 80,
                            color: Colors.grey[600],
                          ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              appName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                latestLog.isFavorite
                                    ? Icons.star
                                    : Icons.star_border,
                                color:
                                    latestLog.isFavorite
                                        ? Colors.yellow[700]
                                        : Colors.grey[600],
                              ),
                              onPressed: () => _toggleFavorite(latestLog),
                            ),
                          ],
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
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      Text(
                        'Version: $versionName',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      Text(
                        'Installed: ${DateFormat('dd/MM/yy HH:mm').format(installDate)}',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      Text(
                        'Last Updated: ${DateFormat('dd/MM/yy HH:mm').format(updateDate)}',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      if (!isInstalled && deletionDate != null)
                        Text(
                          'Deleted: ${DateFormat('dd/MM/yy HH:mm').format(deletionDate)}',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Version History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final eventType = _getEventType(log, logs);
                      final timestamp = log.deletionDate ?? log.updateDate;
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        timestamp,
                      );
                      return GestureDetector(
                        onTap: () {
                          _highlightAndScrollToLog(log.id!, logs);
                          _showNotesDialog(context, log);
                        },
                        child: AnimatedBuilder(
                          animation: _animationController!,
                          builder: (context, child) {
                            return Container(
                              color:
                                  _highlightedLogId == log.id
                                      ? _highlightAnimation?.value
                                      : Colors.transparent,
                              child: ListTile(
                                leading: Icon(
                                  _getEventIcon(eventType),
                                  color: _getIconColor(eventType),
                                ),
                                title: Text(
                                  '${log.versionName} ($eventType)',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  DateFormat('dd/MM/yy HH:mm').format(date),
                                  style: TextStyle(color: Colors.white70),
                                ),
                                trailing:
                                    log.notes != null
                                        ? Icon(
                                          Icons.note,
                                          color: Colors.grey[600],
                                        )
                                        : null,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
