import 'package:flutter/material.dart';

class OfflineSyncScreen extends StatelessWidget {
  const OfflineSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Sync')),
      body: const Center(
        child: Text('Offline sync placeholder'),
      ),
    );
  }
}
