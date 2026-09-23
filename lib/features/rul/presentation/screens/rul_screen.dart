import 'package:flutter/material.dart';

class RULScreen extends StatelessWidget {
  const RULScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RUL')),
      body: const Center(
        child: Text('Remaining useful life placeholder'),
      ),
    );
  }
}
