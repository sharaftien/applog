import 'package:flutter/material.dart';
import 'installed_apps_page.dart';
import 'uninstalled_apps_page.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Installed'), Tab(text: 'Uninstalled')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [InstalledAppsPage(), UninstalledAppsPage()],
      ),
    );
  }
}
