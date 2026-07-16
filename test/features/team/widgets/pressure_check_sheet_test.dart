import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_check_sheet.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  testWidgets('returns pressures and can be reopened and dismissed', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 16, 12);
    final session = ActiveTeamSession(
      unitName: '1 ДПРЧ',
      apparatusName: 'Drager PSS 4000',
      participants: const [
        Firefighter(id: 1, fullName: 'Андрій Бойко', watch: '1'),
      ],
      leaderId: 1,
      startPressuresByFirefighterId: const {1: 300},
      arrivalPressuresByFirefighterId: const {1: 280},
      inclusionTime: now.subtract(const Duration(minutes: 10)),
      arrivalTime: now,
      plannedExitTime: now.add(const Duration(minutes: 20)),
      exitPressure: 90,
      workingTimeMinutes: 20,
      workLoad: WorkLoad.medium,
      cylinderVolume: 6,
      cylindersCount: 1,
    );
    Map<int, int>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showModalBottomSheet<Map<int, int>>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) =>
                      PressureCheckSheet(session: session, openedAt: now),
                );
              },
              child: const Text('Відкрити'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Відкрити'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '250');
    await tester.tap(find.text('Підтвердити замір'));
    await tester.pumpAndSettle();

    expect(result, {1: 250});
    expect(tester.takeException(), isNull);

    result = null;
    await tester.tap(find.text('Відкрити'));
    await tester.pumpAndSettle();
    expect(find.byType(PressureCheckSheet), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(PressureCheckSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
