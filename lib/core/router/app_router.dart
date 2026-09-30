import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/screens/email_verification_screen.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/register_screen.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/chargers/presentation/screens/chargers_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/main_shell.dart';
import '../../features/digital_twin/presentation/screens/digital_twin_screen.dart';
import '../../features/health/presentation/screens/health_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/inspection/presentation/screens/inspection_screen.dart';
import '../../features/inspection/presentation/screens/component_inspection_screen.dart';
import '../../features/inspection/presentation/screens/results_screen.dart';
import '../../features/digital_twin/domain/models/digital_twin_component.dart';
import '../../features/maintenance/presentation/screens/maintenance_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/qr_scanner/presentation/screens/scan_charger_screen.dart';
import '../../features/ai_recognition/presentation/screens/ai_recognition_screen.dart';
import '../../features/chargers/domain/models/charger_model.dart';

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthRouterRefresh(),
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final path = state.uri.path;
      final loggingIn =
          path == '/login' ||
          path == '/register' ||
          path == '/forgot-password' ||
          path == '/splash';
      // If no user, send to login unless already there
      if (user == null) {
        return loggingIn ? null : '/login';
      }
      // User exists but email not verified
      if (!user.emailVerified) {
        // Allow only verification screen
        if (path == '/email-verification') return null;
        return '/email-verification';
      }
      // User verified, prevent access to auth screens
      if (loggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/email-verification',
        name: 'email-verification',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/chargers',
            name: 'chargers',
            builder: (context, state) => const ChargersScreen(),
          ),
          GoRoute(
            path: '/scan',
            name: 'scan',
            builder: (context, state) => const ScanChargerScreen(),
          ),
          GoRoute(
            path: '/ai-recognition',
            name: 'ai-recognition',
            builder: (context, state) => const AiRecognitionScreen(),
          ),
          GoRoute(
            path: '/inspection',
            name: 'inspection',
            builder: (context, state) => const InspectionScreen(),
          ),
          GoRoute(
            path: '/component-inspection',
            name: 'component-inspection',
            builder: (context, state) {
              final comp = state.extra as DigitalTwinComponent;
              return ComponentInspectionScreen(component: comp);
            },
          ),
          GoRoute(
            path: '/results',
            name: 'results',
            builder: (context, state) => const ResultsScreen(),
          ),
          GoRoute(
            path: '/digital-twin',
            name: 'digital-twin',
            builder: (context, state) => DigitalTwinScreen(
              charger: state.extra as ChargerModel?,
            ),
          ),
          GoRoute(
            path: '/health',
            name: 'health',
            builder: (context, state) => const HealthScreen(),
          ),
          GoRoute(
            path: '/maintenance',
            name: 'maintenance',
            builder: (context, state) => const MaintenanceScreen(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/history',
            name: 'history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
