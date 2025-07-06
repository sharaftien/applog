import 'package:flutter/material.dart';
import 'screens/installed_apps_page.dart';

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
