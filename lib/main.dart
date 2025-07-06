import 'package:flutter/material.dart';

void main() {
  runApp(const AppLog());
}

class AppLog extends StatelessWidget {
  const AppLog({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppLogHomePage(),
    );
  }
}

class AppLogHomePage extends StatelessWidget {
  const AppLogHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AppLog')),
      body: const Center(child: Text('Welcome to AppLog')),
    );
  }
}
