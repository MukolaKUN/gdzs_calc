import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  testWidgets(
    'shows a red warning when minimum pressure reaches exit pressure',
    (tester) async {
      final now = DateTime.now();
      final session = ActiveTeamSession(
        unitName: '1 ДПРЧ',
        apparatusName: 'Drager PSS 4000',
        participants: const [
          Firefighter(id: 1, fullName: 'Андрій Бойко', watch: '1'),
          Firefighter(id: 2, fullName: 'Олег Коваль', watch: '1'),
        ],
        leaderId: 1,
        startPressuresByFirefighterId: const {1: 300, 2: 295},
        arrivalPressuresByFirefighterId: const {1: 95, 2: 90},
        inclusionTime: now.subtract(const Duration(minutes: 10)),
        arrivalTime: now.subtract(const Duration(minutes: 5)),
        plannedExitTime: now.add(const Duration(minutes: 20)),
        exitPressure: 90,
        workingTimeMinutes: 20,
        workLoad: WorkLoad.medium,
        cylinderVolume: 6,
        cylindersCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(home: ActiveTeamPage(session: session)),
      );

      final warning = find.byKey(const Key('exit-pressure-warning'));
      await tester.scrollUntilVisible(
        warning,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(warning, findsOneWidget);
      expect(
        find.text('Досягнуто тиску виходу. Ланка повинна розпочати вихід'),
        findsOneWidget,
      );

      final warningCard = tester.widget<Card>(warning);
      final colorScheme = Theme.of(tester.element(warning)).colorScheme;
      expect(warningCard.color, colorScheme.errorContainer);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
