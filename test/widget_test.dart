// ChargeX Vision widget tests

import 'package:chargex_vision/features/authentication/presentation/screens/login_screen.dart';
import 'package:chargex_vision/features/authentication/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ChargeX Vision app initializes with splash screen', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('ChargeX Vision'), findsWidgets);
    expect(find.byIcon(Icons.electric_car_rounded), findsOneWidget);

    // Dispose the initialization splash before draining its delayed callback.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
