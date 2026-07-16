import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  testWidgets('advancing, working, exiting and completed have distinct UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = _session();
    await tester.pumpWidget(
      MaterialApp(home: ActiveTeamPage(session: session)),
    );

    expect(find.text('Ланка прямує до місця роботи'), findsOneWidget);
    expect(find.text('Час прямування'), findsOneWidget);

    await tester.ensureVisible(find.text('Підтвердити прибуття'));
    await tester.pump();
    await tester.tap(find.text('Підтвердити прибуття'));
    await tester.pumpAndSettle();
    expect(find.text('Контроль тиску'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.tap(find.text('Підтвердити замір'));
    await tester.pumpAndSettle();
    expect(session.stage, ActiveTeamStage.working);
    expect(find.text('До початку виходу з НДС'), findsOneWidget);

    await tester.ensureVisible(find.text('Розпочати вихід із НДС'));
    await tester.pump();
    await tester.tap(find.text('Розпочати вихід із НДС'));
    await tester.pumpAndSettle();
    expect(find.text('Підтвердити початок виходу?'), findsOneWidget);
    await tester.tap(find.text('Розпочати вихід'));
    await tester.pumpAndSettle();

    expect(session.stage, ActiveTeamStage.exiting);
    expect(find.text('Ланка виходить із НДС'), findsOneWidget);
    expect(find.text('До початку виходу з НДС'), findsNothing);
    await tester.ensureVisible(find.text('Ланка вийшла на свіже повітря'));
    await tester.pump();
    await tester.tap(find.text('Ланка вийшла на свіже повітря'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Підтвердити вихід'));
    await tester.pumpAndSettle();

    expect(session.stage, ActiveTeamStage.completed);
    expect(find.text('Роботу ланки завершено'), findsOneWidget);
    expect(
      find.text('Дані ланки зберігаються лише до закриття застосунку'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

ActiveTeamSession _session() {
  final inclusion = DateTime.now().subtract(const Duration(minutes: 5));
  return ActiveTeamSession.advancing(
    unitName: 'ДПРЧ-1',
    apparatusName: 'Drager',
    participants: const [
      Firefighter(id: 1, fullName: 'Перший', watch: '1'),
      Firefighter(id: 2, fullName: 'Другий', watch: '1'),
    ],
    leaderId: 1,
    startPressuresByFirefighterId: const {1: 300, 2: 295},
    inclusionTime: inclusion,
    workLoad: WorkLoad.medium,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
    events: [
      ActiveTeamEvent(time: inclusion, title: 'Ланка увімкнулася в ЗІЗОД'),
    ],
  );
}
