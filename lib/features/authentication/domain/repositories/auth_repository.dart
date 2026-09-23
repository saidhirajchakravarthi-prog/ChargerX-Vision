// lib/features/authentication/domain/repositories/auth_repository.dart
import '../../data/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuthService _service;

  AuthRepository(this._service);

  Stream<User?> get authStateChanges => _service.authStateChanges();

  User? get currentUser => _service.currentUser;

  Future<String?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      await _service.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return 'An unknown error occurred.';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _service.login(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return 'An unknown error occurred.';
    }
  }

  Future<void> logout() async => await _service.logout();

  Future<String?> sendPasswordReset({required String email}) async {
    try {
      await _service.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return 'An unknown error occurred.';
    }
  }

  Future<String?> resendVerification() async {
    try {
      await _service.resendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return 'An unknown error occurred.';
    }
  }

  /// Reload the current user's state from Firebase to refresh email verification status.
  Future<void> reloadUser() async {
    await _service.reloadCurrentUser();
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'network-request-failed':
        return 'Network connection failed.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Authentication error.';
    }
  }
}
