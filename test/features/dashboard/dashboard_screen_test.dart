import 'package:chargex_vision/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not show fabricated fleet counts or trends', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active chargers'), findsOneWidget);
    expect(find.text('Open faults'), findsOneWidget);
    expect(find.text('148'), findsNothing);
    expect(find.text('23'), findsNothing);
    expect(find.text('+12%'), findsNothing);
    expect(find.text('-7'), findsNothing);
    expect(find.text('Live fleet data not connected'), findsNWidgets(2));
  });
}
