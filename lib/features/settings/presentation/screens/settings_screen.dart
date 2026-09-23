import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authLoadingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: () async {
                  ref.read(authLoadingProvider.notifier).setLoading(true);
                  await ref.read(authRepositoryProvider).logout();
                  ref.read(authLoadingProvider.notifier).setLoading(false);
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                child: const Text('Logout'),
              ),
      ),
    );
  }
}
