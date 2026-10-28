// lib/features/authentication/presentation/providers/auth_providers.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../domain/repositories/auth_repository.dart';

/// Provides a singleton [FirebaseAuthService].
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>(
  (ref) => FirebaseAuthService(),
);

/// Provides an [AuthRepository] that delegates to [FirebaseAuthService].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(firebaseAuthServiceProvider)),
);

/// Stream of the current Firebase [User] (or null when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authRepositoryProvider).authStateChanges;
});

final authLoadingProvider = NotifierProvider<AuthLoadingNotifier, bool>(
  AuthLoadingNotifier.new,
);

final authErrorProvider = NotifierProvider<AuthErrorNotifier, String?>(
  AuthErrorNotifier.new,
);

class AuthLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLoading(bool val) => state = val;
}

class AuthErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setError(String? val) => state = val;
}
