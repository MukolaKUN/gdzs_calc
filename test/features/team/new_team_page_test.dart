import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/new_team_page.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/models/unit.dart';

void main() {
  testWidgets('inclusion button creates an advancing session', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: NewTeamPage(
          initialUnits: [Unit(id: 1, name: 'ДПРЧ-1', city: 'Київ')],
          initialApparatus: [
            Apparatus(
              id: 1,
              name: 'Drager',
              workingPressure: 300,
              cylinderVolume: 6.8,
              cylindersCount: 1,
              reservePressure: 50,
            ),
          ],
          initialFirefighters: [
            Firefighter(id: 1, fullName: 'Перший', watch: '1'),
            Firefighter(id: 2, fullName: 'Другий', watch: '1'),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<Unit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ДПРЧ-1 (Київ)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<Apparatus>));
    await tester.tap(find.byType(DropdownButtonFormField<Apparatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drager').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перший'));
    await tester.tap(find.text('Другий'));
    await tester.pump();
    await tester.tap(find.byType(Radio<int>).first);
    await tester.pump();
    await tester.tap(find.text('Далі'));
    await tester.pumpAndSettle();

    expect(find.text('Увімкнутися в ЗІЗОД'), findsOneWidget);
    final before = DateTime.now();
    await tester.ensureVisible(find.text('Увімкнутися в ЗІЗОД'));
    await tester.pump();
    await tester.tap(find.text('Увімкнутися в ЗІЗОД'));
    await tester.pumpAndSettle();
    expect(find.text('Підтвердити включення в ЗІЗОД?'), findsOneWidget);
    await tester.tap(find.text('Увімкнутися'));
    await tester.pumpAndSettle();

    final page = tester.widget<ActiveTeamPage>(find.byType(ActiveTeamPage));
    expect(page.session.stage, ActiveTeamStage.advancing);
    expect(page.session.arrivalTime, isNull);
    expect(page.session.inclusionTime.isBefore(before), isFalse);
    expect(find.text('Час прямування'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
