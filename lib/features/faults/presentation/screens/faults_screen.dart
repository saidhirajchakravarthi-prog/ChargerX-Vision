import 'package:flutter/material.dart';

class FaultsScreen extends StatelessWidget {
  const FaultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Faults')),
      body: const Center(
        child: Text('Fault registry placeholder'),
      ),
    );
  }
}
