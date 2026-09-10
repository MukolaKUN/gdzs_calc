import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/firefighters/add_firefighter_page.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';

void main() {
  testWidgets('watch is a required dropdown with four fixed values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AddFirefighterPage(
          firefighter: Firefighter(id: 1, fullName: 'Старий запис', watch: ''),
        ),
      ),
    );

    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    await tester.tap(find.text('Зберегти'));
    await tester.pump();
    expect(find.text('Оберіть караул'), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    for (var watch = 1; watch <= 4; watch++) {
      expect(find.text('$watch-й караул'), findsOneWidget);
    }
  });
}
