// lib/features/authentication/presentation/screens/email_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';

class EmailVerificationScreen extends ConsumerWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authLoadingProvider);
    final error = ref.watch(authErrorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_outlined, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'A verification email has been sent to your address.',
                ),
                const SizedBox(height: 12),
                const Text('Please verify your email to continue.'),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          ref
                              .read(authLoadingProvider.notifier)
                              .setLoading(true);
                          final result = await ref
                              .read(authRepositoryProvider)
                              .resendVerification();
                          ref.read(authErrorProvider.notifier).setError(result);
                          ref
                              .read(authLoadingProvider.notifier)
                              .setLoading(false);
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Resend verification email'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          ref
                              .read(authLoadingProvider.notifier)
                              .setLoading(true);
                          ref.read(authErrorProvider.notifier).setError(null);
                          try {
                            // Reload user from Firebase to check if email verification status changed
                            await ref.read(authRepositoryProvider).reloadUser();
                            // Check if email is now verified
                            final user = ref
                                .read(authRepositoryProvider)
                                .currentUser;
                            if (user?.emailVerified ?? false) {
                              if (context.mounted) context.go('/');
                            } else {
                              ref
                                  .read(authErrorProvider.notifier)
                                  .setError(
                                    'Email not verified yet. Please check your inbox.',
                                  );
                            }
                          } catch (e) {
                            ref
                                .read(authErrorProvider.notifier)
                                .setError(
                                  'Error checking verification status.',
                                );
                          } finally {
                            ref
                                .read(authLoadingProvider.notifier)
                                .setLoading(false);
                          }
                        },
                  icon: const Icon(Icons.check),
                  label: const Text("I've verified my email"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
