import 'package:flutter/material.dart';
import 'screens/installed_apps_page.dart';
import 'screens/uninstalled_apps_page.dart';

void main() {
  runApp(const AppLog());
}

class AppLog extends StatelessWidget {
  const AppLog({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('App Log'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Installed'), Tab(text: 'Uninstalled')],
            ),
          ),
          body: const TabBarView(
            children: [InstalledAppsPage(), UninstalledAppsPage()],
          ),
        ),
      ),
    );
  }
}
