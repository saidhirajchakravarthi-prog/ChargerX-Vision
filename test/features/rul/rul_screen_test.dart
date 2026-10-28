import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/rul/presentation/screens/rul_screen.dart';

void main() {
  testWidgets('shows unavailable RUL readiness without selected charger', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RULScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No charger selected'), findsOneWidget);
    expect(
      find.text('RUL unavailable - insufficient real operational data'),
      findsOneWidget,
    );
    expect(find.text('Scan charger'), findsOneWidget);
    expect(find.text('Use AI recognition'), findsOneWidget);
    expect(find.textContaining('0 months'), findsNothing);
    expect(find.textContaining('50%'), findsNothing);
  });
}
