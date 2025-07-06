import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';

void main() {
  runApp(const AppLog());
}

class AppLog extends StatelessWidget {
  const AppLog({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: InstalledAppsPage());
  }
}

class InstalledAppsPage extends StatefulWidget {
  const InstalledAppsPage({super.key});

  @override
  State<InstalledAppsPage> createState() => _InstalledAppsPageState();
}

class _InstalledAppsPageState extends State<InstalledAppsPage> {
  List<Application>? apps;

  @override
  void initState() {
    super.initState();
    _fetchInstalledApps();
  }

  Future<void> _fetchInstalledApps() async {
    final installedApps = await DeviceApps.getInstalledApplications(
      includeAppIcons: false,
      includeSystemApps: false,
      onlyAppsWithLaunchIntent: true,
    );

    setState(() {
      apps = installedApps;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (apps == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Installed Apps')),
      body: ListView.builder(
        itemCount: apps!.length,
        itemBuilder: (context, index) {
          final app = apps![index];
          return ListTile(
            title: Text(app.appName),
            subtitle: Text(
              'Version: ${app.versionName ?? 'N/A'}\n'
              'Package: ${app.packageName}',
            ),
          );
        },
      ),
    );
  }
}
